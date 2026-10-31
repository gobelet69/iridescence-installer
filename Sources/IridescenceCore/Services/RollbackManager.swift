import Foundation

public struct RollbackEntry: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let bundleIdentifier: String
    public let appName: String
    public let versionString: String
    public let backupDate: Date
    public let backupBundleURL: URL
    public let originalInstallURL: URL

    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        versionString: String,
        backupDate: Date = Date(),
        backupBundleURL: URL,
        originalInstallURL: URL
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.versionString = versionString
        self.backupDate = backupDate
        self.backupBundleURL = backupBundleURL
        self.originalInstallURL = originalInstallURL
    }
}

public actor RollbackManager {
    public static let shared = RollbackManager()

    private let fileManager = FileManager.default
    private let baseRollbackDir: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseRollbackDir = appSupport.appendingPathComponent("IridescenceUpdater/Rollback", isDirectory: true)
        try? fileManager.createDirectory(at: baseRollbackDir, withIntermediateDirectories: true)
    }

    /// Backup an installed app before replacing it
    public func createBackup(of appURL: URL, bundleIdentifier: String, version: AppVersion) throws -> RollbackEntry {
        let appName = appURL.lastPathComponent
        let timestamp = Int(Date().timeIntervalSince1970)
        let sanitizedVersion = version.description.replacingOccurrences(of: "/", with: "-")

        let targetDir = baseRollbackDir
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("\(timestamp)_\(sanitizedVersion)", isDirectory: true)

        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let backupAppURL = targetDir.appendingPathComponent(appName)
        try? fileManager.removeItem(at: backupAppURL)

        // Copy bundle using ditto to preserve attributes and codesign slots
        let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")
        let result = try ProcessRunner.run(
            executableURL: dittoURL,
            arguments: [appURL.path, backupAppURL.path]
        )

        guard result.isSuccess else {
            throw NSError(
                domain: "org.111iridescence.updater.rollback",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create backup bundle: \(result.stderr)"]
            )
        }

        let entry = RollbackEntry(
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            versionString: version.description,
            backupDate: Date(),
            backupBundleURL: backupAppURL,
            originalInstallURL: appURL
        )

        saveEntryMetadata(entry, inDirectory: targetDir)
        pruneOldBackups(for: bundleIdentifier, maxToKeep: 3)

        return entry
    }

    /// Restore a previous version from backup
    public func restore(entry: RollbackEntry) throws {
        guard fileManager.fileExists(atPath: entry.backupBundleURL.path) else {
            throw NSError(
                domain: "org.111iridescence.updater.rollback",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Backup bundle does not exist at \(entry.backupBundleURL.path)"]
            )
        }

        let destination = entry.originalInstallURL

        // Remove broken/current installation if present
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        // Copy backup to original destination
        let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")
        let result = try ProcessRunner.run(
            executableURL: dittoURL,
            arguments: [entry.backupBundleURL.path, destination.path]
        )

        guard result.isSuccess else {
            throw NSError(
                domain: "org.111iridescence.updater.rollback",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to restore backup: \(result.stderr)"]
            )
        }
    }

    /// List all available backups
    public func listBackups(for bundleIdentifier: String? = nil) -> [RollbackEntry] {
        var results: [RollbackEntry] = []

        guard let bundleDirs = try? fileManager.contentsOfDirectory(
            at: baseRollbackDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for bDir in bundleDirs {
            let currentBundleID = bDir.lastPathComponent
            if let target = bundleIdentifier, target != currentBundleID {
                continue
            }

            guard let versionDirs = try? fileManager.contentsOfDirectory(
                at: bDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for vDir in versionDirs {
                let metaURL = vDir.appendingPathComponent("metadata.json")
                if let data = try? Data(contentsOf: metaURL),
                   let entry = try? JSONDecoder().decode(RollbackEntry.self, from: data) {
                    if fileManager.fileExists(atPath: entry.backupBundleURL.path) {
                        results.append(entry)
                    }
                }
            }
        }

        return results.sorted { $0.backupDate > $1.backupDate }
    }

    /// Delete a specific backup
    public func deleteBackup(_ entry: RollbackEntry) {
        let parentDir = entry.backupBundleURL.deletingLastPathComponent()
        try? fileManager.removeItem(at: parentDir)
    }

    /// Prune old backups exceeding max count
    public func pruneOldBackups(for bundleIdentifier: String, maxToKeep: Int = 3) {
        let entries = listBackups(for: bundleIdentifier)
        if entries.count > maxToKeep {
            let toRemove = entries[maxToKeep...]
            for item in toRemove {
                deleteBackup(item)
            }
        }
    }

    private func saveEntryMetadata(_ entry: RollbackEntry, inDirectory dir: URL) {
        let metaURL = dir.appendingPathComponent("metadata.json")
        if let data = try? JSONEncoder().encode(entry) {
            try? data.write(to: metaURL)
        }
    }
}
