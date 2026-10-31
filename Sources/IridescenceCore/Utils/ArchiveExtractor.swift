import Foundation

public enum ExtractionError: LocalizedError, Sendable {
    case extractionFailed(String)
    case appNotFound(String)
    case unsafeZipEntry(String)

    public var errorDescription: String? {
        switch self {
        case .extractionFailed(let msg):
            return "Archive extraction failed: \(msg)"
        case .appNotFound(let path):
            return "No valid '.app' bundle found in extracted archive at \(path)"
        case .unsafeZipEntry(let entry):
            return "Unsafe ZIP entry detected (possible path traversal): \(entry)"
        }
    }
}

public struct ArchiveExtractor: Sendable {
    public static func extractZip(at archiveURL: URL, to destinationDir: URL) throws -> URL {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)

        // Use macOS ditto utility: ditto -x -k <archive> <dest>
        // ditto is native, fast, preserves resource forks and permissions, and stays safe.
        let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")
        let result = try ProcessRunner.run(
            executableURL: dittoURL,
            arguments: ["-x", "-k", archiveURL.path, destinationDir.path]
        )

        guard result.isSuccess else {
            throw ExtractionError.extractionFailed("ditto failed with code \(result.exitCode): \(result.stderr)")
        }

        // Locate the .app bundle inside destinationDir
        guard let appURL = findAppBundle(in: destinationDir) else {
            throw ExtractionError.appNotFound(destinationDir.path)
        }

        return appURL
    }

    /// Search for an .app bundle in directory (top-level or 1 subdirectory deep)
    public static func findAppBundle(in directory: URL) -> URL? {
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        // Direct .app match
        if let direct = items.first(where: { $0.pathExtension == "app" }) {
            return direct
        }

        // One level deep
        for item in items {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                if let subItems = try? fileManager.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]),
                   let subApp = subItems.first(where: { $0.pathExtension == "app" }) {
                    return subApp
                }
            }
        }

        return nil
    }
}
