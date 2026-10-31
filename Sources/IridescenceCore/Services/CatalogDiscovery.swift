import Foundation

public actor CatalogDiscovery {
    public static let shared = CatalogDiscovery()

    private let fileManager = FileManager.default
    private let cacheURL: URL

    private var catalog: [String: CatalogApp] = [:]
    private var knownAppIDs: Set<String> = []

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let newCache = appSupport.appendingPathComponent("IridescenceInstaller/catalog.json")
        let oldCache = appSupport.appendingPathComponent("IridescenceUpdater/catalog.json")
        if !FileManager.default.fileExists(atPath: newCache.path) && FileManager.default.fileExists(atPath: oldCache.path) {
            try? FileManager.default.createDirectory(at: newCache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.copyItem(at: oldCache, to: newCache)
        }
        self.cacheURL = newCache

        var initialCatalog: [String: CatalogApp] = [:]
        var initialKnownIDs = Set<String>()

        // Preload default seeds
        for app in CatalogApp.defaultSeeds {
            initialCatalog[app.id] = app
            initialKnownIDs.insert(app.id)
        }

        // Load cached if available
        if let data = try? Data(contentsOf: newCache),
           let cached = try? JSONDecoder().decode([CatalogApp].self, from: data) {
            for item in cached {
                initialCatalog[item.id] = item
                initialKnownIDs.insert(item.id)
            }
        }

        self.catalog = initialCatalog
        self.knownAppIDs = initialKnownIDs
    }

    /// Refresh catalog from GitHub discovery and releases
    /// Returns any newly discovered apps that weren't previously known
    public func refreshCatalog() async -> [CatalogApp] {
        var newlyDiscovered: [CatalogApp] = []

        // 1. Fetch official repositories from GitHub
        if let repos = try? await GitHubClient.shared.fetchOfficialRepositories() {
            for repoDict in repos {
                guard let name = repoDict["name"] as? String,
                      let fullName = repoDict["full_name"] as? String else {
                    continue
                }
                let description = (repoDict["description"] as? String) ?? ""

                // Check topics
                var topics: [String] = []
                if let rawTopics = repoDict["topics"] as? [String] {
                    topics = rawTopics
                } else if let fetchedTopics = try? await GitHubClient.shared.fetchTopics(for: fullName) {
                    topics = fetchedTopics
                }

                let isOfficialCandidate = topics.contains("iridescence-app") ||
                                          CatalogApp.defaultSeeds.contains(where: { $0.repository.caseInsensitiveCompare(fullName) == .orderedSame })

                guard isOfficialCandidate else { continue }

                let isFeatured = topics.contains("iridescence-featured") ||
                                 (CatalogApp.defaultSeeds.first(where: { $0.repository.caseInsensitiveCompare(fullName) == .orderedSame })?.isFeatured ?? false)
                let isBeta = topics.contains("iridescence-beta")

                // Find if an app already exists in catalog for this repository
                if let existingKey = catalog.first(where: { $0.value.repository.caseInsensitiveCompare(fullName) == .orderedSame })?.key {
                    catalog[existingKey]?.isFeatured = isFeatured
                    catalog[existingKey]?.isBeta = isBeta
                } else {
                    let appId = name.lowercased()
                    let newApp = CatalogApp(
                        id: appId,
                        name: name,
                        shortName: name,
                        taglineEn: description,
                        taglineFr: description,
                        descriptionEn: description,
                        descriptionFr: description,
                        repository: fullName,
                        bundleIdentifier: "org.111iridescence.\(appId.replacingOccurrences(of: "-", with: ""))",
                        isFeatured: isFeatured,
                        isBeta: isBeta
                    )
                    catalog[appId] = newApp
                    if !knownAppIDs.contains(appId) {
                        knownAppIDs.insert(appId)
                        newlyDiscovered.append(newApp)
                    }
                }
            }
        }

        // 2. Fetch latest releases for all catalog applications
        for (id, var app) in catalog {
            if let releases = try? await GitHubClient.shared.fetchReleases(for: app.repository) {
                app.latestRelease = releases.first(where: { !$0.isPrerelease })
                app.latestBetaRelease = releases.first(where: { $0.isPrerelease })
                catalog[id] = app
            }
        }

        saveCatalog()
        return newlyDiscovered
    }

    /// Retrieve all apps currently in the catalog
    public func getCatalogApps() -> [CatalogApp] {
        return Array(catalog.values).sorted { lhs, rhs in
            if lhs.isFeatured != rhs.isFeatured {
                return lhs.isFeatured && !rhs.isFeatured
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Find catalog entry by repository
    public func findByRepository(_ repo: String) -> CatalogApp? {
        return catalog.values.first { $0.repository.caseInsensitiveCompare(repo) == .orderedSame }
    }

    /// Find catalog entry by bundle identifier
    public func findByBundleIdentifier(_ bundleID: String) -> CatalogApp? {
        return catalog.values.first { $0.bundleIdentifier.caseInsensitiveCompare(bundleID) == .orderedSame }
    }

    private func saveCatalog() {
        let items = Array(catalog.values)
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: cacheURL)
        }
    }
}
