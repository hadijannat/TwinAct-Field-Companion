import XCTest
@testable import TwinAct_Field_Companion

final class IdentificationLinkParserTests: XCTestCase {

    func testManufacturerLinkParsingExtractsSerialAndManufacturer() {
        let code = "https://id.siemens.com/product/SP500/XYZ12345"
        let link = IdentificationLinkParser.parse(code)

        XCTAssertNotNil(link)
        XCTAssertEqual(link?.linkType, .manufacturerLink)
        XCTAssertEqual(link?.manufacturer, "Siemens")
        XCTAssertEqual(link?.serialNumber, "XYZ12345")
        XCTAssertEqual(link?.productFamily, "SP500")
    }

    func testURNParsingExtractsEclassId() {
        let urn = "urn:eclass:0173-1#01-AAA001#001"
        let link = IdentificationLinkParser.parse(urn)

        XCTAssertNotNil(link)
        XCTAssertEqual(link?.linkType, .eclassId)
        XCTAssertEqual(link?.globalAssetId, urn)
        XCTAssertTrue(link?.specificAssetIds.contains(where: { $0.name == "eclassId" }) ?? false)
    }

    func testRawSerialNumberParsingCreatesLookupQuery() {
        let serial = "SN-ABC12345"
        let link = IdentificationLinkParser.parse(serial)

        XCTAssertNotNil(link)
        XCTAssertEqual(link?.serialNumber, serial)
        XCTAssertEqual(link?.lookupQuery.first?.name, "serialNumber")
    }
}
