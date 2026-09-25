import Foundation
import SwiftData

@Model
final class ChartPreset {
    var id: UUID
    var name: String
    var seriesPIDIDs: [String]
    /// JSON-encoded [String: [Double]] mapping pidID -> [min, max] override.
    /// Stored as raw Data because SwiftData doesn't model heterogeneous dictionaries directly.
    private var rangeOverridesData: Data
    var timeWindowSeconds: Double
    var createdAt: Date

    var rangeOverrides: [String: ClosedRange<Double>] {
        get {
            guard let raw = try? JSONDecoder().decode([String: [Double]].self, from: rangeOverridesData) else { return [:] }
            return raw.compactMapValues { bounds in
                guard bounds.count == 2 else { return nil }
                return bounds[0]...bounds[1]
            }
        }
        set {
            let raw = newValue.mapValues { [$0.lowerBound, $0.upperBound] }
            rangeOverridesData = (try? JSONEncoder().encode(raw)) ?? Data()
        }
    }

    init(name: String, seriesPIDIDs: [String], rangeOverrides: [String: ClosedRange<Double>] = [:], timeWindowSeconds: Double = 60) {
        self.id = UUID()
        self.name = name
        self.seriesPIDIDs = seriesPIDIDs
        let raw = rangeOverrides.mapValues { [$0.lowerBound, $0.upperBound] }
        self.rangeOverridesData = (try? JSONEncoder().encode(raw)) ?? Data()
        self.timeWindowSeconds = timeWindowSeconds
        self.createdAt = Date()
    }
}
