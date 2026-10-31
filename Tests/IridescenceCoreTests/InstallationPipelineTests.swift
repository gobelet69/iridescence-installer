import XCTest
@testable import IridescenceCore

final class InstallationPipelineTests: XCTestCase {
    var fixtureDir: URL!
    var destinationDir: URL!

    override func setUp() {
        super.setUp()
        fixtureDir = FileManager.default.temporaryDirectory.appendingPathComponent("PipelineFixture_\(UUID().uuidString)")
        destinationDir = FileManager.default.temporaryDirectory.appendingPathComponent("PipelineDest_\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: fixtureDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: destinationDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fixtureDir)
        try? FileManager.default.removeItem(at: destinationDir)
        super.tearDown()
    }

    func testZipInstallationAndQuarantineHandling() async throws {
        // 1. Build a synthetic .app bundle
        let appBundleURL = fixtureDir.appendingPathComponent("SampleTool.app")
        let contentsURL = appBundleURL.appendingPathComponent("Contents")
        let macosURL = contentsURL.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: macosURL, withIntermediateDirectories: true)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>org.111iridescence.sampletool</string>
            <key>CFBundleName</key>
            <string>SampleTool</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0.0</string>
            <key>CFBundleExecutable</key>
            <string>SampleTool</string>
        </dict>
        </plist>
        """
        try plist.write(to: contentsURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        // Create dummy executable
        let execURL = macosURL.appendingPathComponent("SampleTool")
        try "#!/bin/sh\necho hello".write(to: execURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execURL.path)

        // 2. Package into a zip archive using ditto
        let zipURL = fixtureDir.appendingPathComponent("SampleTool-1.0.0-macOS-universal.zip")
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-c", "-k", "--keepParent", appBundleURL.path, zipURL.path]
        try ditto.run()
        ditto.waitUntilExit()

        XCTAssertTrue(FileManager.default.fileExists(atPath: zipURL.path))

        // 3. Compute SHA256 checksum
        let checksum = try IntegrityVerifier.computeSHA256(for: zipURL)

        // 4. Create ReleaseItem model
        let asset = ReleaseAsset(
            id: 9901,
            name: "SampleTool-1.0.0-macOS-universal.zip",
            downloadURL: zipURL,
            size: 1024,
            contentType: "application/zip"
        )

        let release = ReleaseItem(
            id: 8801,
            tagName: "v1.0.0",
            name: "SampleTool v1.0.0",
            body: "First test release",
            publishedAt: Date(),
            isPrerelease: false,
            assets: [asset],
            checksums: [asset.name: checksum]
        )

        // 5. Test installation with policy allowing official sources
        let policy = TrustPolicy(autoQuarantineOfficial: true)
        let installedURL = try await InstallationManager.shared.install(
            release: release,
            repository: "gobelet69/SampleTool",
            expectedBundleID: "org.111iridescence.sampletool",
            targetDirectory: destinationDir,
            policy: policy
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: installedURL.path))
        XCTAssertEqual(installedURL.lastPathComponent, "SampleTool.app")

        // 6. Inspect installed bundle with AppScanner
        let inspected = await AppScanner.shared.inspectAppBundle(at: installedURL)
        XCTAssertNotNil(inspected)
        XCTAssertEqual(inspected?.installedVersion.major, 1)
        XCTAssertEqual(inspected?.bundleIdentifier, "org.111iridescence.sampletool")
    }
}
