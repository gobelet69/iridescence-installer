import SwiftUI
import AppKit
import IridescenceCore

public enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General"
    case updates = "Updates"
    case security = "Security & Quarantine"
    case github = "GitHub & Sources"
    case storage = "Storage & Rollback"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .updates: return "arrow.triangle.2.circlepath"
        case .security: return "lock.shield"
        case .github: return "network"
        case .storage: return "externaldrive"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedSection: SettingsSection = .security

    @State private var gitHubTokenText: String = ""
    @State private var newThirdPartyRepoText: String = ""
    @State private var rollbackList: [RollbackEntry] = []
    @State private var showQuarantineExplanation: Bool = false

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Standard Atelier Header with pixel grid
            PixelGridHeader(
                title: "Settings & Preferences",
                subtitle: "Manage security quarantine, update policies, and local storage",
                accentColor: IridescenceTheme.deepViolet
            )

            // Horizontal Category Selector Tab Bar
            HStack(spacing: 6) {
                ForEach(SettingsSection.allCases) { section in
                    Button(action: { selectedSection = section }) {
                        HStack(spacing: 6) {
                            Image(systemName: section.iconName)
                                .font(.system(size: 11))
                            Text(section.rawValue)
                                .font(.system(size: 11, weight: selectedSection == section ? .semibold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedSection == section ? IridescenceTheme.surfaceSubtle : Color.clear)
                        )
                        .foregroundColor(selectedSection == section ? IridescenceTheme.textPrimary : IridescenceTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(IridescenceTheme.surfaceSubtle.opacity(0.3))

            Divider()

            // Full-Width Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedSection {
                    case .general:
                        generalSection
                    case .updates:
                        updatesSection
                    case .security:
                        securitySection
                    case .github:
                        githubSection
                    case .storage:
                        storageSection
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(IridescenceTheme.canvas)
        }
        .onAppear {
            Task {
                gitHubTokenText = await GitHubClient.shared.getGitHubToken() ?? ""
                rollbackList = await RollbackManager.shared.listBackups()
            }
        }
    }

    // MARK: - General Section
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader("General Preferences", subtitle: "Configure appearance, notifications, and startup options.")

            VStack(alignment: .leading, spacing: 12) {
                Text("Notifications")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                Toggle("Notify when new Iridescence applications are discovered", isOn: $appState.notificationPrefs.notifyNewApps)
                Toggle("Notify when stable updates are available", isOn: $appState.notificationPrefs.notifyStableUpdates)
                Toggle("Notify when beta updates are available", isOn: $appState.notificationPrefs.notifyBetaUpdates)
                Toggle("Notify on completed installations", isOn: $appState.notificationPrefs.notifyInstallCompleted)
                Toggle("Notify on installation failures", isOn: $appState.notificationPrefs.notifyInstallFailed)
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))
            .onChange(of: appState.notificationPrefs.notifyNewApps) { _ in appState.savePreferences() }
        }
    }

    // MARK: - Updates Section
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader("Update Channels & Schedules", subtitle: "Manage stable vs. beta updates and background checking frequency.")

            VStack(alignment: .leading, spacing: 14) {
                Picker("Release Channel", selection: $appState.schedulerPrefs.globalReleaseChannel) {
                    Text("Stable Only (Recommended)").tag(ReleaseChannel.stable)
                    Text("Stable + Beta (Pre-releases)").tag(ReleaseChannel.beta)
                }
                .pickerStyle(.radioGroup)

                Divider()

                Toggle("Automatically check for updates in the background", isOn: $appState.schedulerPrefs.autoCheckEnabled)

                if appState.schedulerPrefs.autoCheckEnabled {
                    Picker("Check Frequency", selection: $appState.schedulerPrefs.checkIntervalHours) {
                        Text("Every 4 Hours").tag(4)
                        Text("Every 8 Hours (Default)").tag(8)
                        Text("Every 24 Hours").tag(24)
                    }
                    .frame(width: 250)
                }

                Toggle("Automatically install updates when ready", isOn: $appState.schedulerPrefs.autoInstallUpdates)
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))
            .onChange(of: appState.schedulerPrefs.globalReleaseChannel) { _ in appState.savePreferences() }
            .onChange(of: appState.schedulerPrefs.autoCheckEnabled) { _ in appState.savePreferences() }

            // Iridescence Installer Self-Update Box
            VStack(alignment: .leading, spacing: 10) {
                Text("Iridescence Installer Self-Update")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Installed Version: v\(appState.currentAppVersion)")
                            .font(IridescenceTheme.fontMono(size: 12, weight: .semibold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        if let rel = appState.selfUpdateRelease {
                            Text("New version available: v\(rel.version.displayVersion)")
                                .font(.system(size: 11))
                                .foregroundColor(IridescenceTheme.luminousCyan)
                        } else {
                            Text("Iridescence Installer is up to date.")
                                .font(.system(size: 11))
                                .foregroundColor(IridescenceTheme.textSecondary)
                        }
                    }

                    Spacer()

                    if appState.selfUpdateRelease != nil {
                        Button("Self-Update Now") {
                            Task {
                                await appState.triggerSelfUpdate()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("Check for Updates") {
                            Task {
                                await appState.checkSelfUpdate()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Security & Quarantine Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader("Security & Quarantine Policy", subtitle: "Configure trust levels and Gatekeeper quarantine removal for unsigned applications.")

            // Master Quarantine Handling Toggle
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { appState.trustPolicy.autoQuarantineOfficial },
                    set: { appState.toggleQuarantineOfficial($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatically handle quarantine for trusted unsigned apps")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        Text("Removes macOS quarantine attribute from validated bundles installed from trusted official sources.")
                            .font(.system(size: 11))
                            .foregroundColor(IridescenceTheme.textSecondary)
                    }
                }

                HStack {
                    Image(systemName: "exclamationmark.shield")
                        .foregroundColor(Color.orange)
                    Text("Notice: Iridescence applications are distributed unsigned without Apple Developer ID. Enabling this removes Gatekeeper approval prompts for verified sources.")
                        .font(.system(size: 11))
                        .foregroundColor(IridescenceTheme.textSecondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))

            // Official Source Trust
            VStack(alignment: .leading, spacing: 10) {
                Text("Verified Official Publisher")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GitHub Owner: \(TrustPolicy.officialOwner)")
                            .font(IridescenceTheme.fontMono(size: 12, weight: .semibold))
                            .foregroundColor(IridescenceTheme.textPrimary)
                        Text("Official ecosystem repositories (e.g. gobelet69/iridecence-pdf-reader)")
                            .font(.system(size: 11))
                            .foregroundColor(IridescenceTheme.textSecondary)
                    }
                    Spacer()
                    StatusBadge(.official)
                }
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))

            // Third-Party Sources Trust
            VStack(alignment: .leading, spacing: 12) {
                Text("Approved Third-Party Sources")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                Text("Third-party repositories require explicit approval before any quarantine removal is permitted.")
                    .font(.system(size: 11))
                    .foregroundColor(IridescenceTheme.textSecondary)

                HStack {
                    TextField("owner/repo (e.g. contributor/custom-tool)", text: $newThirdPartyRepoText)
                        .textFieldStyle(.roundedBorder)
                        .font(IridescenceTheme.fontMono(size: 11))

                    Button("Approve Source") {
                        let clean = newThirdPartyRepoText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty {
                            appState.approveSource(clean)
                            newThirdPartyRepoText = ""
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if appState.trustPolicy.trustedThirdPartyRepositories.isEmpty {
                    Text("No third-party sources currently approved.")
                        .font(.system(size: 11))
                        .foregroundColor(IridescenceTheme.textMuted)
                } else {
                    ForEach(Array(appState.trustPolicy.trustedThirdPartyRepositories).sorted(), id: \.self) { repo in
                        HStack {
                            Text(repo)
                                .font(IridescenceTheme.fontMono(size: 11, weight: .semibold))
                                .foregroundColor(IridescenceTheme.textPrimary)
                            Spacer()
                            Button("Revoke") {
                                appState.revokeSource(repo)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(IridescenceTheme.surfaceSubtle)
                        .cornerRadius(6)
                    }
                }
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))
        }
    }

    // MARK: - GitHub Section
    private var githubSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader("GitHub & Rate Limiting", subtitle: "Configure GitHub API authentication and check rate limit quotas.")

            VStack(alignment: .leading, spacing: 12) {
                Text("GitHub Personal Access Token (Optional)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                Text("Anonymous requests are limited to 60/hr. Adding a token with 'public_repo' read access increases your quota to 5,000/hr.")
                    .font(.system(size: 11))
                    .foregroundColor(IridescenceTheme.textSecondary)

                HStack {
                    SecureField("ghp_...", text: $gitHubTokenText)
                        .textFieldStyle(.roundedBorder)
                        .font(IridescenceTheme.fontMono(size: 11))

                    Button("Save Token") {
                        Task {
                            await GitHubClient.shared.setGitHubToken(gitHubTokenText)
                            await appState.checkAllUpdates()
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    Text("API Rate Limit Remaining:")
                        .font(.system(size: 12))
                        .foregroundColor(IridescenceTheme.textSecondary)
                    Text("\(appState.rateLimitRemaining) requests")
                        .font(IridescenceTheme.fontMono(size: 12, weight: .bold))
                        .foregroundColor(appState.rateLimitRemaining > 10 ? IridescenceTheme.emeraldPhosphor : Color.red)
                }
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))
        }
    }

    // MARK: - Storage & Rollback Section
    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsHeader("Storage & Rollback", subtitle: "Manage historical app backups and temporary download caches.")

            VStack(alignment: .leading, spacing: 12) {
                Text("Historical Rollback Backups (\(rollbackList.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(IridescenceTheme.textPrimary)

                if rollbackList.isEmpty {
                    Text("No version backups stored currently.")
                        .font(.system(size: 11))
                        .foregroundColor(IridescenceTheme.textMuted)
                } else {
                    ForEach(rollbackList) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(entry.appName) v\(entry.versionString)")
                                    .font(IridescenceTheme.fontMono(size: 11, weight: .bold))
                                    .foregroundColor(IridescenceTheme.textPrimary)
                                Text(entry.bundleIdentifier)
                                    .font(.system(size: 10))
                                    .foregroundColor(IridescenceTheme.textMuted)
                            }
                            Spacer()
                            Button("Delete") {
                                Task {
                                    await RollbackManager.shared.deleteBackup(entry)
                                    rollbackList = await RollbackManager.shared.listBackups()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(8)
                        .background(IridescenceTheme.surfaceSubtle)
                        .cornerRadius(6)
                    }
                }
            }
            .padding(14)
            .background(IridescenceTheme.cardSurface)
            .cornerRadius(IridescenceTheme.radiusMd)
            .overlay(RoundedRectangle(cornerRadius: IridescenceTheme.radiusMd).stroke(IridescenceTheme.hairline, lineWidth: 1))
        }
    }

    private func settingsHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(IridescenceTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(IridescenceTheme.textSecondary)
        }
    }
}
