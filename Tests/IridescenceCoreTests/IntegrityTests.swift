import XCTest
@testable import IridescenceCore

final class IntegrityTests: XCTestCase {
    func testChecksumParsing() {
        let text = """
        # SHA-256 Checksums for Release v1.0.0
        e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  empty.dmg
        a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e *Mass.Print_0.2.1_universal.dmg
        SHA256 (Iridescence-PDF-Reader-v2.0.0-macOS-arm64.dmg) = d41d8cd98f00b204e9800998ecf8427e
        """

        let parsed = IntegrityVerifier.parseChecksums(text: text)
        XCTAssertEqual(parsed["empty.dmg"], "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(parsed["Mass.Print_0.2.1_universal.dmg"], "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e")
        XCTAssertEqual(parsed["Iridescence-PDF-Reader-v2.0.0-macOS-arm64.dmg"], "d41d8cd98f00b204e9800998ecf8427e")
    }

    func testComputeSHA256() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("sha_test_\(UUID().uuidString).txt")
        let testString = "111iridescence Prismatic Atelier"
        try testString.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let hash = try IntegrityVerifier.computeSHA256(for: tempFile)
        XCTAssertFalse(hash.isEmpty)
        XCTAssertEqual(hash.count, 64)

        // Verify matches itself
        XCTAssertNoThrow(try IntegrityVerifier.verify(fileURL: tempFile, expectedHash: hash))

        // Verify fails on incorrect hash
        XCTAssertThrowsError(try IntegrityVerifier.verify(fileURL: tempFile, expectedHash: "0000000000000000000000000000000000000000000000000000000000000000"))
    }
}
