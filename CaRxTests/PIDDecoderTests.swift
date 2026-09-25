import XCTest
@testable import CaRx

final class PIDDecoderTests: XCTestCase {
    func testRPMDecoding() {
        // ((A*256)+B)/4, A=0x1A, B=0xF8 -> (26*256+248)/4 = 1725
        let data = Data([0x1A, 0xF8])
        XCTAssertEqual(PIDDecoders.rpm(data), 1725)
    }

    func testTemperatureFahrenheitDecoding() {
        // A=0x5A (90) -> Celsius 50 -> Fahrenheit 122
        let data = Data([0x5A])
        XCTAssertEqual(PIDDecoders.temperatureFahrenheit(data), 122)
    }

    func testSpeedMphDecoding() {
        let data = Data([100]) // 100 km/h -> ~62.14 mph
        XCTAssertEqual(PIDDecoders.speedMph(data), 62.1371, accuracy: 0.001)
    }

    func testPercentDecoding() {
        let data = Data([255])
        XCTAssertEqual(PIDDecoders.percent(data), 100, accuracy: 0.01)
    }

    func testBoostPsiRelativeAtAtmosphericBaseline() {
        // ~101 kPa raw byte should read close to 0 PSI gauge pressure.
        let data = Data([101])
        XCTAssertEqual(PIDDecoders.boostPsiRelative(data), -0.0435, accuracy: 0.001)
    }

    func testDataBytesStripsMode01Echo() {
        // "41 0C 1A F8" -> mode 01 echo (2 bytes) stripped -> [0x1A, 0xF8]
        let bytes = ELM327Session.dataBytes(fromResponse: "41 0C 1A F8", request: "010C")
        XCTAssertEqual(Array(bytes), [0x1A, 0xF8])
    }

    func testDataBytesStripsMode22Echo() {
        // "62 11 B0 5A" -> mode 22 echo (3 bytes: 62 + 2-byte PID) stripped -> [0x5A]
        let bytes = ELM327Session.dataBytes(fromResponse: "62 11 B0 5A", request: "2211B0")
        XCTAssertEqual(Array(bytes), [0x5A])
    }
}
