import Foundation
import Darwin

public enum QuarantineError: LocalizedError, Sendable {
    case invalidAppBundle(String)
    case unauthorizedSource(String)
    case systemPathForbidden(String)
    case removalFailed(String, Int32)
    case verificationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidAppBundle(let reason):
            return "Invalid application bundle: \(reason)"
        case .unauthorizedSource(let repo):
            return "Quarantine removal is not authorized for source '\(repo)'. Please enable trust in Settings."
        case .systemPathForbidden(let path):
            return "Security violation: Modification of system path '\(path)' is forbidden."
        case .removalFailed(let item, let code):
            return "Failed to remove quarantine attribute on '\(item)' (POSIX error \(code))."
        case .verificationFailed(let path):
            return "Verification failed: Quarantine attribute still present on '\(path)'."
        }
    }
}

/// Dedicated, secure manager for inspecting and removing the macOS `com.apple.quarantine` extended attribute
/// on verified unsigned application bundles according to the user's explicit trust policy.
public final class QuarantineManager: Sendable {
    public static let shared = QuarantineManager()
    public static let quarantineAttributeName = "com.apple.quarantine"

    public init() {}

    /// Check if a path or bundle has the `com.apple.quarantine` extended attribute set.
    public func hasQuarantine(at url: URL) -> Bool {
        let path = url.path
        let bufferSize = getxattr(path, Self.quarantineAttributeName, nil, 0, 0, XATTR_NOFOLLOW)
        return bufferSize >= 0
    }

    /// Read the raw quarantine string from the application bundle (for diagnostic logging).
    public func readQuarantineString(at url: URL) -> String? {
        let path = url.path
        let bufferSize = getxattr(path, Self.quarantineAttributeName, nil, 0, 0, XATTR_NOFOLLOW)
        guard bufferSize > 0 else { return nil }

        var buffer = [CChar](repeating: 0, count: bufferSize + 1)
        let bytesRead = getxattr(path, Self.quarantineAttributeName, &buffer, bufferSize, 0, XATTR_NOFOLLOW)
        guard bytesRead > 0 else { return nil }
        return String(cString: buffer)
    }

    /// Recursively remove the `com.apple.quarantine` extended attribute on a validated application bundle.
    /// - Parameters:
    ///   - bundleURL: The URL of the `.app` bundle.
    ///   - expectedBundleID: Optional expected `CFBundleIdentifier` to cross-validate.
    ///   - sourceRepository: The GitHub repository string (e.g. "gobelet69/Mass-Print").
    ///   - policy: The active trust policy.
    public func removeQuarantine(
        bundleURL: URL,
        expectedBundleID: String? = nil,
        sourceRepository: String,
        policy: TrustPolicy
    ) throws {
        // 1. Authorization check
        guard policy.isQuarantineRemovalAuthorized(for: sourceRepository) else {
            throw QuarantineError.unauthorizedSource(sourceRepository)
        }

        // 2. Validate safety of the destination path
        try validateBundlePath(bundleURL, expectedBundleID: expectedBundleID)

        // 3. Perform scoped POSIX removal without invoking arbitrary shell strings
        try recursivelyRemoveQuarantine(at: bundleURL)

        // 4. Verify removal on bundle root
        if hasQuarantine(at: bundleURL) {
            throw QuarantineError.verificationFailed(bundleURL.path)
        }
    }

    /// Validates that the path is a legitimate, isolated `.app` bundle and not a system directory or symlink escape.
    public func validateBundlePath(_ url: URL, expectedBundleID: String? = nil) throws {
        let path = url.standardizedFileURL.path

        // Must end with .app
        guard path.hasSuffix(".app") else {
            throw QuarantineError.invalidAppBundle("Path must end with '.app': \(path)")
        }

        // Must not be root or top-level directory
        guard path != "/Applications" && path != "/System" && path != "/" else {
            throw QuarantineError.systemPathForbidden(path)
        }

        // Standard permitted locations: /Applications, ~/Applications, user temp/caches, or Application Support
        let homeAppDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path
        let userTempDir = FileManager.default.temporaryDirectory.path
        let isPermittedLocation = path.hasPrefix("/Applications/") ||
                                  path.hasPrefix(homeAppDir) ||
                                  path.hasPrefix(userTempDir) ||
                                  path.hasPrefix("/tmp/") ||
                                  path.hasPrefix("/private/tmp/") ||
                                  path.contains("/var/folders/") ||
                                  path.contains("Application Support")

        guard isPermittedLocation else {
            throw QuarantineError.systemPathForbidden("Location '\(path)' is not permitted for app bundle quarantine removal.")
        }

        // Explicitly forbidden system locations
        let forbiddenPrefixes = ["/System", "/bin", "/sbin", "/usr", "/etc", "/var/root", "/var/db", "/var/log"]
        for forbidden in forbiddenPrefixes {
            if path.hasPrefix(forbidden) {
                throw QuarantineError.systemPathForbidden(path)
            }
        }

        // Must be a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            throw QuarantineError.invalidAppBundle("Path is not a valid directory: \(path)")
        }

        // Must contain Contents/Info.plist
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw QuarantineError.invalidAppBundle("Missing Contents/Info.plist: \(infoPlistURL.path)")
        }

        // Verify bundle identifier if specified
        if let expectedID = expectedBundleID {
            guard let plistData = try? Data(contentsOf: infoPlistURL),
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                  let actualID = plist["CFBundleIdentifier"] as? String else {
                throw QuarantineError.invalidAppBundle("Unable to read CFBundleIdentifier from Info.plist")
            }

            guard actualID.caseInsensitiveCompare(expectedID) == .orderedSame else {
                throw QuarantineError.invalidAppBundle("Bundle identifier mismatch. Expected '\(expectedID)', found '\(actualID)'")
            }
        }
    }

    /// Recursively strips `com.apple.quarantine` using direct Darwin `removexattr`.
    private func recursivelyRemoveQuarantine(at bundleURL: URL) throws {
        let fileManager = FileManager.default

        // Strip from root bundle directory
        stripAttribute(atPath: bundleURL.path)

        // Iterate contents
        guard let enumerator = fileManager.enumerator(
            at: bundleURL,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey],
            options: []
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            // Never follow symlinks to avoid directory traversal
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isSymbolicLinkKey])
            if resourceValues?.isSymbolicLink == true {
                // Just remove attribute on the symlink itself without following
                stripAttribute(atPath: fileURL.path)
                continue
            }
            stripAttribute(atPath: fileURL.path)
        }
    }

    @discardableResult
    private func stripAttribute(atPath path: String) -> Bool {
        let result = removexattr(path, Self.quarantineAttributeName, XATTR_NOFOLLOW)
        if result == 0 {
            return true
        }
        let err = errno
        // ENOATTR (93) means the attribute was not present, which is normal/successful
        if err == ENOATTR {
            return true
        }
        return false
    }
}
