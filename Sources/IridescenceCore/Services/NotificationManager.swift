import Foundation
import UserNotifications

public struct NotificationPreferences: Codable, Sendable {
    public var notifyNewApps: Bool
    public var notifyStableUpdates: Bool
    public var notifyBetaUpdates: Bool
    public var notifyInstallCompleted: Bool
    public var notifyInstallFailed: Bool

    public init(
        notifyNewApps: Bool = true,
        notifyStableUpdates: Bool = true,
        notifyBetaUpdates: Bool = false,
        notifyInstallCompleted: Bool = true,
        notifyInstallFailed: Bool = true
    ) {
        self.notifyNewApps = notifyNewApps
        self.notifyStableUpdates = notifyStableUpdates
        self.notifyBetaUpdates = notifyBetaUpdates
        self.notifyInstallCompleted = notifyInstallCompleted
        self.notifyInstallFailed = notifyInstallFailed
    }

    private static let key = "org.111iridescence.updater.notificationPreferences"

    public static func load() -> NotificationPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let prefs = try? JSONDecoder().decode(NotificationPreferences.self, from: data) else {
            return NotificationPreferences()
        }
        return prefs
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

public actor NotificationManager {
    public static let shared = NotificationManager()

    private var deliveredIdentifiers: Set<String> = []

    public init() {}

    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Notify about a newly discovered application
    public func notifyNewAppDiscovered(_ app: CatalogApp) async {
        let prefs = NotificationPreferences.load()
        guard prefs.notifyNewApps else { return }

        let notifId = "new_app_\(app.id)"
        guard !deliveredIdentifiers.contains(notifId) else { return }
        deliveredIdentifiers.insert(notifId)

        let content = UNMutableNotificationContent()
        content.title = "New Iridescence App"
        content.subtitle = app.name
        content.body = app.localizedTagline()
        content.sound = .default

        let request = UNNotificationRequest(identifier: notifId, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Notify about an available application update
    public func notifyUpdateAvailable(appName: String, version: AppVersion, isBeta: Bool) async {
        let prefs = NotificationPreferences.load()
        if isBeta && !prefs.notifyBetaUpdates { return }
        if !isBeta && !prefs.notifyStableUpdates { return }

        let notifId = "update_\(appName)_\(version.description)"
        guard !deliveredIdentifiers.contains(notifId) else { return }
        deliveredIdentifiers.insert(notifId)

        let content = UNMutableNotificationContent()
        content.title = isBeta ? "Beta Update Available" : "Update Available"
        content.subtitle = "\(appName) \(version.description)"
        content.body = "A new version of \(appName) is ready to install."
        content.sound = .default

        let request = UNNotificationRequest(identifier: notifId, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Notify about a completed installation
    public func notifyInstallationCompleted(appName: String, version: AppVersion) async {
        let prefs = NotificationPreferences.load()
        guard prefs.notifyInstallCompleted else { return }

        let notifId = "installed_\(appName)_\(version.description)_\(Int(Date().timeIntervalSince1970))"

        let content = UNMutableNotificationContent()
        content.title = "Installation Complete"
        content.body = "\(appName) \(version.description) was installed successfully."
        content.sound = .default

        let request = UNNotificationRequest(identifier: notifId, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Notify about an installation failure
    public func notifyInstallationFailed(appName: String, error: String) async {
        let prefs = NotificationPreferences.load()
        guard prefs.notifyInstallFailed else { return }

        let notifId = "failed_\(appName)_\(Int(Date().timeIntervalSince1970))"

        let content = UNMutableNotificationContent()
        content.title = "Installation Failed"
        content.subtitle = appName
        content.body = error
        content.sound = .default

        let request = UNNotificationRequest(identifier: notifId, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
