import SwiftUI
import IridescenceCore

public struct SidebarView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        NavigationSplitView {
            SidebarPanel(appState: appState)
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

public struct SidebarPanel: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
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

                Text("111 Installer.")
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

            // Self-Update Callout Banner
            if let selfRel = appState.selfUpdateRelease {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundColor(IridescenceTheme.luminousCyan)
                        Text("Self-Update")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)
                    }
                    Text("Installer v\(selfRel.version.displayVersion) ready")
                        .font(IridescenceTheme.fontMono(size: 10))
                        .foregroundColor(IridescenceTheme.textSecondary)

                    Button(action: {
                        Task {
                            await appState.triggerSelfUpdate()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Update Now")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(10)
                .background(IridescenceTheme.cardSurface)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(IridescenceTheme.luminousCyan.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }

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
    }
}

/// Standalone visual snapshot container that can be rendered offscreen cleanly by ImageRenderer
public struct StandaloneSnapshotView: View {
    @ObservedObject var appState: AppState
    let tab: NavigationTab

    public init(appState: AppState, tab: NavigationTab) {
        self.appState = appState
        self.tab = tab
    }

    public var body: some View {
        HStack(spacing: 0) {
            SidebarPanel(appState: appState)
                .frame(width: 220)
                .background(IridescenceTheme.surfaceSubtle.opacity(0.2))

            Divider()

            Group {
                switch tab {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 860, height: 560)
        .background(IridescenceTheme.canvas)
    }
}
