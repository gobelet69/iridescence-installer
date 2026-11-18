import Foundation
import SwiftUI
import Combine
import IridescenceCore

public enum NavigationTab: String, CaseIterable, Identifiable {
    case installed = "Installed"
    case updates = "Updates"
    case discover = "Discover"
    case settings = "Settings"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .installed: return "macwindow.on.rectangle"
        case .updates: return "arrow.triangle.2.circlepath"
        case .discover: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    public let currentAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"

    @Published public var selectedTab: NavigationTab = .installed
    @Published public var installedApps: [InstalledApp] = []
    @Published public var pendingUpdates: [InstalledApp] = []
    @Published public var catalogApps: [CatalogApp] = []

    @Published public var isScanning: Bool = false
    @Published public var isCheckingUpdates: Bool = false
    @Published public var activeInstalls: [String: InstallationPhase] = [:]

    @Published public var trustPolicy: TrustPolicy
    @Published public var schedulerPrefs: SchedulerPreferences
    @Published public var notificationPrefs: NotificationPreferences

    @Published public var rateLimitRemaining: Int = 60
    @Published public var searchQuery: String = ""
    @Published public var statusMessage: String?
    @Published public var selectedAppForDetail: InstalledApp?
    @Published public var selectedCatalogForDetail: CatalogApp?

    @Published public var selfUpdateState: SelfUpdateState = .idle
    @Published public var selfUpdateRelease: ReleaseItem? = nil

    private let scanner = AppScanner.shared
    private let gitHub = GitHubClient.shared
    private let discovery = CatalogDiscovery.shared
    private let installer = InstallationManager.shared
    private let rollbackMgr = RollbackManager.shared
    private let notifier = NotificationManager.shared
    private let selfUpdater = SelfUpdateManager.shared

    public init() {
        self.catalogApps = CatalogApp.defaultSeeds
        self.trustPolicy = TrustPolicy.load()
        self.schedulerPrefs = SchedulerPreferences.load()
        self.notificationPrefs = NotificationPreferences.load()

        Task {
            await bootstrap()
        }
    }

    public func bootstrap() async {
        await refreshAll()

        // Start periodic background updates scheduler
        await UpdateScheduler.shared.start { [weak self] in
            await self?.checkAllUpdates()
        }
    }

    public func refreshAll() async {
        await scanLocalApps()
        await refreshCatalog()
        await checkAllUpdates()
    }

    // MARK: - Installed Apps Discovery

    public func scanLocalApps() async {
        isScanning = true
        let apps = await scanner.scanInstalledApplications()
        self.installedApps = apps
        isScanning = false
    }

    // MARK: - Catalog Discovery

    public func refreshCatalog() async {
        let newApps = await discovery.refreshCatalog()
        self.catalogApps = await discovery.getCatalogApps()

        // Notify user about new discoveries
        for app in newApps {
            await notifier.notifyNewAppDiscovered(app)
        }
    }

    // MARK: - Update Checks

    public func checkAllUpdates() async {
        isCheckingUpdates = true
        var updatedInstalled: [InstalledApp] = []
        var updatesAvailable: [InstalledApp] = []

        let includeBetaGlobal = (schedulerPrefs.globalReleaseChannel == .beta)

        for var app in installedApps {
            // Check if app has associated repository
            if let repo = app.associatedRepository, !repo.isEmpty {
                let includeBeta = (app.channelOverride == .beta) || (app.channelOverride == nil && includeBetaGlobal)
                if let release = try? await gitHub.fetchLatestRelease(for: repo, includeBeta: includeBeta) {
                    if release.version > app.installedVersion {
                        app.availableUpdate = release
                        updatesAvailable.append(app)

                        // Notify
                        await notifier.notifyUpdateAvailable(
                            appName: app.name,
                            version: release.version,
                            isBeta: release.isPrerelease
                        )
                    } else {
                        app.availableUpdate = nil
                    }
                }
            }
            app.lastCheckDate = Date()
            updatedInstalled.append(app)
        }

        self.installedApps = updatedInstalled
        self.pendingUpdates = updatesAvailable
        self.rateLimitRemaining = await gitHub.rateLimitRemaining

        // Check for self update of Iridescence Installer
        await checkSelfUpdate()

        self.isCheckingUpdates = false
    }

    // MARK: - Self Update

    public func checkSelfUpdate() async {
        let includeBetaGlobal = (schedulerPrefs.globalReleaseChannel == .beta)
        if let rel = await selfUpdater.checkForSelfUpdate(includeBeta: includeBetaGlobal) {
            self.selfUpdateRelease = rel
            self.selfUpdateState = .updateAvailable(rel)
        } else {
            self.selfUpdateRelease = nil
            self.selfUpdateState = .upToDate
        }
    }

    public func triggerSelfUpdate() async {
        guard let rel = selfUpdateRelease else { return }
        selfUpdateState = .downloading(0.0)

        do {
            try await selfUpdater.performSelfUpdate(release: rel) { [weak self] state in
                Task { @MainActor in
                    self?.selfUpdateState = state
                }
            }
        } catch {
            selfUpdateState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Single & Batch Installation

    public func installUpdate(for app: InstalledApp) async {
        guard let release = app.availableUpdate,
              let repo = app.associatedRepository else {
            return
        }

        activeInstalls[app.bundleIdentifier] = .resolvingAsset

        do {
            _ = try await installer.install(
                release: release,
                repository: repo,
                expectedBundleID: app.bundleIdentifier,
                targetDirectory: app.bundleURL.deletingLastPathComponent(),
                policy: self.trustPolicy
            ) { [weak self] phase in
                Task { @MainActor in
                    self?.activeInstalls[app.bundleIdentifier] = phase
                }
            }

            activeInstalls.removeValue(forKey: app.bundleIdentifier)
            await notifier.notifyInstallationCompleted(appName: app.name, version: release.version)

            // Rescan local apps to update installed state
            await scanLocalApps()
            pendingUpdates.removeAll { $0.bundleIdentifier == app.bundleIdentifier }
        } catch {
            activeInstalls[app.bundleIdentifier] = .failed(error.localizedDescription)
            await notifier.notifyInstallationFailed(appName: app.name, error: error.localizedDescription)
        }
    }

    public func installCatalogApp(_ catalogApp: CatalogApp) async {
        let isBeta = (schedulerPrefs.globalReleaseChannel == .beta)
        let releaseToInstall = isBeta ? (catalogApp.latestBetaRelease ?? catalogApp.latestRelease) : catalogApp.latestRelease

        guard let release = releaseToInstall else {
            return
        }

        activeInstalls[catalogApp.bundleIdentifier] = .resolvingAsset

        do {
            _ = try await installer.install(
                release: release,
                repository: catalogApp.repository,
                expectedBundleID: catalogApp.bundleIdentifier,
                policy: self.trustPolicy
            ) { [weak self] phase in
                Task { @MainActor in
                    self?.activeInstalls[catalogApp.bundleIdentifier] = phase
                }
            }

            activeInstalls.removeValue(forKey: catalogApp.bundleIdentifier)
            await notifier.notifyInstallationCompleted(appName: catalogApp.name, version: release.version)
            await scanLocalApps()
        } catch {
            activeInstalls[catalogApp.bundleIdentifier] = .failed(error.localizedDescription)
            await notifier.notifyInstallationFailed(appName: catalogApp.name, error: error.localizedDescription)
        }
    }

    public func updateAllPending() async {
        let updates = pendingUpdates
        for app in updates {
            await installUpdate(for: app)
        }
    }

    // MARK: - Manual Association & Trust Policy Controls

    public func setManualRepository(bundleIdentifier: String, repository: String) async {
        await scanner.setManualMapping(bundleIdentifier: bundleIdentifier, repository: repository)
        await scanLocalApps()
        await checkAllUpdates()
    }

    public func toggleQuarantineOfficial(_ enabled: Bool) {
        trustPolicy.autoQuarantineOfficial = enabled
        trustPolicy.save()
    }

    public func approveSource(_ repo: String) {
        trustPolicy.approveSource(repo)
        trustPolicy.save()
    }

    public func revokeSource(_ repo: String) {
        trustPolicy.revokeSource(repo)
        trustPolicy.save()
    }

    public func savePreferences() {
        trustPolicy.save()
        schedulerPrefs.save()
        notificationPrefs.save()
    }
}
