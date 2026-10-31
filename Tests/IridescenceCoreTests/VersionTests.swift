import XCTest
@testable import IridescenceCore

final class VersionTests: XCTestCase {
    func testSemanticVersionParsing() {
        let v1 = AppVersion("v1.2.3")
        XCTAssertEqual(v1.major, 1)
        XCTAssertEqual(v1.minor, 2)
        XCTAssertEqual(v1.patch, 3)
        XCTAssertNil(v1.prerelease)

        let v2 = AppVersion("2.0.0-beta.1")
        XCTAssertEqual(v2.major, 2)
        XCTAssertEqual(v2.minor, 0)
        XCTAssertEqual(v2.patch, 0)
        XCTAssertEqual(v2.prerelease, "beta.1")
        XCTAssertTrue(v2.isPrerelease)
    }

    func testVersionComparison() {
        let v1 = AppVersion("1.0.0")
        let v2 = AppVersion("1.0.1")
        let v3 = AppVersion("1.1.0")
        let v4 = AppVersion("2.0.0")
        let vBeta = AppVersion("2.0.0-beta.1")
        let vBeta2 = AppVersion("2.0.0-beta.2")

        XCTAssertTrue(v1 < v2)
        XCTAssertTrue(v2 < v3)
        XCTAssertTrue(v3 < v4)

        // Prerelease is lower than release
        XCTAssertTrue(vBeta < v4)
        XCTAssertTrue(vBeta < vBeta2)
        XCTAssertTrue(v3 < vBeta)
    }

    func testDowngradeDetection() {
        let current = AppVersion("2.0.0")
        let older = AppVersion("1.9.9")
        XCTAssertTrue(older < current)
    }
}
