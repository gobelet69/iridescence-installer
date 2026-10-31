import Foundation
import AppKit

public actor AppScanner {
    public static let shared = AppScanner()

    private let fileManager = FileManager.default
    private let quarantineManager = QuarantineManager.shared

    // Stored manual mappings: BundleIdentifier -> GitHubRepository ("owner/repo")
    private let manualMappingsKey = "org.111iridescence.updater.manualMappings"

    public init() {}

    /// Known bundle identifier mappings for 111iridescence ecosystem apps
    public static let knownEcosystemMappings: [String: String] = [
        "com.iridecence.pdfreader": "gobelet69/iridecence-pdf-reader",
        "com.massprint.app": "gobelet69/Mass-Print",
        "com.macresourceguard.app": "gobelet69/mac-resource-guard",
        "org.111iridescence.quickpad": "gobelet69/QuickPad",
        "org.111iridescence.updater": "gobelet69/iridescence-updater"
    ]

    /// Scan standard application directories (/Applications and ~/Applications)
    public func scanInstalledApplications() async -> [InstalledApp] {
        var results: [InstalledApp] = []
        var scannedBundleIDs = Set<String>()

        let standardDirs: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]

        let manualMappings = loadManualMappings()

        for dirURL in standardDirs {
            guard fileManager.fileExists(atPath: dirURL.path) else { continue }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: dirURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for itemURL in contents {
                guard itemURL.pathExtension == "app" else { continue }

                if let app = inspectAppBundle(at: itemURL, manualMappings: manualMappings) {
                    // Prevent duplicate entries if installed in both /Applications and ~/Applications
                    if !scannedBundleIDs.contains(app.bundleIdentifier) {
                        scannedBundleIDs.insert(app.bundleIdentifier)
                        results.append(app)
                    }
                }
            }
        }

        // Sort: Official Iridescence apps first, then alphabetical by name
        return results.sorted { (lhs, rhs) -> Bool in
            if lhs.isOfficialIridescence != rhs.isOfficialIridescence {
                return lhs.isOfficialIridescence && !rhs.isOfficialIridescence
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Inspect an application bundle at a specific URL
    public func inspectAppBundle(at bundleURL: URL, manualMappings: [String: String]? = nil) -> InstalledApp? {
        let mappings = manualMappings ?? loadManualMappings()
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let bundleID = (plist["CFBundleIdentifier"] as? String) ?? bundleURL.deletingPathExtension().lastPathComponent
        let name = (plist["CFBundleDisplayName"] as? String) ??
                   (plist["CFBundleName"] as? String) ??
                   bundleURL.deletingPathExtension().lastPathComponent
        let versionStr = (plist["CFBundleShortVersionString"] as? String) ??
                         (plist["CFBundleVersion"] as? String) ??
                         "1.0.0"
        let buildStr = plist["CFBundleVersion"] as? String
        let version = AppVersion(versionStr)

        // Architecture inspection of primary executable
        var arch: BinaryArchitecture = .unknown
        if let execName = plist["CFBundleExecutable"] as? String {
            let execURL = bundleURL.appendingPathComponent("Contents/MacOS/\(execName)")
            arch = BinaryArchitecture.inspectMachO(at: execURL)
        }

        // Icon extraction (thumbnail data)
        let iconData = extractIconThumbnailData(for: bundleURL, plist: plist)

        // Association logic:
        // 1. Check user manual mappings
        // 2. Check known ecosystem mappings
        // 3. Fallback: Check if bundleID contains '111iridescence'
        var repo = mappings[bundleID]
        if repo == nil {
            repo = Self.knownEcosystemMappings[bundleID]
        }

        let isOfficial: Bool
        if let r = repo {
            isOfficial = TrustPolicy.isOfficial(repository: r)
        } else {
            isOfficial = bundleID.contains("111iridescence") || bundleID.contains("iridecence")
        }

        // Management checks
        let masReceiptURL = bundleURL.appendingPathComponent("Contents/_MASReceipt/receipt")
        let isAppStore = fileManager.fileExists(atPath: masReceiptURL.path)
        let isHomebrew = bundleURL.path.contains("/Cellar/") || bundleURL.path.contains("/Caskroom/")

        // Quarantine status
        let hasQuarantine = quarantineManager.hasQuarantine(at: bundleURL)

        return InstalledApp(
            name: name,
            bundleIdentifier: bundleID,
            bundleURL: bundleURL,
            installedVersion: version,
            buildVersion: buildStr,
            iconData: iconData,
            architecture: arch,
            associatedRepository: repo,
            isOfficialIridescence: isOfficial,
            isManagedByAppStore: isAppStore,
            isManagedByHomebrew: isHomebrew,
            hasQuarantine: hasQuarantine
        )
    }

    private func extractIconThumbnailData(for bundleURL: URL, plist: [String: Any]) -> Data? {
        if let iconName = plist["CFBundleIconFile"] as? String {
            var actualIconName = iconName
            if !actualIconName.hasSuffix(".icns") {
                actualIconName += ".icns"
            }
            let iconURL = bundleURL.appendingPathComponent("Contents/Resources/\(actualIconName)")
            if let image = NSImage(contentsOf: iconURL) {
                return thumbnailPNG(from: image)
            }
        }

        // Fallback to NSWorkspace icon for bundle
        let wsIcon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        return thumbnailPNG(from: wsIcon)
    }

    private func thumbnailPNG(from image: NSImage) -> Data? {
        let size = NSSize(width: 64, height: 64)
        let thumb = NSImage(size: size)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
        thumb.unlockFocus()

        guard let tiffData = thumb.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Manual Repository Mapping Persistence

    public func loadManualMappings() -> [String: String] {
        return (UserDefaults.standard.dictionary(forKey: manualMappingsKey) as? [String: String]) ?? [:]
    }

    public func setManualMapping(bundleIdentifier: String, repository: String) {
        var mappings = loadManualMappings()
        let cleanRepo = repository.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanRepo.isEmpty {
            mappings.removeValue(forKey: bundleIdentifier)
        } else {
            mappings[bundleIdentifier] = cleanRepo
        }
        UserDefaults.standard.set(mappings, forKey: manualMappingsKey)
    }

    public func removeManualMapping(bundleIdentifier: String) {
        var mappings = loadManualMappings()
        mappings.removeValue(forKey: bundleIdentifier)
        UserDefaults.standard.set(mappings, forKey: manualMappingsKey)
    }
}
