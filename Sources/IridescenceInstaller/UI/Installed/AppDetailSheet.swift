import SwiftUI
import AppKit
import IridescenceCore

public struct AppDetailSheet: View {
    let app: InstalledApp
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var repositoryText: String = ""
    @State private var rollbackBackups: [RollbackEntry] = []
    @State private var isRemovingQuarantine: Bool = false
    @State private var quarantineError: String?

    public init(app: InstalledApp, appState: AppState) {
        self.app = app
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                if let iconData = app.iconData, let nsImage = NSImage(data: iconData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 36))
                        .foregroundColor(IridescenceTheme.textMuted)
                        .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        if app.isOfficialIridescence {
                            StatusBadge(.official)
                        }
                    }

                    Text(app.bundleIdentifier)
                        .font(IridescenceTheme.fontMono(size: 11))
                        .foregroundColor(IridescenceTheme.textSecondary)
                }

                Spacer()

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

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Application Info Box
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Application Details")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Text("Installed Version")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                                Text("\(app.installedVersion.description)\(app.buildVersion.map { " (build \($0))" } ?? "")")
                                    .font(IridescenceTheme.fontMono(size: 12, weight: .semibold))
                                    .foregroundColor(IridescenceTheme.textPrimary)
                            }

                            GridRow {
                                Text("Architecture")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                                StatusBadge(.architecture(app.architecture))
                            }

                            GridRow {
                                Text("Location")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                                Text(app.bundleURL.path)
                                    .font(IridescenceTheme.fontMono(size: 10))
                                    .foregroundColor(IridescenceTheme.textPrimary)
                                    .lineLimit(2)
                            }

                            GridRow {
                                Text("Quarantine Status")
                                    .font(.system(size: 12))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                                HStack {
                                    StatusBadge(app.hasQuarantine ? .quarantinePresent : .quarantineClean)

                                    if app.hasQuarantine {
                                        Button("Remove Quarantine") {
                                            removeQuarantineAction()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .disabled(isRemovingQuarantine)
                                    }
                                }
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

                    // GitHub Association Editor
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GitHub Repository Mapping")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        Text("Associate this application with a GitHub repository ('owner/repo') to check for updates.")
                            .font(.system(size: 11))
                            .foregroundColor(IridescenceTheme.textSecondary)

                        HStack {
                            TextField("owner/repo (e.g. gobelet69/Mass-Print)", text: $repositoryText)
                                .textFieldStyle(.roundedBorder)
                                .font(IridescenceTheme.fontMono(size: 12))

                            Button("Save") {
                                Task {
                                    await appState.setManualRepository(
                                        bundleIdentifier: app.bundleIdentifier,
                                        repository: repositoryText
                                    )
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .background(IridescenceTheme.cardSurface)
                    .cornerRadius(IridescenceTheme.radiusMd)
                    .overlay(
                        RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd)
                            .stroke(IridescenceTheme.hairline, lineWidth: 1)
                    )

                    // Rollback Versions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Rollback & Version History")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        if rollbackBackups.isEmpty {
                            Text("No previous version backups found for this application.")
                                .font(.system(size: 11))
                                .foregroundColor(IridescenceTheme.textMuted)
                        } else {
                            ForEach(rollbackBackups) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Version \(entry.versionString)")
                                            .font(IridescenceTheme.fontMono(size: 12, weight: .bold))
                                            .foregroundColor(IridescenceTheme.textPrimary)

                                        Text("Backed up on \(formattedDate(entry.backupDate))")
                                            .font(.system(size: 10))
                                            .foregroundColor(IridescenceTheme.textSecondary)
                                    }

                                    Spacer()

                                    Button("Restore") {
                                        Task {
                                            try? await RollbackManager.shared.restore(entry: entry)
                                            await appState.scanLocalApps()
                                            loadBackups()
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(8)
                                .background(IridescenceTheme.surfaceSubtle)
                                .cornerRadius(IridescenceTheme.radiusSm)
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
                }
                .padding(16)
            }
        }
        .frame(width: 540, height: 500)
        .background(IridescenceTheme.canvas)
        .onAppear {
            self.repositoryText = app.associatedRepository ?? ""
            loadBackups()
        }
    }

    private func loadBackups() {
        Task {
            let entries = await RollbackManager.shared.listBackups(for: app.bundleIdentifier)
            self.rollbackBackups = entries
        }
    }

    private func removeQuarantineAction() {
        isRemovingQuarantine = true
        do {
            try QuarantineManager.shared.removeQuarantine(
                bundleURL: app.bundleURL,
                expectedBundleID: app.bundleIdentifier,
                sourceRepository: app.associatedRepository ?? "manual",
                policy: TrustPolicy(autoQuarantineOfficial: true, trustedThirdPartyRepositories: [app.associatedRepository ?? "manual"])
            )
            Task {
                await appState.scanLocalApps()
            }
        } catch {
            quarantineError = error.localizedDescription
        }
        isRemovingQuarantine = false
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }
}
