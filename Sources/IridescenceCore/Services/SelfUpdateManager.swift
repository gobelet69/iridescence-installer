import Foundation
import AppKit

public enum SelfUpdateState: Sendable, Equatable {
    case idle
    case checking
    case updateAvailable(ReleaseItem)
    case upToDate
    case downloading(Double)
    case verifying
    case readyToRelaunch
    case failed(String)
}

public actor SelfUpdateManager {
    public static let shared = SelfUpdateManager()

    public static let installerRepository = "gobelet69/iridescence-installer"
    public static let installerBundleID = "org.111iridescence.installer"

    public private(set) var currentState: SelfUpdateState = .idle
    public private(set) var availableRelease: ReleaseItem?

    public init() {}

    /// Current running version of Iridescence Installer
    public var currentVersion: AppVersion {
        let verStr = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        return AppVersion(verStr)
    }

    /// Check if a newer version of Iridescence Installer is available on GitHub
    public func checkForSelfUpdate(includeBeta: Bool = false) async -> ReleaseItem? {
        currentState = .checking

        do {
            if let release = try await GitHubClient.shared.fetchLatestRelease(
                for: Self.installerRepository,
                includeBeta: includeBeta
            ) {
                if release.version > currentVersion {
                    self.availableRelease = release
                    self.currentState = .updateAvailable(release)
                    return release
                }
            }
            self.currentState = .upToDate
            return nil
        } catch {
            self.currentState = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Perform download, verification, staging, and launch the external relaunch helper
    public func performSelfUpdate(
        release: ReleaseItem,
        progressObserver: (@Sendable (SelfUpdateState) -> Void)? = nil
    ) async throws {
        progressObserver?(.downloading(0.0))

        guard let asset = release.bestInstallableAsset(for: .current) else {
            let err = "No compatible binary asset found for this architecture in release \(release.name)."
            progressObserver?(.failed(err))
            throw NSError(domain: "org.111iridescence.installer.selfupdate", code: -1, userInfo: [NSLocalizedDescriptionKey: err])
        }

        let fileManager = FileManager.default
        let stagingDir = fileManager.temporaryDirectory.appendingPathComponent("IridescenceSelfUpdate_\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let downloadDest = stagingDir.appendingPathComponent(asset.name)

        // 1. Download
        try await GitHubClient.shared.downloadAsset(asset, to: downloadDest) { progress in
            progressObserver?(.downloading(progress))
        }

        // 2. Verify Checksum
        progressObserver?(.verifying)
        if let expectedHash = release.checksums[asset.name] {
            try IntegrityVerifier.verify(fileURL: downloadDest, expectedHash: expectedHash)
        }

        // 3. Extract bundle
        let extractionDir = stagingDir.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractionDir, withIntermediateDirectories: true)

        let extractedAppURL: URL
        if asset.kind == .dmg {
            extractedAppURL = try DMGManager.extractAppFromDMG(at: downloadDest, to: extractionDir)
        } else {
            extractedAppURL = try ArchiveExtractor.extractZip(at: downloadDest, to: extractionDir)
        }

        // 4. Validate extracted bundle
        let infoPlistURL = extractedAppURL.appendingPathComponent("Contents/Info.plist")
        guard fileManager.fileExists(atPath: infoPlistURL.path) else {
            throw NSError(domain: "org.111iridescence.installer.selfupdate", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid update bundle (missing Info.plist)"])
        }

        // 5. Determine target installation location of current app
        var targetAppURL = Bundle.main.bundleURL
        if !targetAppURL.path.hasSuffix(".app") {
            // Running in development or CLI mode -> default to /Applications/Iridescence Installer.app
            targetAppURL = URL(fileURLWithPath: "/Applications/Iridescence Installer.app")
        }

        progressObserver?(.readyToRelaunch)

        // 6. Generate and launch detached self-update script
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let scriptPath = stagingDir.appendingPathComponent("self_update_worker.sh").path

        let scriptContent = """
        #!/bin/bash
        set -e

        # Wait for host process (PID \(currentPID)) to exit
        while kill -0 \(currentPID) 2>/dev/null; do
            sleep 0.15
        done

        # Replace application bundle
        if [ -d "\(targetAppURL.path)" ]; then
            rm -rf "\(targetAppURL.path)"
        fi
        cp -R "\(extractedAppURL.path)" "\(targetAppURL.path)"

        # Remove quarantine attribute
        xattr -dr com.apple.quarantine "\(targetAppURL.path)" 2>/dev/null || true

        # Relaunch the upgraded application
        open "\(targetAppURL.path)"

        # Clean staging
        rm -rf "\(stagingDir.path)"
        exit 0
        """

        try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)

        let workerProcess = Process()
        workerProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        workerProcess.arguments = [scriptPath]

        try workerProcess.run()

        // 7. Quit host application so worker script can replace the bundle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}
