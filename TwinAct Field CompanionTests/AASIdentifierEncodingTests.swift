import XCTest
@testable import TwinAct_Field_Companion

final class AASIdentifierEncodingTests: XCTestCase {

    func testRoundTripEncodingDecoding() {
        let original = "https://example.com/aas/1234567890"
        let encoded = aasB64Url(original)
        let decoded = aasB64UrlDecode(encoded)

        XCTAssertEqual(decoded, original)
        XCTAssertFalse(encoded.contains("="))
    }

    func testEmptyStringEncodingDecoding() {
        XCTAssertEqual(aasB64Url(""), "")
        XCTAssertEqual(aasB64UrlDecode(""), "")
    }
}
