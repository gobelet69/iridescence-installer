import XCTest
@testable import IridescenceCore

final class RollbackManagerTests: XCTestCase {
    var tempDir: URL!
    var syntheticAppURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("RollbackTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        syntheticAppURL = tempDir.appendingPathComponent("SyntheticApp.app")
        let contents = syntheticAppURL.appendingPathComponent("Contents")
        try? FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>org.111iridescence.rollbacktest</string>
            <key>CFBundleName</key>
            <string>SyntheticApp</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0.0</string>
        </dict>
        </plist>
        """
        try? plistContent.write(to: contents.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testCreateBackupAndRestore() async throws {
        let mgr = RollbackManager.shared
        let bundleID = "org.111iridescence.rollbacktest"

        let entry = try await mgr.createBackup(
            of: syntheticAppURL,
            bundleIdentifier: bundleID,
            version: AppVersion("1.0.0")
        )

        XCTAssertEqual(entry.bundleIdentifier, bundleID)
        XCTAssertEqual(entry.versionString, "1.0.0")
        XCTAssertTrue(FileManager.default.fileExists(atPath: entry.backupBundleURL.path))

        let backups = await mgr.listBackups(for: bundleID)
        XCTAssertFalse(backups.isEmpty)
        XCTAssertEqual(backups.first?.bundleIdentifier, bundleID)

        // Modify the original app to simulate a broken update
        let testMarker = syntheticAppURL.appendingPathComponent("Contents/modified.txt")
        try "modified".write(to: testMarker, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testMarker.path))

        // Restore backup
        try await mgr.restore(entry: entry)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testMarker.path), "Restored app should not contain the modified file")

        // Cleanup backup
        await mgr.deleteBackup(entry)
    }
}
