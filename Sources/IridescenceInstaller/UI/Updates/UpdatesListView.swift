import SwiftUI
import AppKit
import IridescenceCore

public struct UpdatesListView: View {
    @ObservedObject var appState: AppState
    @State private var inspectingRelease: (ReleaseItem, String)?

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            PixelGridHeader(
                title: "Software Updates",
                subtitle: appState.pendingUpdates.isEmpty ? "All applications are up to date" : "\(appState.pendingUpdates.count) update\(appState.pendingUpdates.count == 1 ? "" : "s") available",
                accentColor: IridescenceTheme.electricBlue
            )

            // Action Bar
            HStack(spacing: 12) {
                if !appState.pendingUpdates.isEmpty {
                    Button(action: {
                        Task {
                            await appState.updateAllPending()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Update All (\(appState.pendingUpdates.count))")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                Spacer()

                Button(action: {
                    Task {
                        await appState.checkAllUpdates()
                    }
                }) {
                    Label("Check Now", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isCheckingUpdates)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(IridescenceTheme.surfaceSubtle)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(IridescenceTheme.hairline),
                alignment: .bottom
            )

            // Content
            if appState.isCheckingUpdates && appState.pendingUpdates.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Checking GitHub releases for updates...")
                        .font(.system(size: 13))
                        .foregroundColor(IridescenceTheme.textSecondary)
                    Spacer()
                }
            } else if appState.pendingUpdates.isEmpty && appState.selfUpdateRelease == nil {
                VStack(spacing: 12) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(IridescenceTheme.emeraldPhosphor.opacity(0.12))
                            .frame(width: 56, height: 56)

                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(IridescenceTheme.emeraldPhosphor)
                    }

                    Text("Everything is up to date")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(IridescenceTheme.textPrimary)

                    Text("All tracked Iridescence applications match the latest published releases.")
                        .font(.system(size: 12))
                        .foregroundColor(IridescenceTheme.textSecondary)

                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let selfRel = appState.selfUpdateRelease {
                            SelfUpdateCardView(release: selfRel, appState: appState)
                        }

                        ForEach(appState.pendingUpdates) { app in
                            if let update = app.availableUpdate {
                                UpdateRowView(
                                    app: app,
                                    release: update,
                                    appState: appState,
                                    onViewNotes: {
                                        inspectingRelease = (update, app.name)
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(IridescenceTheme.canvas)
        .sheet(item: Binding<ReleaseItem?>(
            get: { inspectingRelease?.0 },
            set: { _ in inspectingRelease = nil }
        )) { release in
            ReleaseNotesSheet(release: release, appName: inspectingRelease?.1 ?? "")
        }
    }
}

struct UpdateRowView: View {
    let app: InstalledApp
    let release: ReleaseItem
    @ObservedObject var appState: AppState
    let onViewNotes: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Icon
                AppIconView(identifier: app.bundleIdentifier, size: 42)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        if release.isPrerelease {
                            StatusBadge(.beta)
                        } else {
                            StatusBadge(.stable)
                        }

                        if app.isOfficialIridescence {
                            StatusBadge(.official)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("v\(app.installedVersion.description)")
                            .font(IridescenceTheme.fontMono(size: 11))
                            .foregroundColor(IridescenceTheme.textMuted)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundColor(IridescenceTheme.textMuted)

                        Text("v\(release.version.description)")
                            .font(IridescenceTheme.fontMono(size: 11, weight: .bold))
                            .foregroundColor(IridescenceTheme.electricBlue)
                    }
                }

                Spacer()

                // Buttons
                HStack(spacing: 8) {
                    Button("Release Notes", action: onViewNotes)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("Update") {
                        Task {
                            await appState.installUpdate(for: app)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            // In-flight progress
            if let phase = appState.activeInstalls[app.bundleIdentifier] {
                ProgressCard(phase: phase, appName: app.name)
            }
        }
        .padding(14)
        .background(IridescenceTheme.cardSurface)
        .cornerRadius(IridescenceTheme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd)
                .stroke(IridescenceTheme.hairline, lineWidth: 1)
        )
    }
}

struct SelfUpdateCardView: View {
    let release: ReleaseItem
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AppIconView(identifier: SelfUpdateManager.installerBundleID, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Iridescence Installer (Self-Update)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        StatusBadge(.official)
                    }

                    HStack(spacing: 6) {
                        Text("Current v\(appState.currentAppVersion)")
                            .font(IridescenceTheme.fontMono(size: 11))
                            .foregroundColor(IridescenceTheme.textMuted)

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundColor(IridescenceTheme.textMuted)

                        Text("v\(release.version.displayVersion)")
                            .font(IridescenceTheme.fontMono(size: 11, weight: .bold))
                            .foregroundColor(IridescenceTheme.luminousCyan)
                    }
                }

                Spacer()

                Button("Self-Update Now") {
                    Task {
                        await appState.triggerSelfUpdate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(IridescenceTheme.cardSurface)
        .cornerRadius(IridescenceTheme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd)
                .stroke(IridescenceTheme.luminousCyan.opacity(0.5), lineWidth: 1.2)
        )
    }
}
