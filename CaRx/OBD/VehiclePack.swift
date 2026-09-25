import Foundation

/// The set of formulas a JSON-defined enhanced PID can reference. Keeping this as a
/// closed enum (rather than shipping arbitrary code in JSON) means vehicle packs stay
/// pure data -- a new pack is just a new JSON file, no app code changes.
enum DecoderKind: String, Codable, Hashable {
    case temperatureCelsius
    case temperatureFahrenheit
    case rpm
    case speedMph
    case percent
    case rawByte
    case timingAdvance
    case voltage
    case kPaToPsi
    case boostPsiRelative
    case mafGramsPerSecond

    var function: @Sendable (Data) -> Double {
        switch self {
        case .temperatureCelsius: return PIDDecoders.temperatureCelsius
        case .temperatureFahrenheit: return PIDDecoders.temperatureFahrenheit
        case .rpm: return PIDDecoders.rpm
        case .speedMph: return PIDDecoders.speedMph
        case .percent: return PIDDecoders.percent
        case .rawByte: return PIDDecoders.rawByte
        case .timingAdvance: return PIDDecoders.timingAdvance
        case .voltage: return PIDDecoders.voltage
        case .kPaToPsi: return PIDDecoders.kPaToPsi
        case .boostPsiRelative: return PIDDecoders.boostPsiRelative
        case .mafGramsPerSecond: return PIDDecoders.mafGramsPerSecond
        }
    }
}

/// JSON-codable mirror of `PID`, since closures aren't `Codable`.
struct VehiclePID: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let request: String
    let header: String
    let unit: String
    let minValue: Double
    let maxValue: Double
    let verified: Bool
    let decoderKind: DecoderKind

    func toPID() -> PID {
        PID(id: id, name: name, request: request, header: header,
            unit: unit, minValue: minValue, maxValue: maxValue,
            verified: verified, decode: decoderKind.function)
    }
}

/// A bundled, make/model-specific PID pack layered on top of the standard SAE set.
/// See CaRx_iOS_CarPlay_Development_Prompt.md §5b for why the enhanced PIDs below
/// carry a `verified` flag instead of being trusted as OEM fact.
struct VehiclePack: Codable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let make: String
    let model: String
    let year: Int
    let ecuAccessNotes: String
    let enhancedPIDs: [VehiclePID]
    /// PID ids (standard + enhanced) to seed the default dashboard with when this pack is selected.
    let defaultDashboardPIDIDs: [String]

    var allPIDs: [PID] {
        StandardPIDRegistry.all + enhancedPIDs.map { $0.toPID() }
    }
}

enum VehiclePackLoader {
    /// Built-in packs bundled with the app. Dropping a new `*.json` file into
    /// OBD/VehiclePacks/ and adding its name here is the only step needed to
    /// support a new vehicle -- no other code changes required.
    private static let bundledFileNames = ["cruze_2014", "bmw_2015", "ram1500_2020"]

    static let genericPack = VehiclePack(
        id: "generic",
        displayName: "Generic / Standard OBD-II",
        make: "Generic",
        model: "Any OBD-II compliant vehicle",
        year: 0,
        ecuAccessNotes: "Standard SAE J1979 Mode 01 PIDs only. No manufacturer-specific sensors.",
        enhancedPIDs: [],
        defaultDashboardPIDIDs: ["STD_RPM", "STD_SPEED", "STD_ECT", "STD_LOAD"]
    )

    static func loadAll() -> [VehiclePack] {
        var packs = bundledFileNames.compactMap(load)
        packs.append(genericPack)
        return packs
    }

    static func load(named name: String) -> VehiclePack? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "VehiclePacks")
                ?? Bundle.main.url(forResource: name, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(VehiclePack.self, from: data)
        } catch {
            assertionFailure("Failed to decode vehicle pack \(name): \(error)")
            return nil
        }
    }
}
