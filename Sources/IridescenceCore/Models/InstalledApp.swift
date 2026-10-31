import Foundation
import AppKit

public enum ReleaseChannel: String, Codable, Sendable, CaseIterable {
    case stable = "Stable"
    case beta = "Beta"

    public var badgeTitle: String {
        switch self {
        case .stable: return "Stable"
        case .beta: return "Beta"
        }
    }
}

public struct InstalledApp: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var bundleIdentifier: String
    public var bundleURL: URL
    public var installedVersion: AppVersion
    public var buildVersion: String?
    public var iconData: Data?
    public var architecture: BinaryArchitecture
    public var associatedRepository: String?
    public var isOfficialIridescence: Bool
    public var isManagedByAppStore: Bool
    public var isManagedByHomebrew: Bool
    public var hasQuarantine: Bool
    public var lastCheckDate: Date?
    public var availableUpdate: ReleaseItem?
    public var channelOverride: ReleaseChannel?

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String,
        bundleURL: URL,
        installedVersion: AppVersion,
        buildVersion: String? = nil,
        iconData: Data? = nil,
        architecture: BinaryArchitecture = .unknown,
        associatedRepository: String? = nil,
        isOfficialIridescence: Bool = false,
        isManagedByAppStore: Bool = false,
        isManagedByHomebrew: Bool = false,
        hasQuarantine: Bool = false,
        lastCheckDate: Date? = nil,
        availableUpdate: ReleaseItem? = nil,
        channelOverride: ReleaseChannel? = nil
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
        self.installedVersion = installedVersion
        self.buildVersion = buildVersion
        self.iconData = iconData
        self.architecture = architecture
        self.associatedRepository = associatedRepository
        self.isOfficialIridescence = isOfficialIridescence
        self.isManagedByAppStore = isManagedByAppStore
        self.isManagedByHomebrew = isManagedByHomebrew
        self.hasQuarantine = hasQuarantine
        self.lastCheckDate = lastCheckDate
        self.availableUpdate = availableUpdate
        self.channelOverride = channelOverride
    }

    public var hasUpdate: Bool {
        guard let update = availableUpdate else { return false }
        return update.version > installedVersion
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(bundleIdentifier)
        hasher.combine(bundleURL)
    }

    public static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.id == rhs.id &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.bundleURL == rhs.bundleURL &&
        lhs.installedVersion == rhs.installedVersion &&
        lhs.availableUpdate?.id == rhs.availableUpdate?.id
    }
}
