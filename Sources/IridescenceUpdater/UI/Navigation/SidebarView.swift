import SwiftUI
import IridescenceCore

public struct SidebarView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Sidebar header wordmark
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(IridescenceTheme.surfaceSubtle)
                            .frame(width: 24, height: 24)

                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(IridescenceTheme.luminousCyan)
                    }

                    Text("111iridescence.")
                        .font(IridescenceTheme.fontMono(size: 13, weight: .bold))
                        .foregroundColor(IridescenceTheme.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                Divider()

                // Sidebar Navigation items
                List(selection: $appState.selectedTab) {
                    Section("Manager") {
                        NavigationLink(value: NavigationTab.installed) {
                            HStack {
                                Label("Installed", systemImage: NavigationTab.installed.iconName)
                                Spacer()
                                Text("\(appState.installedApps.count)")
                                    .font(IridescenceTheme.fontMono(size: 10, weight: .semibold))
                                    .foregroundColor(IridescenceTheme.textMuted)
                            }
                        }

                        NavigationLink(value: NavigationTab.updates) {
                            HStack {
                                Label("Updates", systemImage: NavigationTab.updates.iconName)
                                Spacer()
                                if !appState.pendingUpdates.isEmpty {
                                    Text("\(appState.pendingUpdates.count)")
                                        .font(IridescenceTheme.fontMono(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(IridescenceTheme.warmCoral)
                                        .foregroundColor(Color.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        NavigationLink(value: NavigationTab.discover) {
                            HStack {
                                Label("Discover", systemImage: NavigationTab.discover.iconName)
                                Spacer()
                                Text("★")
                                    .font(.system(size: 11))
                                    .foregroundColor(IridescenceTheme.luminousCyan)
                            }
                        }
                    }

                    Section("Preferences") {
                        NavigationLink(value: NavigationTab.settings) {
                            Label("Settings", systemImage: NavigationTab.settings.iconName)
                        }
                    }
                }
                .listStyle(.sidebar)

                Spacer()

                // Bottom rate limit telemetry footer
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.rateLimitRemaining > 10 ? IridescenceTheme.emeraldPhosphor : Color.orange)
                        .frame(width: 6, height: 6)

                    Text("GitHub API: \(appState.rateLimitRemaining) rem")
                        .font(IridescenceTheme.fontMono(size: 9))
                        .foregroundColor(IridescenceTheme.textMuted)

                    Spacer()

                    Text("v1.0.0")
                        .font(IridescenceTheme.fontMono(size: 9))
                        .foregroundColor(IridescenceTheme.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(IridescenceTheme.surfaceSubtle.opacity(0.4))
            }
            .frame(minWidth: 190, idealWidth: 210, maxWidth: 240)
        } detail: {
            switch appState.selectedTab {
            case .installed:
                InstalledListView(appState: appState)
            case .updates:
                UpdatesListView(appState: appState)
            case .discover:
                DiscoverCatalogView(appState: appState)
            case .settings:
                SettingsView(appState: appState)
            }
        }
        .frame(minWidth: 840, minHeight: 540)
    }
}
