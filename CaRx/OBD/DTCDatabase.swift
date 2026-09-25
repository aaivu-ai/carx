import Foundation

/// Generic (SAE-defined) P/B/C/U trouble code descriptions, bundled as JSON so
/// the list can grow without touching Swift code. Manufacturer-specific codes
/// (typically P1xxx/P3xxx ranges) that aren't in this bundled set fall back to
/// a generic description built from the code's category.
enum DTCDatabase {
    static let shared: [String: String] = {
        guard let url = Bundle.main.url(forResource: "dtc_descriptions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return dict
    }()

    static func description(for code: String) -> String {
        if let known = shared[code.uppercased()] {
            return known
        }
        return fallbackDescription(for: code)
    }

    private static func fallbackDescription(for code: String) -> String {
        guard let category = code.first else { return "Unknown diagnostic trouble code." }
        switch category {
        case "P": return "Powertrain code (engine/transmission) — not in the local description database."
        case "C": return "Chassis code (brakes/steering/suspension) — not in the local description database."
        case "B": return "Body code (airbags/climate/lighting) — not in the local description database."
        case "U": return "Network/communication code — not in the local description database."
        default: return "Unknown diagnostic trouble code."
        }
    }
}
