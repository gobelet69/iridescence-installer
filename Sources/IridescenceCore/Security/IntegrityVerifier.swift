import Foundation
import CryptoKit

public enum IntegrityError: LocalizedError, Sendable {
    case checksumMismatch(expected: String, actual: String, filename: String)
    case unreadableFile(URL)
    case invalidChecksumFormat(String)

    public var errorDescription: String? {
        switch self {
        case .checksumMismatch(let expected, let actual, let filename):
            return "Integrity check failed for '\(filename)': expected SHA256 \(expected), computed \(actual)."
        case .unreadableFile(let url):
            return "Unable to read file for checksum verification: \(url.path)"
        case .invalidChecksumFormat(let line):
            return "Invalid checksum line format: '\(line)'"
        }
    }
}

/// Verifies SHA-256 checksums of downloaded release assets.
public struct IntegrityVerifier: Sendable {

    /// Compute the SHA-256 hash of a file on disk using CryptoKit.
    public static func computeSHA256(for fileURL: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw IntegrityError.unreadableFile(fileURL)
        }

        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }

        var hasher = SHA256()
        let bufferSize = 1024 * 1024 // 1 MB buffer for performance

        while autoreleasepool(invoking: {
            let data = fileHandle.readData(ofLength: bufferSize)
            if data.isEmpty {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Parse a `SHA256SUMS.txt` or `checksums.txt` file content into a dictionary mapping filename -> SHA256.
    public static func parseChecksums(text: String) -> [String: String] {
        var result: [String: String] = [:]
        let lines = text.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // Common formats:
            // <hash>  <filename>
            // <hash> *<filename>
            // SHA256 (<filename>) = <hash>
            if trimmed.starts(with: "SHA256 (") {
                let parts = trimmed.components(separatedBy: ") = ")
                if parts.count == 2 {
                    let filename = parts[0].replacingOccurrences(of: "SHA256 (", with: "")
                    let hash = parts[1].trimmingCharacters(in: .whitespaces)
                    result[filename] = hash.lowercased()
                }
            } else {
                let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if tokens.count >= 2 {
                    let hash = tokens[0].trimmingCharacters(in: .whitespaces).lowercased()
                    var filename = tokens[1...].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    if filename.hasPrefix("*") {
                        filename.removeFirst()
                    }
                    // Strip path components if present (e.g. dist/App.dmg -> App.dmg)
                    let baseFilename = URL(fileURLWithPath: filename).lastPathComponent
                    result[baseFilename] = hash
                }
            }
        }
        return result
    }

    /// Verify that an asset file matches its expected SHA-256 hash.
    public static func verify(fileURL: URL, expectedHash: String) throws {
        let actual = try computeSHA256(for: fileURL)
        if actual.caseInsensitiveCompare(expectedHash) != .orderedSame {
            throw IntegrityError.checksumMismatch(
                expected: expectedHash.lowercased(),
                actual: actual.lowercased(),
                filename: fileURL.lastPathComponent
            )
        }
    }
}
