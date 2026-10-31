import Foundation
import AppKit

public enum InstallationPhase: Sendable, Equatable {
    case resolvingAsset
    case downloading(progress: Double)
    case verifyingIntegrity
    case extracting
    case validatingBundle
    case backingUp
    case terminatingRunningApp
    case installing
    case handlingQuarantine
    case completed(URL)
    case failed(String)
}

public enum InstallationError: LocalizedError, Sendable {
    case noCompatibleAssetFound(String)
    case downloadFailed(String)
    case integrityVerificationFailed(String)
    case extractionFailed(String)
    case invalidBundle(String)
    case architectureIncompatible(String)
    case osIncompatible(required: String, current: String)
    case appRunningAndRefusedTermination(String)
    case destinationNotWritable(String)
    case installationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noCompatibleAssetFound(let release):
            return "No compatible macOS installable asset (.dmg or .zip) found in release '\(release)'."
        case .downloadFailed(let reason):
            return "Asset download failed: \(reason)"
        case .integrityVerificationFailed(let reason):
            return "Integrity check failed: \(reason)"
        case .extractionFailed(let reason):
            return "Failed to extract package: \(reason)"
        case .invalidBundle(let reason):
            return "Extracted bundle is invalid: \(reason)"
        case .architectureIncompatible(let arch):
            return "Binary architecture '\(arch)' is incompatible with this Mac."
        case .osIncompatible(let req, let cur):
            return "Application requires macOS \(req) or newer (current: \(cur))."
        case .appRunningAndRefusedTermination(let name):
            return "Application '\(name)' is running and could not be terminated."
        case .destinationNotWritable(let path):
            return "Target installation directory is not writable: \(path)"
        case .installationFailed(let reason):
            return "Installation failed: \(reason)"
        }
    }
}

public actor InstallationManager {
    public static let shared = InstallationManager()

    private let fileManager = FileManager.default
    private let quarantineManager = QuarantineManager.shared
    private let rollbackManager = RollbackManager.shared

    public init() {}

    /// Executes the full end-to-end installation pipeline safely.
    public func install(
        release: ReleaseItem,
        repository: String,
        expectedBundleID: String?,
        targetDirectory: URL? = nil,
        policy: TrustPolicy,
        progressObserver: (@Sendable (InstallationPhase) -> Void)? = nil
    ) async throws -> URL {
        progressObserver?(.resolvingAsset)

        // 1. Resolve best asset for current hardware architecture
        guard let asset = release.bestInstallableAsset(for: .current) else {
            let err = InstallationError.noCompatibleAssetFound(release.name)
            progressObserver?(.failed(err.localizedDescription))
            throw err
        }

        // 2. Set up isolated temporary staging workspace
        let sessionID = UUID().uuidString
        let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("IridescenceInstall_\(sessionID)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: stagingDir)
        }

        let downloadDest = stagingDir.appendingPathComponent(asset.name)

        // 3. Download asset with progress
        do {
            try await GitHubClient.shared.downloadAsset(asset, to: downloadDest) { progress in
                progressObserver?(.downloading(progress: progress))
            }
        } catch {
            let err = InstallationError.downloadFailed(error.localizedDescription)
            progressObserver?(.failed(err.localizedDescription))
            throw err
        }

        // 4. Verify integrity against checksum (if available)
        progressObserver?(.verifyingIntegrity)
        if let expectedHash = release.checksums[asset.name] {
            do {
                try IntegrityVerifier.verify(fileURL: downloadDest, expectedHash: expectedHash)
            } catch {
                let err = InstallationError.integrityVerificationFailed(error.localizedDescription)
                progressObserver?(.failed(err.localizedDescription))
                throw err
            }
        } else if policy.enforceChecksumWhenAvailable && release.checksumAsset != nil {
            // A checksum file was provided by release but lacked this asset
            let err = InstallationError.integrityVerificationFailed("Asset '\(asset.name)' not listed in release checksums.")
            progressObserver?(.failed(err.localizedDescription))
            throw err
        }

        // 5. Extract archive or mount disk image
        progressObserver?(.extracting)
        let extractedAppURL: URL
        let extractionDir = stagingDir.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractionDir, withIntermediateDirectories: true)

        do {
            if asset.kind == .dmg {
                extractedAppURL = try DMGManager.extractAppFromDMG(at: downloadDest, to: extractionDir)
            } else {
                extractedAppURL = try ArchiveExtractor.extractZip(at: downloadDest, to: extractionDir)
            }
        } catch {
            let err = InstallationError.extractionFailed(error.localizedDescription)
            progressObserver?(.failed(err.localizedDescription))
            throw err
        }

        // 6. Inspect and validate application bundle
        progressObserver?(.validatingBundle)
        let infoPlistURL = extractedAppURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            let err = InstallationError.invalidBundle("Contents/Info.plist is missing or unreadable.")
            progressObserver?(.failed(err.localizedDescription))
            throw err
        }

        let actualBundleID = plist["CFBundleIdentifier"] as? String ?? ""
        if let expectedID = expectedBundleID, !expectedID.isEmpty {
            if actualBundleID.caseInsensitiveCompare(expectedID) != .orderedSame {
                let err = InstallationError.invalidBundle("Bundle identifier mismatch: expected '\(expectedID)', found '\(actualBundleID)'")
                progressObserver?(.failed(err.localizedDescription))
                throw err
            }
        }

        // Check minimum OS version
        if let minOS = plist["LSMinimumSystemVersion"] as? String {
            let currentOS = ProcessInfo.processInfo.operatingSystemVersionString
            let minVersion = AppVersion(minOS)
            let hostOSVersion = AppVersion("\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)")
            if hostOSVersion < minVersion {
                let err = InstallationError.osIncompatible(required: minOS, current: currentOS)
                progressObserver?(.failed(err.localizedDescription))
                throw err
            }
        }

        // 7. Check if target application is currently running
        progressObserver?(.terminatingRunningApp)
        if !actualBundleID.isEmpty {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: actualBundleID)
            for running in runningApps {
                running.terminate()
                // Wait briefly for graceful shutdown
                for _ in 0..<10 {
                    if running.isTerminated { break }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }

        // 8. Determine target destination directory
        let appName = extractedAppURL.lastPathComponent
        let defaultDestinationDir = determineInstallDirectory(preferred: targetDirectory)
        let finalDestinationURL = defaultDestinationDir.appendingPathComponent(appName)

        // 9. Create Rollback backup of existing installation
        var rollbackEntry: RollbackEntry?
        if fileManager.fileExists(atPath: finalDestinationURL.path) {
            progressObserver?(.backingUp)
            if let existingApp = await AppScanner.shared.inspectAppBundle(at: finalDestinationURL) {
                rollbackEntry = try? await rollbackManager.createBackup(
                    of: finalDestinationURL,
                    bundleIdentifier: actualBundleID,
                    version: existingApp.installedVersion
                )
            }
        }

        // 10. Perform atomic replacement
        progressObserver?(.installing)
        do {
            if fileManager.fileExists(atPath: finalDestinationURL.path) {
                try fileManager.removeItem(at: finalDestinationURL)
            }

            // Move extracted bundle to destination
            try fileManager.moveItem(at: extractedAppURL, to: finalDestinationURL)
        } catch {
            // Restore previous version from rollback backup if move failed
            if let backup = rollbackEntry {
                try? await rollbackManager.restore(entry: backup)
            }
            let err = InstallationError.installationFailed("Failed to replace application bundle: \(error.localizedDescription)")
            progressObserver?(.failed(err.localizedDescription))
            throw err
        }

        // 11. Scoped Quarantine handling if authorized
        progressObserver?(.handlingQuarantine)
        if policy.isQuarantineRemovalAuthorized(for: repository) {
            do {
                try quarantineManager.removeQuarantine(
                    bundleURL: finalDestinationURL,
                    expectedBundleID: actualBundleID,
                    sourceRepository: repository,
                    policy: policy
                )
            } catch {
                // If quarantine removal fails, log warning but keep installed app
                print("Warning: Quarantine removal encountered an issue: \(error.localizedDescription)")
            }
        }

        progressObserver?(.completed(finalDestinationURL))
        return finalDestinationURL
    }

    private func determineInstallDirectory(preferred: URL?) -> URL {
        if let pref = preferred, fileManager.isWritableFile(atPath: pref.path) {
            return pref
        }

        let sysApps = URL(fileURLWithPath: "/Applications", isDirectory: true)
        if fileManager.isWritableFile(atPath: sysApps.path) {
            return sysApps
        }

        let userApps = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        try? fileManager.createDirectory(at: userApps, withIntermediateDirectories: true)
        return userApps
    }
}
