import XCTest
@testable import CaRx

final class VehiclePackTests: XCTestCase {
    func testAllThreeRequiredVehiclePacksLoad() {
        let packs = VehiclePackLoader.loadAll()
        let ids = Set(packs.map(\.id))
        XCTAssertTrue(ids.contains("cruze_2014"), "2014 Chevrolet Cruze pack must be bundled")
        XCTAssertTrue(ids.contains("bmw_2015"), "2015 BMW pack must be bundled")
        XCTAssertTrue(ids.contains("ram1500_2020"), "2020 Ram 1500 pack must be bundled")
    }

    func testCruzePIDsAreMarkedVerified() {
        guard let cruze = VehiclePackLoader.load(named: "cruze_2014") else {
            return XCTFail("cruze_2014.json failed to decode")
        }
        XCTAssertTrue(cruze.enhancedPIDs.allSatisfy(\.verified), "Cruze PIDs are carried over from the validated Android app and should be marked verified")
    }

    func testBMWAndRamPIDsAreMarkedUnverifiedUntilConfirmed() {
        for name in ["bmw_2015", "ram1500_2020"] {
            guard let pack = VehiclePackLoader.load(named: name) else {
                return XCTFail("\(name).json failed to decode")
            }
            XCTAssertTrue(pack.enhancedPIDs.allSatisfy { !$0.verified }, "\(name) enhanced PIDs are community placeholders and must not be marked verified by default")
        }
    }

    func testEveryPackDefaultDashboardPIDsExist() {
        for pack in VehiclePackLoader.loadAll() {
            let allIDs = Set(pack.allPIDs.map(\.id))
            for pidID in pack.defaultDashboardPIDIDs {
                XCTAssertTrue(allIDs.contains(pidID), "\(pack.id) default dashboard references missing PID \(pidID)")
            }
        }
    }
}
