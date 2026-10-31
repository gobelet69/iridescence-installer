import SwiftUI
import AppKit
import IridescenceCore

public enum CatalogFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case featured = "Featured"
    case beta = "Beta"

    public var id: String { rawValue }
}

public struct DiscoverCatalogView: View {
    @ObservedObject var appState: AppState
    @State private var filter: CatalogFilter = .all
    @State private var selectedApp: CatalogApp?

    public init(appState: AppState) {
        self.appState = appState
    }

    private var filteredApps: [CatalogApp] {
        var list = appState.catalogApps

        switch filter {
        case .all:
            break
        case .featured:
            list = list.filter { $0.isFeatured }
        case .beta:
            list = list.filter { $0.isBeta || $0.latestBetaRelease != nil }
        }

        let query = appState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(query) ||
                $0.descriptionEn.lowercased().contains(query) ||
                $0.taglineEn.lowercased().contains(query)
            }
        }
        return list
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            PixelGridHeader(
                title: "Discover 111iridescence",
                subtitle: "Curated native macOS software from the official ecosystem",
                accentColor: IridescenceTheme.luminousCyan
            )

            // Toolbar
            HStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(IridescenceTheme.textMuted)
                    TextField("Search catalog...", text: $appState.searchQuery)
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

                // Filter
                Picker("Filter", selection: $filter) {
                    ForEach(CatalogFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)

                Spacer()

                Button(action: {
                    Task {
                        await appState.refreshCatalog()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(IridescenceTheme.surfaceSubtle)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(IridescenceTheme.hairline),
                alignment: .bottom
            )

            // Grid of App Cards
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Featured Lead Card
                    if let lead = appState.catalogApps.first(where: { $0.isFeatured }) {
                        FeaturedHeroCard(app: lead, appState: appState) {
                            selectedApp = lead
                        }
                    }

                    Text("All Applications")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(IridescenceTheme.textPrimary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                        ForEach(filteredApps) { app in
                            CatalogAppCard(app: app, appState: appState) {
                                selectedApp = app
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(IridescenceTheme.canvas)
        .sheet(item: $selectedApp) { app in
            CatalogDetailSheet(app: app, appState: appState)
        }
    }
}

struct FeaturedHeroCard: View {
    let app: CatalogApp
    @ObservedObject var appState: AppState
    let onSelect: () -> Void

    private var isInstalled: Bool {
        appState.installedApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(IridescenceTheme.deepViolet.opacity(0.12))
                    .frame(width: 64, height: 64)

                Circle()
                    .fill(IridescenceTheme.accentForName(app.accentColorName))
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("FEATURED APPLICATION")
                        .font(IridescenceTheme.fontMono(size: 9, weight: .bold))
                        .foregroundColor(IridescenceTheme.luminousCyan)

                    StatusBadge(.official)
                }

                Text(app.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                Text(app.taglineEn)
                    .font(.system(size: 12))
                    .foregroundColor(IridescenceTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let release = app.latestRelease {
                    Text("v\(release.version.displayVersion)")
                        .font(IridescenceTheme.fontMono(size: 11, weight: .bold))
                        .foregroundColor(IridescenceTheme.textSecondary)
                }

                Button(action: onSelect) {
                    Text(isInstalled ? "View Details" : "Discover & Install")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(16)
        .background(IridescenceTheme.cardSurface)
        .cornerRadius(IridescenceTheme.radiusLg)
        .overlay(
            RoundedRectangle(cornerRadius: IridescenceTheme.radiusLg)
                .stroke(IridescenceTheme.hairline, lineWidth: 1)
        )
    }
}

struct CatalogAppCard: View {
    let app: CatalogApp
    @ObservedObject var appState: AppState
    let onSelect: () -> Void

    private var isInstalled: Bool {
        appState.installedApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(IridescenceTheme.surfaceSubtle)
                        .frame(width: 36, height: 36)

                    Circle()
                        .fill(IridescenceTheme.accentForName(app.accentColorName))
                        .frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(IridescenceTheme.textPrimary)

                    if let release = app.latestRelease {
                        Text("v\(release.version.displayVersion)")
                            .font(IridescenceTheme.fontMono(size: 10))
                            .foregroundColor(IridescenceTheme.textMuted)
                    }
                }

                Spacer()

                if app.isFeatured {
                    Text("★")
                        .font(.system(size: 12))
                        .foregroundColor(IridescenceTheme.luminousCyan)
                }
            }

            Text(app.taglineEn)
                .font(.system(size: 12))
                .foregroundColor(IridescenceTheme.textSecondary)
                .lineLimit(2)
                .frame(minHeight: 32, alignment: .topLeading)

            // Progress bar if downloading
            if let phase = appState.activeInstalls[app.bundleIdentifier] {
                ProgressCard(phase: phase, appName: app.name)
            }

            HStack {
                if isInstalled {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(IridescenceTheme.emeraldPhosphor)
                        Text("Installed")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(IridescenceTheme.emeraldPhosphor)
                    }
                } else {
                    Button("Install") {
                        Task {
                            await appState.installCatalogApp(app)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(app.latestRelease == nil)
                }

                Spacer()

                Button("Details", action: onSelect)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
