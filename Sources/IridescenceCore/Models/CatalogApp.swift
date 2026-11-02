import Foundation

public struct CatalogApp: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var shortName: String
    public var taglineEn: String
    public var taglineFr: String
    public var descriptionEn: String
    public var descriptionFr: String
    public var repository: String
    public var bundleIdentifier: String
    public var minimumOSVersion: String
    public var accentColorName: String
    public var isFeatured: Bool
    public var isBeta: Bool
    public var iconURL: URL?
    public var latestRelease: ReleaseItem?
    public var latestBetaRelease: ReleaseItem?

    public init(
        id: String,
        name: String,
        shortName: String,
        taglineEn: String,
        taglineFr: String,
        descriptionEn: String,
        descriptionFr: String,
        repository: String,
        bundleIdentifier: String,
        minimumOSVersion: String = "13.0",
        accentColorName: String = "violet",
        isFeatured: Bool = false,
        isBeta: Bool = false,
        iconURL: URL? = nil,
        latestRelease: ReleaseItem? = nil,
        latestBetaRelease: ReleaseItem? = nil
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.taglineEn = taglineEn
        self.taglineFr = taglineFr
        self.descriptionEn = descriptionEn
        self.descriptionFr = descriptionFr
        self.repository = repository
        self.bundleIdentifier = bundleIdentifier
        self.minimumOSVersion = minimumOSVersion
        self.accentColorName = accentColorName
        self.isFeatured = isFeatured
        self.isBeta = isBeta
        self.iconURL = iconURL
        self.latestRelease = latestRelease
        self.latestBetaRelease = latestBetaRelease
    }

    /// Primary localized description helper
    public func localizedDescription(locale: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        return locale.lowercased().hasPrefix("fr") ? descriptionFr : descriptionEn
    }

    /// Primary localized tagline helper
    public func localizedTagline(locale: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        return locale.lowercased().hasPrefix("fr") ? taglineFr : taglineEn
    }

    /// Canonical seed catalog matching 111iridescence registry and website
    public static let defaultSeeds: [CatalogApp] = [
        CatalogApp(
            id: "iridescence-pdf-reader",
            name: "Iridescence PDF Reader",
            shortName: "PDF Reader",
            taglineEn: "Read fast. Stay focused.",
            taglineFr: "Lire vite. Rester concentré.",
            descriptionEn: "Native macOS PDF reader built for speed, fluid navigation, and zero distraction.",
            descriptionFr: "Un lecteur PDF natif pour macOS, conçu pour une lecture rapide, fluide et sans distraction.",
            repository: "gobelet69/iridecence-pdf-reader",
            bundleIdentifier: "com.iridecence.pdfreader",
            minimumOSVersion: "14.0",
            accentColorName: "violet",
            isFeatured: true
        ),
        CatalogApp(
            id: "mass-print",
            name: "Mass Print",
            shortName: "Mass Print",
            taglineEn: "Print hundreds of PDFs safely in one click.",
            taglineFr: "Imprimez des centaines de PDF en un clic.",
            descriptionEn: "Native batch printing utility with print safety, page counts, and total file ordering control.",
            descriptionFr: "Utilitaire d'impression par lots natif avec contrôle de l'ordre des pages et sécurité d'impression.",
            repository: "gobelet69/Mass-Print",
            bundleIdentifier: "com.massprint.app",
            minimumOSVersion: "13.0",
            accentColorName: "blue",
            isFeatured: true
        ),
        CatalogApp(
            id: "resource-guard",
            name: "Mac Resource Guard",
            shortName: "Resource Guard",
            taglineEn: "Compact macOS resource monitor & battery saver.",
            taglineFr: "Moniteur de ressources macOS compact et économe.",
            descriptionEn: "Lightweight menu bar telemetry for CPU, memory, battery temperature, and rogue process alerts.",
            descriptionFr: "Télémétrie légère dans la barre des menus pour le processeur, la mémoire et les alertes d'emballement.",
            repository: "gobelet69/mac-resource-guard",
            bundleIdentifier: "com.macresourceguard.app",
            minimumOSVersion: "13.0",
            accentColorName: "presence",
            isFeatured: true
        ),
        CatalogApp(
            id: "quickpad",
            name: "QuickPad",
            shortName: "QuickPad",
            taglineEn: "Instant distraction-free notes for macOS.",
            taglineFr: "Notes instantanées et épurées pour macOS.",
            descriptionEn: "High-speed native plain-text scratchpad engineered for rapid capture and zero-latency editing.",
            descriptionFr: "Bloc-notes natif ultra-rapide conçu pour la saisie instantanée sans latence.",
            repository: "gobelet69/quickpad",
            bundleIdentifier: "org.111iridescence.quickpad",
            minimumOSVersion: "13.0",
            accentColorName: "ultraviolet",
            isFeatured: false
        ),
        CatalogApp(
            id: "iridescence-installer",
            name: "Iridescence Installer",
            shortName: "Installer",
            taglineEn: "Native macOS app manager & unsigned installer.",
            taglineFr: "Gestionnaire natif et installateur d'apps non signées.",
            descriptionEn: "Autonomous installer and updater for 111iridescence ecosystem software with safe quarantine removal.",
            descriptionFr: "Installateur et mise à jour autonomes pour l'écosystème 111iridescence avec gestion sécurisée de la quarantaine.",
            repository: "gobelet69/iridescence-installer",
            bundleIdentifier: "org.111iridescence.installer",
            minimumOSVersion: "13.0",
            accentColorName: "cyan",
            isFeatured: false
        )
    ]
}
