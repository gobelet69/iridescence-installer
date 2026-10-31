import XCTest
@testable import IridescenceCore

final class QuarantineManagerTests: XCTestCase {
    var tempDir: URL!
    var syntheticAppURL: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("QuarantineTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        syntheticAppURL = tempDir.appendingPathComponent("SyntheticTest.app")
        let contents = syntheticAppURL.appendingPathComponent("Contents")
        try? FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>org.111iridescence.synthetictest</string>
            <key>CFBundleName</key>
            <string>SyntheticTest</string>
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

    func testBundlePathValidation() {
        let mgr = QuarantineManager.shared

        // Valid bundle path in temp
        XCTAssertNoThrow(try mgr.validateBundlePath(syntheticAppURL, expectedBundleID: "org.111iridescence.synthetictest"))

        // Reject mismatching bundle identifier
        XCTAssertThrowsError(try mgr.validateBundlePath(syntheticAppURL, expectedBundleID: "org.111iridescence.wrongid"))

        // Reject non-.app path
        let nonApp = tempDir.appendingPathComponent("random.txt")
        try? "test".write(to: nonApp, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try mgr.validateBundlePath(nonApp))

        // Reject system root paths
        let systemPath = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        XCTAssertThrowsError(try mgr.validateBundlePath(systemPath))
    }

    func testQuarantineAdditionAndRemoval() throws {
        let mgr = QuarantineManager.shared

        // Set quarantine attribute using xattr utility
        let setXattr = Process()
        setXattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        setXattr.arguments = ["-w", QuarantineManager.quarantineAttributeName, "0081;63a1c890;Safari;AE256671-1E5A-4B9F-84B9", syntheticAppURL.path]
        try setXattr.run()
        setXattr.waitUntilExit()

        XCTAssertTrue(mgr.hasQuarantine(at: syntheticAppURL), "Quarantine attribute should be present")

        // Policy without autoQuarantineOfficial should throw unauthorized
        var policy = TrustPolicy(autoQuarantineOfficial: false)
        XCTAssertThrowsError(
            try mgr.removeQuarantine(
                bundleURL: syntheticAppURL,
                expectedBundleID: "org.111iridescence.synthetictest",
                sourceRepository: "gobelet69/SyntheticTest",
                policy: policy
            )
        )

        // Policy with autoQuarantineOfficial enabled
        policy.autoQuarantineOfficial = true
        XCTAssertNoThrow(
            try mgr.removeQuarantine(
                bundleURL: syntheticAppURL,
                expectedBundleID: "org.111iridescence.synthetictest",
                sourceRepository: "gobelet69/SyntheticTest",
                policy: policy
            )
        )

        XCTAssertFalse(mgr.hasQuarantine(at: syntheticAppURL), "Quarantine attribute should have been removed")
    }

    func testThirdPartyQuarantineAuthorization() throws {
        let mgr = QuarantineManager.shared

        let setXattr = Process()
        setXattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        setXattr.arguments = ["-w", QuarantineManager.quarantineAttributeName, "0081;test", syntheticAppURL.path]
        try setXattr.run()
        setXattr.waitUntilExit()

        var policy = TrustPolicy(autoQuarantineOfficial: true, trustedThirdPartyRepositories: [])

        // Third party repo not yet approved
        XCTAssertThrowsError(
            try mgr.removeQuarantine(
                bundleURL: syntheticAppURL,
                expectedBundleID: "org.111iridescence.synthetictest",
                sourceRepository: "thirdparty/custom-app",
                policy: policy
            )
        )

        // Now approve third party
        policy.approveSource("thirdparty/custom-app")
        XCTAssertNoThrow(
            try mgr.removeQuarantine(
                bundleURL: syntheticAppURL,
                expectedBundleID: "org.111iridescence.synthetictest",
                sourceRepository: "thirdparty/custom-app",
                policy: policy
            )
        )

        XCTAssertFalse(mgr.hasQuarantine(at: syntheticAppURL))
    }
}
