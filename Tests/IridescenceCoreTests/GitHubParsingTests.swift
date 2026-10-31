import XCTest
@testable import IridescenceCore

final class GitHubParsingTests: XCTestCase {
    func testReleaseJsonDecoding() throws {
        let json = """
        [
            {
                "id": 1001,
                "tag_name": "v2.0.0",
                "name": "Iridescence PDF Reader v2.0.0",
                "body": "Major 2.0 release with dual sidebars and native performance.",
                "published_at": "2026-10-30T12:00:00Z",
                "prerelease": false,
                "draft": false,
                "assets": [
                    {
                        "id": 2001,
                        "name": "Iridescence-PDF-Reader-v2.0.0-macOS-arm64.dmg",
                        "browser_download_url": "https://github.com/gobelet69/iridecence-pdf-reader/releases/download/v2.0.0/Iridescence-PDF-Reader-v2.0.0-macOS-arm64.dmg",
                        "size": 15420000,
                        "content_type": "application/x-apple-diskimage"
                    },
                    {
                        "id": 2002,
                        "name": "SHA256SUMS.txt",
                        "browser_download_url": "https://github.com/gobelet69/iridecence-pdf-reader/releases/download/v2.0.0/SHA256SUMS.txt",
                        "size": 120,
                        "content_type": "text/plain"
                    }
                ]
            },
            {
                "id": 1002,
                "tag_name": "v2.1.0-beta.1",
                "name": "Iridescence PDF Reader v2.1.0-beta.1",
                "body": "Experimental beta features.",
                "published_at": "2026-10-31T08:00:00Z",
                "prerelease": true,
                "draft": false,
                "assets": [
                    {
                        "id": 2003,
                        "name": "Iridescence-PDF-Reader-v2.1.0-universal.dmg",
                        "browser_download_url": "https://github.com/gobelet69/iridecence-pdf-reader/releases/download/v2.1.0-beta.1/Iridescence-PDF-Reader-v2.1.0-universal.dmg",
                        "size": 22000000,
                        "content_type": "application/x-apple-diskimage"
                    }
                ]
            }
        ]
        """

        let data = json.data(using: .utf8)!
        let releases = try JSONDecoder().decode([ReleaseItem].self, from: data)

        XCTAssertEqual(releases.count, 2)
        XCTAssertEqual(releases[0].tagName, "v2.0.0")
        XCTAssertEqual(releases[0].version.major, 2)
        XCTAssertFalse(releases[0].isPrerelease)

        // Best asset selection for arm64
        let bestAsset = releases[0].bestInstallableAsset(for: .arm64)
        XCTAssertNotNil(bestAsset)
        XCTAssertEqual(bestAsset?.name, "Iridescence-PDF-Reader-v2.0.0-macOS-arm64.dmg")
        XCTAssertEqual(bestAsset?.architecture, .arm64)

        // Checksum asset discovery
        XCTAssertNotNil(releases[0].checksumAsset)
        XCTAssertEqual(releases[0].checksumAsset?.name, "SHA256SUMS.txt")

        // Prerelease check
        XCTAssertTrue(releases[1].isPrerelease)
        XCTAssertEqual(releases[1].version.prerelease, "beta.1")
        let universalAsset = releases[1].bestInstallableAsset(for: .arm64)
        XCTAssertEqual(universalAsset?.architecture, .universal)
    }

    func testArchitectureInference() {
        XCTAssertEqual(BinaryArchitecture.infer(from: "App-arm64.dmg"), .arm64)
        XCTAssertEqual(BinaryArchitecture.infer(from: "App-apple-silicon.zip"), .arm64)
        XCTAssertEqual(BinaryArchitecture.infer(from: "App-x86_64.dmg"), .x86_64)
        XCTAssertEqual(BinaryArchitecture.infer(from: "App_universal.dmg"), .universal)
        XCTAssertEqual(BinaryArchitecture.infer(from: "Generic.dmg"), .unknown)
    }
}
