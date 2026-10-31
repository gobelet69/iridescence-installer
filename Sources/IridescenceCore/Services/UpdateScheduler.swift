import Foundation

public struct SchedulerPreferences: Codable, Sendable {
    public var autoCheckEnabled: Bool
    public var checkIntervalHours: Int // e.g. 4, 8, 24
    public var autoInstallUpdates: Bool
    public var globalReleaseChannel: ReleaseChannel

    public init(
        autoCheckEnabled: Bool = true,
        checkIntervalHours: Int = 8,
        autoInstallUpdates: Bool = false,
        globalReleaseChannel: ReleaseChannel = .stable
    ) {
        self.autoCheckEnabled = autoCheckEnabled
        self.checkIntervalHours = checkIntervalHours
        self.autoInstallUpdates = autoInstallUpdates
        self.globalReleaseChannel = globalReleaseChannel
    }

    private static let key = "org.111iridescence.updater.schedulerPreferences"

    public static func load() -> SchedulerPreferences {
        guard let data = UserDefaults.standard.data(forKey: key),
              let prefs = try? JSONDecoder().decode(SchedulerPreferences.self, from: data) else {
            return SchedulerPreferences()
        }
        return prefs
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

/// Lightweight scheduler for periodic update checks
public actor UpdateScheduler {
    public static let shared = UpdateScheduler()

    private var scheduledTask: Task<Void, Never>?
    private var isChecking: Bool = false
    public private(set) var lastCheckDate: Date?

    public init() {}

    public func start(checkAction: @Sendable @escaping () async -> Void) {
        stop()

        scheduledTask = Task { [weak self] in
            while !Task.isCancelled {
                let prefs = SchedulerPreferences.load()
                guard prefs.autoCheckEnabled else {
                    // Sleep 1 hour before checking preference again
                    try? await Task.sleep(nanoseconds: 3600 * 1_000_000_000)
                    continue
                }

                await checkAction()
                await self?.recordCheckDate(Date())

                let sleepSeconds = UInt64(max(1, prefs.checkIntervalHours) * 3600)
                try? await Task.sleep(nanoseconds: sleepSeconds * 1_000_000_000)
            }
        }
    }

    public func stop() {
        scheduledTask?.cancel()
        scheduledTask = nil
    }

    private func recordCheckDate(_ date: Date) {
        self.lastCheckDate = date
    }
}
