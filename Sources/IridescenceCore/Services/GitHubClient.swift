import Foundation

public enum GitHubError: LocalizedError, Sendable {
    case invalidRepository(String)
    case rateLimited(resetDate: Date)
    case resourceNotFound(String)
    case invalidResponse(Int)
    case networkFailure(String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRepository(let repo):
            return "Invalid GitHub repository identifier: '\(repo)'. Expected format 'owner/repo'."
        case .rateLimited(let resetDate):
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return "GitHub API rate limit reached. Resets at \(formatter.string(from: resetDate))."
        case .resourceNotFound(let resource):
            return "Resource not found on GitHub: \(resource)"
        case .invalidResponse(let statusCode):
            return "GitHub API returned HTTP status \(statusCode)."
        case .networkFailure(let msg):
            return "Network connection error: \(msg)"
        case .decodingError(let msg):
            return "Failed to parse GitHub metadata: \(msg)"
        }
    }
}

public actor GitHubClient {
    public static let shared = GitHubClient()

    private let session: URLSession
    private var etagCache: [String: String] = [:]
    private var dataCache: [String: Data] = [:]

    // Rate limiting tracking
    public private(set) var rateLimitRemaining: Int = 60
    public private(set) var rateLimitResetDate: Date = Date()

    // Stored settings
    private let tokenKey = "org.111iridescence.installer.githubToken"
    private let legacyTokenKey = "org.111iridescence.updater.githubToken"

    public init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    public func setGitHubToken(_ token: String?) {
        let clean = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let t = clean, !t.isEmpty {
            UserDefaults.standard.set(t, forKey: tokenKey)
        } else {
            UserDefaults.standard.removeObject(forKey: tokenKey)
        }
    }

    public func getGitHubToken() -> String? {
        return UserDefaults.standard.string(forKey: tokenKey) ?? UserDefaults.standard.string(forKey: legacyTokenKey)
    }

    /// Fetch all releases for a repository (e.g. "gobelet69/Mass-Print")
    public func fetchReleases(for repository: String) async throws -> [ReleaseItem] {
        let endpoint = "https://api.github.com/repos/\(repository)/releases"
        let data = try await request(urlString: endpoint)

        do {
            let decoder = JSONDecoder()
            var releases = try decoder.decode([ReleaseItem].self, from: data)

            // Filter out draft releases
            releases.removeAll { $0.isDraft }

            // Fetch checksums for each release in parallel if a checksum asset exists
            for i in 0..<releases.count {
                if let checksumAsset = releases[i].checksumAsset {
                    if let checksums = try? await fetchChecksumFile(url: checksumAsset.downloadURL) {
                        releases[i].checksums = checksums
                    }
                }
            }

            return releases.sorted { $0.version > $1.version }
        } catch {
            throw GitHubError.decodingError("Releases decoding failed: \(error.localizedDescription)")
        }
    }

    /// Fetch the latest release for an app according to channel preferences
    public func fetchLatestRelease(
        for repository: String,
        includeBeta: Bool
    ) async throws -> ReleaseItem? {
        let releases = try await fetchReleases(for: repository)
        if includeBeta {
            // Newest compatible version, whether stable or prerelease
            return releases.first
        } else {
            // Strictly stable releases
            return releases.first(where: { !$0.isPrerelease })
        }
    }

    /// Fetch topics for a repository (e.g. to detect "iridescence-app")
    public func fetchTopics(for repository: String) async throws -> [String] {
        let endpoint = "https://api.github.com/repos/\(repository)/topics"
        let data = try await request(urlString: endpoint, extraHeaders: ["Accept": "application/vnd.github.mercy-preview+json"])

        struct TopicsResponse: Codable {
            let names: [String]
        }

        if let response = try? JSONDecoder().decode(TopicsResponse.self, from: data) {
            return response.names
        }
        return []
    }

    /// Fetch all repositories owned by the official account
    public func fetchOfficialRepositories(owner: String = TrustPolicy.officialOwner) async throws -> [[String: Any]] {
        let endpoint = "https://api.github.com/users/\(owner)/repos?per_page=100"
        let data = try await request(urlString: endpoint)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json
    }

    /// Download a checksum file and parse it into [Filename: Hash]
    private func fetchChecksumFile(url: URL) async throws -> [String: String] {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else {
            return [:]
        }
        return IntegrityVerifier.parseChecksums(text: text)
    }

    /// Download a release asset to disk with download progress tracking
    public func downloadAsset(
        _ asset: ReleaseAsset,
        to destinationURL: URL,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws {
        // Handle local file fixtures (e.g. offline testing or local packages)
        if asset.downloadURL.isFileURL {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: asset.downloadURL, to: destinationURL)
            progressHandler?(1.0)
            return
        }

        var request = URLRequest(url: asset.downloadURL)
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        if let token = getGitHubToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (asyncBytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse(0)
        }

        guard (200...299).contains(http.statusCode) else {
            throw GitHubError.invalidResponse(http.statusCode)
        }

        let expectedLength = http.expectedContentLength
        let tempDestination = destinationURL.appendingPathExtension("download")
        try? FileManager.default.removeItem(at: tempDestination)
        FileManager.default.createFile(atPath: tempDestination.path, contents: nil)

        let fileHandle = try FileHandle(forWritingTo: tempDestination)
        defer { try? fileHandle.close() }

        var bytesReceived: Int64 = 0
        var lastReportTime = Date()

        for try await byte in asyncBytes {
            let data = Data([byte])
            fileHandle.write(data)
            bytesReceived += 1

            if expectedLength > 0 && Date().timeIntervalSince(lastReportTime) > 0.08 {
                let frac = Double(bytesReceived) / Double(expectedLength)
                progressHandler?(frac)
                lastReportTime = Date()
            }
        }

        progressHandler?(1.0)

        // Atomic move into final destination
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempDestination, to: destinationURL)
    }

    // MARK: - Core HTTP Request with ETag & Rate Limit Handling

    private func request(
        urlString: String,
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidRepository(urlString)
        }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("IridescenceInstaller/1.0", forHTTPHeaderField: "User-Agent")

        if let token = getGitHubToken() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        for (k, v) in extraHeaders {
            req.setValue(v, forHTTPHeaderField: k)
        }

        // Conditional GET using ETag
        if let cachedETag = etagCache[urlString] {
            req.setValue(cachedETag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            // Return cached data on network error if available
            if let cached = dataCache[urlString] {
                return cached
            }
            throw GitHubError.networkFailure(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse(0)
        }

        // Update rate limit stats
        if let remainingStr = http.value(forHTTPHeaderField: "x-ratelimit-remaining"),
           let remaining = Int(remainingStr) {
            self.rateLimitRemaining = remaining
        }
        if let resetStr = http.value(forHTTPHeaderField: "x-ratelimit-reset"),
           let resetTimestamp = TimeInterval(resetStr) {
            self.rateLimitResetDate = Date(timeIntervalSince1970: resetTimestamp)
        }

        // Handle 304 Not Modified
        if http.statusCode == 304, let cached = dataCache[urlString] {
            return cached
        }

        // Handle 403 Rate Limited
        if http.statusCode == 403 && self.rateLimitRemaining == 0 {
            if let cached = dataCache[urlString] {
                return cached
            }
            throw GitHubError.rateLimited(resetDate: self.rateLimitResetDate)
        }

        // Handle 404
        if http.statusCode == 404 {
            throw GitHubError.resourceNotFound(urlString)
        }

        guard (200...299).contains(http.statusCode) else {
            throw GitHubError.invalidResponse(http.statusCode)
        }

        // Cache response and ETag
        if let etag = http.value(forHTTPHeaderField: "ETag") {
            self.etagCache[urlString] = etag
        }
        self.dataCache[urlString] = data

        return data
    }
}
