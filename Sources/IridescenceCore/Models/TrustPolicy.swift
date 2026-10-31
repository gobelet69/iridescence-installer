import Foundation

/// Security and trust settings for software sources and quarantine handling.
public struct TrustPolicy: Codable, Sendable {
    /// The official GitHub account/organization for Iridescence
    public static let officialOwner = "gobelet69"

    /// Whether automatic quarantine removal is enabled for official sources
    public var autoQuarantineOfficial: Bool

    /// Set of explicitly approved third-party repositories (e.g., "owner/repo")
    public var trustedThirdPartyRepositories: Set<String>

    /// Whether SHA256 checksum verification is strictly enforced when a checksum file exists
    public var enforceChecksumWhenAvailable: Bool

    /// User approval history for auditability
    public var approvalHistory: [String: Date]

    public init(
        autoQuarantineOfficial: Bool = false,
        trustedThirdPartyRepositories: Set<String> = [],
        enforceChecksumWhenAvailable: Bool = true,
        approvalHistory: [String: Date] = [:]
    ) {
        self.autoQuarantineOfficial = autoQuarantineOfficial
        self.trustedThirdPartyRepositories = trustedThirdPartyRepositories
        self.enforceChecksumWhenAvailable = enforceChecksumWhenAvailable
        self.approvalHistory = approvalHistory
    }

    /// Determines if a repository is an official Iridescence repository
    public static func isOfficial(repository: String) -> Bool {
        let normalized = repository.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let prefix = "\(officialOwner.lowercased())/"
        return normalized.hasPrefix(prefix) || normalized == officialOwner.lowercased()
    }

    /// Evaluates if quarantine removal is permitted for a given repository source
    public func isQuarantineRemovalAuthorized(for repository: String) -> Bool {
        if Self.isOfficial(repository: repository) {
            return autoQuarantineOfficial
        }
        let normalized = repository.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trustedThirdPartyRepositories.contains(normalized)
    }

    /// Records explicit approval for a third-party source
    public mutating func approveSource(_ repository: String) {
        let normalized = repository.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        trustedThirdPartyRepositories.insert(normalized)
        approvalHistory[normalized] = Date()
    }

    /// Revokes approval for a third-party source
    public mutating func revokeSource(_ repository: String) {
        let normalized = repository.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        trustedThirdPartyRepositories.remove(normalized)
        approvalHistory.removeValue(forKey: normalized)
    }

    // MARK: - Persistence
    private static let storageKey = "org.111iridescence.installer.trustPolicy"
    private static let legacyStorageKey = "org.111iridescence.updater.trustPolicy"

    public static func load() -> TrustPolicy {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let policy = try? JSONDecoder().decode(TrustPolicy.self, from: data) {
            return policy
        }
        if let data = UserDefaults.standard.data(forKey: legacyStorageKey),
           let policy = try? JSONDecoder().decode(TrustPolicy.self, from: data) {
            return policy
        }
        return TrustPolicy()
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
