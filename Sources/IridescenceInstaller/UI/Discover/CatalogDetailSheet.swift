import SwiftUI
import AppKit
import IridescenceCore

public struct CatalogDetailSheet: View {
    let app: CatalogApp
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var languageFr: Bool = false

    public init(app: CatalogApp, appState: AppState) {
        self.app = app
        self.appState = appState
    }

    private var isInstalled: Bool {
        appState.installedApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private var installedApp: InstalledApp? {
        appState.installedApps.first { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private var hasUpdate: Bool {
        guard let inst = installedApp, let release = app.latestRelease else { return false }
        return release.version > inst.installedVersion
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                // Icon emblem
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(IridescenceTheme.surfaceSubtle)
                        .frame(width: 54, height: 54)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(IridescenceTheme.hairline, lineWidth: 1)
                        )

                    Circle()
                        .fill(IridescenceTheme.accentForName(app.accentColorName))
                        .frame(width: 16, height: 16)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        StatusBadge(.official)

                        if app.isFeatured {
                            Text("Featured")
                                .font(IridescenceTheme.fontMono(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(IridescenceTheme.luminousCyan.opacity(0.15))
                                .foregroundColor(IridescenceTheme.luminousCyan)
                                .clipShape(Capsule())
                        }
                    }

                    Text(languageFr ? app.taglineFr : app.taglineEn)
                        .font(.system(size: 12))
                        .foregroundColor(IridescenceTheme.textSecondary)
                }

                Spacer()

                // Language toggle (EN / FR)
                Picker("", selection: $languageFr) {
                    Text("EN").tag(false)
                    Text("FR").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 80)

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(IridescenceTheme.surfaceSubtle)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(IridescenceTheme.hairline),
                alignment: .bottom
            )

            // Body
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    Text(languageFr ? app.descriptionFr : app.descriptionEn)
                        .font(.system(size: 13))
                        .foregroundColor(IridescenceTheme.textPrimary)
                        .lineSpacing(5)

                    // Installation Action Hero Box
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            if let release = app.latestRelease {
                                Text("Latest Release: v\(release.version.displayVersion)")
                                    .font(IridescenceTheme.fontMono(size: 13, weight: .bold))
                                    .foregroundColor(IridescenceTheme.textPrimary)

                                Text(isInstalled ? "Currently installed: v\(installedApp?.installedVersion.displayVersion ?? "")" : "Not yet installed on this Mac")
                                    .font(.system(size: 11))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                            } else {
                                Text("No published releases detected yet")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textMuted)
                            }
                        }

                        Spacer()

                        if isInstalled && !hasUpdate {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(IridescenceTheme.emeraldPhosphor)
                                Text("Installed")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(IridescenceTheme.emeraldPhosphor)
                            }
                        } else {
                            Button(action: {
                                Task {
                                    await appState.installCatalogApp(app)
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: hasUpdate ? "arrow.triangle.2.circlepath" : "arrow.down.circle.fill")
                                    Text(hasUpdate ? "Update" : "Install App")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(app.latestRelease == nil)
                        }
                    }
                    .padding(14)
                    .background(IridescenceTheme.surfaceSubtle)
                    .cornerRadius(IridescenceTheme.radiusMd)

                    // In-flight installation progress
                    if let phase = appState.activeInstalls[app.bundleIdentifier] {
                        ProgressCard(phase: phase, appName: app.name)
                    }

                    // Metadata Spec
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Specifications")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Text("Repository")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                                Link(app.repository, destination: URL(string: "https://github.com/\(app.repository)")!)
                                    .font(IridescenceTheme.fontMono(size: 12))
                            }

                            GridRow {
                                Text("Bundle ID")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                                Text(app.bundleIdentifier)
                                    .font(IridescenceTheme.fontMono(size: 11))
                                    .foregroundColor(IridescenceTheme.textPrimary)
                            }

                            GridRow {
                                Text("Requires")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                                Text("macOS \(app.minimumOSVersion)+")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textPrimary)
                            }
                        }
                    }
                    .padding(14)
                    .background(IridescenceTheme.cardSurface)
                    .cornerRadius(IridescenceTheme.radiusMd)
                    .overlay(
                        RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd)
                            .stroke(IridescenceTheme.hairline, lineWidth: 1)
                    )

                    // Release notes if available
                    if let notes = app.latestRelease?.body, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Latest Release Notes")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(IridescenceTheme.textPrimary)

                            Text(notes)
                                .font(.system(size: 12))
                                .foregroundColor(IridescenceTheme.textSecondary)
                                .lineSpacing(3)
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
                .padding(16)
            }
        }
        .frame(width: 560, height: 520)
        .background(IridescenceTheme.canvas)
    }
}
