import SwiftUI
import Charts

/// Overlays multiple sensors on one chart. Since PIDs have wildly different scales
/// (RPM vs. PSI vs. °F), each series is normalized to its own 0-100% range (either the
/// PID's default range or a per-series override) so they can be compared visually.
struct MultiSeriesChartView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    let seriesPIDs: [PID]
    let rangeOverrides: [String: ClosedRange<Double>]
    @State var windowSeconds: Double

    private let palette: [Color] = [CaRxTheme.accent, CaRxTheme.accentSecondary, CaRxTheme.warning, CaRxTheme.success, CaRxTheme.danger, .white]

    private struct NormalizedPoint: Identifiable {
        let id = UUID()
        let seriesName: String
        let timestamp: Date
        let normalizedValue: Double
        let rawValue: Double
    }

    private var normalizedPoints: [NormalizedPoint] {
        seriesPIDs.flatMap { pid -> [NormalizedPoint] in
            let range = rangeOverrides[pid.id] ?? pid.range
            let span = range.upperBound - range.lowerBound
            return coordinator.telemetry.samples(for: pid.id, within: windowSeconds).map { sample in
                let normalized = span > 0 ? ((sample.value - range.lowerBound) / span * 100).clamped(to: 0...100) : 0
                return NormalizedPoint(seriesName: pid.name, timestamp: sample.timestamp, normalizedValue: normalized, rawValue: sample.value)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ForEach(Array(seriesPIDs.enumerated()), id: \.element.id) { index, pid in
                    HStack(spacing: 5) {
                        Circle().fill(palette[index % palette.count]).frame(width: 8, height: 8)
                        Text(pid.name).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Chart(normalizedPoints) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Normalized", point.normalizedValue)
                )
                .foregroundStyle(by: .value("Series", point.seriesName))
                .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale(domain: seriesPIDs.map(\.name), range: palette)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))%")
                        }
                    }
                }
            }
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .chartLegend(.hidden)
            .frame(maxHeight: .infinity)
            .carxCard()
        }
    }
}
