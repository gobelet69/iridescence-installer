import Foundation

public enum DMGError: LocalizedError, Sendable {
    case mountFailed(String)
    case unmountFailed(String)
    case appNotFoundInDMG(String)
    case copyFailed(String)

    public var errorDescription: String? {
        switch self {
        case .mountFailed(let msg):
            return "Failed to mount disk image: \(msg)"
        case .unmountFailed(let msg):
            return "Failed to unmount disk image: \(msg)"
        case .appNotFoundInDMG(let path):
            return "No application bundle found inside mounted image at \(path)"
        case .copyFailed(let msg):
            return "Failed to copy application from disk image: \(msg)"
        }
    }
}

public struct DMGManager: Sendable {
    /// Mounts a DMG, extracts the .app bundle to target staging directory, and unmounts the DMG.
    public static func extractAppFromDMG(at dmgURL: URL, to stagingDir: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let mountPoint = stagingDir.appendingPathComponent("mnt_\(UUID().uuidString)")
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        defer {
            // Guarantee unmount on exit
            unmountDMG(at: mountPoint)
            try? fileManager.removeItem(at: mountPoint)
        }

        // Mount DMG: hdiutil attach <dmg> -nobrowse -readonly -mountpoint <mountPoint>
        let hdiutilURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        let mountResult = try ProcessRunner.run(
            executableURL: hdiutilURL,
            arguments: ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountpoint", mountPoint.path]
        )

        guard mountResult.isSuccess else {
            throw DMGError.mountFailed("hdiutil attach failed (code \(mountResult.exitCode)): \(mountResult.stderr)")
        }

        // Search for .app in mounted volume
        guard let appInDMG = ArchiveExtractor.findAppBundle(in: mountPoint) else {
            throw DMGError.appNotFoundInDMG(mountPoint.path)
        }

        let destinationAppURL = stagingDir.appendingPathComponent(appInDMG.lastPathComponent)
        try? fileManager.removeItem(at: destinationAppURL)

        // Copy bundle using /usr/bin/ditto to preserve all metadata and signatures
        let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")
        let copyResult = try ProcessRunner.run(
            executableURL: dittoURL,
            arguments: [appInDMG.path, destinationAppURL.path]
        )

        guard copyResult.isSuccess else {
            throw DMGError.copyFailed("Failed to copy \(appInDMG.lastPathComponent) from DMG: \(copyResult.stderr)")
        }

        return destinationAppURL
    }

    /// Detaches a mounted disk image volume safely
    public static func unmountDMG(at mountPoint: URL) {
        guard FileManager.default.fileExists(atPath: mountPoint.path) else { return }
        let hdiutilURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        _ = try? ProcessRunner.run(
            executableURL: hdiutilURL,
            arguments: ["detach", mountPoint.path, "-force"],
            timeout: 10
        )
    }
}
