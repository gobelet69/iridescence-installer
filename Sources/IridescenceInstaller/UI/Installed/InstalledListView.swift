import SwiftUI
import AppKit
import IridescenceCore

public enum InstalledFilter: String, CaseIterable, Identifiable {
    case all = "All Installed"
    case hasUpdates = "Updates Ready"
    case quarantined = "Quarantined"

    public var id: String { rawValue }
}

public struct InstalledListView: View {
    @ObservedObject var appState: AppState
    @State private var filter: InstalledFilter = .all
    @State private var selectedApp: InstalledApp?

    public init(appState: AppState) {
        self.appState = appState
    }

    private var filteredApps: [InstalledApp] {
        var list = appState.installedApps

        switch filter {
        case .all:
            break
        case .hasUpdates:
            list = list.filter { $0.hasUpdate }
        case .quarantined:
            list = list.filter { $0.hasQuarantine }
        }

        let query = appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.bundleIdentifier.lowercased().contains(query)
            }
        }
        return list
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            PixelGridHeader(
                title: "Installed Applications",
                subtitle: "\(appState.installedApps.count) 111iridescence application\(appState.installedApps.count == 1 ? "" : "s") installed on this Mac",
                accentColor: IridescenceTheme.deepViolet
            )

            // Toolbar Filter Bar
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(IridescenceTheme.textMuted)
                    TextField("Search installed applications...", text: $appState.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(IridescenceTheme.cardSurface)
                .cornerRadius(IridescenceTheme.radiusSm)
                .overlay(
                    RoundedRectangle(cornerRadius: IridescenceTheme.radiusSm)
                        .stroke(IridescenceTheme.hairline, lineWidth: 1)
                )

                // Segmented Filter
                Picker("Filter", selection: $filter) {
                    ForEach(InstalledFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                Spacer()

                // Rescan button
                Button(action: {
                    Task {
                        await appState.scanLocalApps()
                        await appState.checkAllUpdates()
                    }
                }) {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .disabled(appState.isScanning || appState.isCheckingUpdates)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(IridescenceTheme.surfaceSubtle)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(IridescenceTheme.hairline),
                alignment: .bottom
            )

            // Content List
            if appState.isScanning && appState.installedApps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("Scanning /Applications and ~/Applications...")
                        .font(.system(size: 13))
                        .foregroundColor(IridescenceTheme.textSecondary)
                    Spacer()
                }
            } else if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "square.stack.3d.slash")
                        .font(.system(size: 32))
                        .foregroundColor(IridescenceTheme.textMuted)
                    Text("No Iridescence applications installed yet")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(IridescenceTheme.textPrimary)
                    Text("Visit the Discover tab to install apps from the 111iridescence portfolio.")
                        .font(.system(size: 12))
                        .foregroundColor(IridescenceTheme.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredApps) { app in
                            InstalledAppRow(app: app, appState: appState) {
                                selectedApp = app
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(IridescenceTheme.canvas)
        .sheet(item: $selectedApp) { app in
            AppDetailSheet(app: app, appState: appState)
        }
    }
}

struct InstalledAppRow: View {
    let app: InstalledApp
    @ObservedObject var appState: AppState
    let onInspect: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Icon
                if let iconData = app.iconData, let img = NSImage(data: iconData) {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 32))
                        .foregroundColor(IridescenceTheme.textMuted)
                        .frame(width: 38, height: 38)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        if app.isOfficialIridescence {
                            StatusBadge(.official)
                        }

                        StatusBadge(.architecture(app.architecture))

                        if app.hasQuarantine {
                            StatusBadge(.quarantinePresent)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("v\(app.installedVersion.description)")
                            .font(IridescenceTheme.fontMono(size: 11, weight: .semibold))
                            .foregroundColor(IridescenceTheme.textSecondary)

                        if let repo = app.associatedRepository {
                            Text("•  \(repo)")
                                .font(IridescenceTheme.fontMono(size: 10))
                                .foregroundColor(IridescenceTheme.textMuted)
                        }
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: 8) {
                    if let update = app.availableUpdate, update.version > app.installedVersion {
                        Button(action: {
                            Task {
                                await appState.installUpdate(for: app)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Update to v\(update.version.description)")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button("Inspect", action: onInspect)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }

            // In-flight installation progress if applicable
            if let phase = appState.activeInstalls[app.bundleIdentifier] {
                ProgressCard(phase: phase, appName: app.name)
            }
        }
        .padding(12)
        .background(IridescenceTheme.cardSurface)
        .cornerRadius(IridescenceTheme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd)
                .stroke(IridescenceTheme.hairline, lineWidth: 1)
        )
        .contextMenu {
            Button("Inspect Details") {
                onInspect()
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(app.bundleURL.path, inFileViewerRootedAtPath: "")
            }
            Button("Launch Application") {
                NSWorkspace.shared.open(app.bundleURL)
            }
        }
    }
}
