import XCTest
@testable import CaRx

final class DTCParserTests: XCTestCase {
    func testParsesTwoCurrentCodes() {
        // 43 (echo) 02 (count) 02 34 (P0234) 01 71 (P0171)
        let codes = DTCParser.parse(response: "43 02 02 34 01 71", expectedEcho: "43")
        XCTAssertEqual(codes, ["P0234", "P0171"])
    }

    func testNoCodesReturnsEmpty() {
        XCTAssertEqual(DTCParser.parse(response: "43 00", expectedEcho: "43"), [])
    }

    func testNoDataReturnsEmpty() {
        XCTAssertEqual(DTCParser.parse(response: "NO DATA", expectedEcho: "47"), [])
    }

    func testChassisAndNetworkCodeLetters() {
        // C0035: letter bits 01 -> C; 0000 -> digit1=0, digit2=0; 0x35 -> digit3=3 digit4=5
        let cCode = DTCParser.parse(response: "43 01 40 35", expectedEcho: "43")
        XCTAssertEqual(cCode, ["C0035"])
    }

    func testFreezeFrameDTCParsing() {
        let dtc = DTCParser.parseFreezeFrameDTC(response: "42 02 00 02 34")
        XCTAssertEqual(dtc, "P0234")
    }

    func testFreezeFrameNoDataReturnsNil() {
        XCTAssertNil(DTCParser.parseFreezeFrameDTC(response: "NO DATA"))
    }

    func testDatabaseLookupKnownCode() {
        XCTAssertEqual(DTCDatabase.description(for: "P0234"), "Engine Overboost Condition")
    }

    func testDatabaseFallbackForUnknownCode() {
        XCTAssertTrue(DTCDatabase.description(for: "P9999").contains("Powertrain"))
    }
}
