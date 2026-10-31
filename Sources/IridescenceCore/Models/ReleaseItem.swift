import Foundation

public enum AssetKind: String, Codable, Sendable {
    case dmg
    case zip
    case pkg
    case checksum
    case unknown

    public static func from(filename: String) -> AssetKind {
        let lower = filename.lowercased()
        if lower.hasSuffix(".dmg") {
            return .dmg
        } else if lower.hasSuffix(".zip") {
            return .zip
        } else if lower.hasSuffix(".pkg") {
            return .pkg
        } else if lower.hasSuffix(".txt") && (lower.contains("sum") || lower.contains("sha") || lower.contains("hash")) {
            return .checksum
        }
        return .unknown
    }
}

public struct ReleaseAsset: Identifiable, Codable, Sendable, Hashable {
    public let id: Int
    public let name: String
    public let downloadURL: URL
    public let size: Int64
    public let contentType: String
    public let kind: AssetKind
    public let architecture: BinaryArchitecture

    public init(
        id: Int,
        name: String,
        downloadURL: URL,
        size: Int64,
        contentType: String
    ) {
        self.id = id
        self.name = name
        self.downloadURL = downloadURL
        self.size = size
        self.contentType = contentType
        self.kind = AssetKind.from(filename: name)
        self.architecture = BinaryArchitecture.infer(from: name)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case downloadURL = "browser_download_url"
        case size
        case contentType = "content_type"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.downloadURL = try container.decode(URL.self, forKey: .downloadURL)
        self.size = try container.decode(Int64.self, forKey: .size)
        self.contentType = (try? container.decode(String.self, forKey: .contentType)) ?? "application/octet-stream"
        self.kind = AssetKind.from(filename: self.name)
        self.architecture = BinaryArchitecture.infer(from: self.name)
    }
}

public struct ReleaseItem: Identifiable, Codable, Sendable, Hashable {
    public let id: Int
    public let tagName: String
    public let name: String
    public let body: String
    public let publishedAt: Date
    public let isPrerelease: Bool
    public let isDraft: Bool
    public let version: AppVersion
    public let assets: [ReleaseAsset]
    public var checksums: [String: String]

    public init(
        id: Int,
        tagName: String,
        name: String,
        body: String,
        publishedAt: Date,
        isPrerelease: Bool,
        isDraft: Bool = false,
        assets: [ReleaseAsset],
        checksums: [String: String] = [:]
    ) {
        self.id = id
        self.tagName = tagName
        self.name = name.isEmpty ? tagName : name
        self.body = body
        self.publishedAt = publishedAt
        self.isPrerelease = isPrerelease
        self.isDraft = isDraft
        self.version = AppVersion(tagName)
        self.assets = assets
        self.checksums = checksums
    }

    enum CodingKeys: String, CodingKey {
        case id
        case tagName = "tag_name"
        case name
        case body
        case publishedAt = "published_at"
        case isPrerelease = "prerelease"
        case isDraft = "draft"
        case assets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.tagName = try container.decode(String.self, forKey: .tagName)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? self.tagName
        self.body = (try? container.decode(String.self, forKey: .body)) ?? ""
        self.isPrerelease = try container.decode(Bool.self, forKey: .isPrerelease)
        self.isDraft = (try? container.decode(Bool.self, forKey: .isDraft)) ?? false
        self.version = AppVersion(self.tagName)

        let rawDate = try container.decode(String.self, forKey: .publishedAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.publishedAt = formatter.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate) ?? Date()

        self.assets = (try? container.decode([ReleaseAsset].self, forKey: .assets)) ?? []
        self.checksums = [:]
    }

    /// Finds the best installable macOS asset (dmg or zip) for the target architecture
    public func bestInstallableAsset(for hostArch: BinaryArchitecture = .current) -> ReleaseAsset? {
        let installable = assets.filter { $0.kind == .dmg || $0.kind == .zip }

        // 1. Exact architecture match (e.g. arm64 or x86_64)
        if let exact = installable.first(where: { $0.architecture == hostArch }) {
            return exact
        }

        // 2. Universal binary
        if let universal = installable.first(where: { $0.architecture == .universal }) {
            return universal
        }

        // 3. Fallback: if host is Apple Silicon (arm64), Rosetta can run x86_64
        if hostArch == .arm64, let intel = installable.first(where: { $0.architecture == .x86_64 }) {
            return intel
        }

        // 4. Any installable asset where architecture is unknown (e.g. generic App.zip / App.dmg)
        if let unknown = installable.first(where: { $0.architecture == .unknown }) {
            return unknown
        }

        return nil
    }

    /// Check if this release provides a checksum file
    public var checksumAsset: ReleaseAsset? {
        return assets.first { $0.kind == .checksum }
    }
}
