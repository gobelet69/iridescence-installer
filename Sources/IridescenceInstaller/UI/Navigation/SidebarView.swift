import SwiftUI
import IridescenceCore

public struct SidebarView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        HStack(spacing: 0) {
            SidebarPanel(appState: appState)

            Divider()
                .overlay(IridescenceTheme.hairline)

            Group {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(IridescenceTheme.canvas)
        }
        .frame(minWidth: 920, minHeight: 580)
        .background(IridescenceTheme.canvas)
    }
}

public struct SidebarPanel: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header wordmark with traffic lights clearance
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
            .padding(.horizontal, 16)
            .padding(.top, 38) // Elegant clearance below native window traffic lights
            .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Custom atelier navigation items
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MANAGER")
                        .font(IridescenceTheme.fontMono(size: 10, weight: .bold))
                        .foregroundColor(IridescenceTheme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        .padding(.bottom, 4)

                    SidebarItemButton(
                        tab: .installed,
                        title: "Installed",
                        icon: NavigationTab.installed.iconName,
                        badge: "\(appState.installedApps.count)",
                        isSelected: appState.selectedTab == .installed
                    ) {
                        appState.selectedTab = .installed
                    }

                    SidebarItemButton(
                        tab: .updates,
                        title: "Updates",
                        icon: NavigationTab.updates.iconName,
                        badge: appState.pendingUpdates.isEmpty ? nil : "\(appState.pendingUpdates.count)",
                        badgeIsAlert: true,
                        isSelected: appState.selectedTab == .updates
                    ) {
                        appState.selectedTab = .updates
                    }

                    SidebarItemButton(
                        tab: .discover,
                        title: "Discover",
                        icon: NavigationTab.discover.iconName,
                        star: true,
                        isSelected: appState.selectedTab == .discover
                    ) {
                        appState.selectedTab = .discover
                    }

                    Text("PREFERENCES")
                        .font(IridescenceTheme.fontMono(size: 10, weight: .bold))
                        .foregroundColor(IridescenceTheme.textMuted)
                        .padding(.horizontal, 14)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    SidebarItemButton(
                        tab: .settings,
                        title: "Settings",
                        icon: NavigationTab.settings.iconName,
                        isSelected: appState.selectedTab == .settings
                    ) {
                        appState.selectedTab = .settings
                    }
                }
                .padding(.horizontal, 8)
            }

            // Self-Update Callout Banner (if update ready)
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
                .padding(.bottom, 8)
            }

            Spacer(minLength: 0)

            Divider()

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
            .background(IridescenceTheme.surfaceSubtle.opacity(0.3))
        }
        .frame(width: 210)
        .background(IridescenceTheme.surfaceSubtle.opacity(0.5))
    }
}

private struct SidebarItemButton: View {
    let tab: NavigationTab
    let title: String
    let icon: String
    var badge: String? = nil
    var badgeIsAlert: Bool = false
    var star: Bool = false
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? IridescenceTheme.luminousCyan : (isHovered ? IridescenceTheme.textPrimary : IridescenceTheme.textSecondary))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? IridescenceTheme.textPrimary : (isHovered ? IridescenceTheme.textPrimary : IridescenceTheme.textSecondary))

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(IridescenceTheme.fontMono(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeIsAlert ? IridescenceTheme.warmCoral : IridescenceTheme.surfaceSubtle)
                        .foregroundColor(badgeIsAlert ? Color.white : IridescenceTheme.textPrimary)
                        .clipShape(Capsule())
                } else if star {
                    Text("★")
                        .font(.system(size: 11))
                        .foregroundColor(IridescenceTheme.luminousCyan)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? IridescenceTheme.surfaceSubtle : (isHovered ? IridescenceTheme.surfaceSubtle.opacity(0.5) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Standalone visual snapshot container for test and rendering parity
public struct StandaloneSnapshotView: View {
    @ObservedObject var appState: AppState
    let tab: NavigationTab

    public init(appState: AppState, tab: NavigationTab) {
        self.appState = appState
        self.tab = tab
    }

    public var body: some View {
        SidebarView(appState: appState)
    }
}
