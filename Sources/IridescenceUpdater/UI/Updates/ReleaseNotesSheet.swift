import SwiftUI
import IridescenceCore

public struct ReleaseNotesSheet: View {
    let release: ReleaseItem
    let appName: String
    @Environment(\.dismiss) private var dismiss

    public init(release: ReleaseItem, appName: String) {
        self.release = release
        self.appName = appName
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(appName) \(release.version.description)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(IridescenceTheme.textPrimary)

                        if release.isPrerelease {
                            StatusBadge(.beta)
                        } else {
                            StatusBadge(.stable)
                        }
                    }

                    Text("Published on \(formattedDate(release.publishedAt))")
                        .font(.system(size: 11))
                        .foregroundColor(IridescenceTheme.textSecondary)
                }

                Spacer()

                Button("Close") {
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

            // Release Notes Body
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if release.body.isEmpty {
                        Text("No release notes provided for this version.")
                            .font(.system(size: 13))
                            .foregroundColor(IridescenceTheme.textMuted)
                    } else {
                        Text(release.body)
                            .font(.system(size: 13))
                            .foregroundColor(IridescenceTheme.textPrimary)
                            .lineSpacing(4)
                    }

                    Divider()

                    // Assets list
                    Text("Release Assets")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(IridescenceTheme.textPrimary)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(release.assets) { asset in
                            HStack {
                                Image(systemName: assetIcon(for: asset.kind))
                                    .foregroundColor(IridescenceTheme.electricBlue)

                                Text(asset.name)
                                    .font(IridescenceTheme.fontMono(size: 11))
                                    .foregroundColor(IridescenceTheme.textPrimary)

                                Spacer()

                                StatusBadge(.architecture(asset.architecture))

                                Text(formattedBytes(asset.size))
                                    .font(IridescenceTheme.fontMono(size: 10))
                                    .foregroundColor(IridescenceTheme.textSecondary)
                            }
                            .padding(8)
                            .background(IridescenceTheme.cardSurface)
                            .cornerRadius(IridescenceTheme.radiusSm)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 520, height: 460)
        .background(IridescenceTheme.canvas)
    }

    private func assetIcon(for kind: AssetKind) -> String {
        switch kind {
        case .dmg: return "opticaldiscdrive"
        case .zip: return "doc.zipper"
        case .pkg: return "shippingbox"
        case .checksum: return "checkmark.shield"
        case .unknown: return "doc"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
}
