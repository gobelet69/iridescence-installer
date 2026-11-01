import SwiftUI
import AppKit
import IridescenceCore

@MainActor
public enum AppIconProvider {
    /// In-memory cache for loaded app icons
    private static var iconCache: [String: NSImage] = [:]

    /// Resolves an NSImage for any ecosystem application
    public static func icon(for identifier: String) -> NSImage? {
        let cleanId = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let cached = iconCache[cleanId] {
            return cached
        }

        // 1. Map canonical IDs to bundled icon filenames first for official pristine icons
        let assetName: String?
        if cleanId.contains("pdf") {
            assetName = "pdf-reader"
        } else if cleanId.contains("resource") || cleanId.contains("guard") {
            assetName = "resource-guard"
        } else if cleanId.contains("mass") || cleanId.contains("print") {
            assetName = "mass-print"
        } else if cleanId.contains("quick") || cleanId.contains("pad") {
            assetName = "quickpad"
        } else if cleanId.contains("installer") || cleanId.contains("updater") {
            assetName = "installer"
        } else {
            assetName = nil
        }

        if let name = assetName {
            // Check bundled AppIcons folder in main bundle
            let candidatePaths: [URL?] = [
                Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "AppIcons"),
                Bundle.main.url(forResource: name, withExtension: "png"),
                Bundle.main.resourceURL?.appendingPathComponent("AppIcons/\(name).png"),
                Bundle.main.resourceURL?.appendingPathComponent("\(name).png"),
                // Fallback to source directory if running in dev environment
                URL(fileURLWithPath: "/Users/theodeville/Documents/Iridescence/iridescence-installer/Resources/AppIcons/\(name).png"),
                URL(fileURLWithPath: "/Users/theodeville/Documents/Iridescence/brand/app-icons/\(name == "installer" ? "quickpad" : name)/icon-128.png")
            ]

            for candidate in candidatePaths {
                if let url = candidate, FileManager.default.fileExists(atPath: url.path),
                   let img = NSImage(contentsOf: url) {
                    iconCache[cleanId] = img
                    return img
                }
            }
        }

        // 2. Fallback to installed local app icon if available
        if let installed = AppState.shared.installedApps.first(where: {
            $0.bundleIdentifier.lowercased() == cleanId ||
            $0.name.lowercased() == cleanId
        }) {
            if let data = installed.iconData, let img = NSImage(data: data) {
                iconCache[cleanId] = img
                return img
            }
            if FileManager.default.fileExists(atPath: installed.bundleURL.path) {
                let wsIcon = NSWorkspace.shared.icon(forFile: installed.bundleURL.path)
                iconCache[cleanId] = wsIcon
                return wsIcon
            }
        }

        return nil
    }
}

/// Unified, pixel-perfect macOS app icon component for all views
public struct AppIconView: View {
    let identifier: String
    let accentColorName: String
    let size: CGFloat

    public init(identifier: String, accentColorName: String = "electricBlue", size: CGFloat = 36) {
        self.identifier = identifier
        self.accentColorName = accentColorName
        self.size = size
    }

    public var body: some View {
        if let image = AppIconProvider.icon(for: identifier) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(IridescenceTheme.surfaceSubtle)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .stroke(IridescenceTheme.hairline, lineWidth: 1)
                    )

                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundColor(IridescenceTheme.accentForName(accentColorName))
            }
        }
    }
}
