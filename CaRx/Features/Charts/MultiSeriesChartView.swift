import SwiftUI
import Charts

/// Multi-channel chart. Channels are grouped by effective value range: channels that share
/// a range are overlaid as a multi-series chart in one row (real units on the Y axis), while
/// each distinct range gets its own row so nothing overlaps. Tapping a legend chip toggles
/// that channel's visibility.
struct MultiSeriesChartView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    let seriesPIDs: [PID]
    let rangeOverrides: [String: ClosedRange<Double>]
    @State var windowSeconds: Double
    @State private var hiddenPIDIDs: Set<String> = []

    private let palette: [Color] = [CaRxTheme.accent, CaRxTheme.accentSecondary, CaRxTheme.warning, CaRxTheme.success, CaRxTheme.danger, .white]

    private struct RangeGroup: Identifiable {
        let range: ClosedRange<Double>
        let pids: [PID]
        var id: String { "\(range.lowerBound)|\(range.upperBound)" }
    }

    private func effectiveRange(_ pid: PID) -> ClosedRange<Double> {
        rangeOverrides[pid.id] ?? pid.range
    }

    private func color(for pid: PID) -> Color {
        let index = seriesPIDs.firstIndex(where: { $0.id == pid.id }) ?? 0
        return palette[index % palette.count]
    }

    private var groups: [RangeGroup] {
        var order: [String] = []
        var buckets: [String: (ClosedRange<Double>, [PID])] = [:]
        for pid in seriesPIDs {
            let range = effectiveRange(pid)
            let key = "\(range.lowerBound)|\(range.upperBound)"
            if buckets[key] == nil {
                order.append(key)
                buckets[key] = (range, [])
            }
            buckets[key]?.1.append(pid)
        }
        return order.compactMap { key in
            buckets[key].map { RangeGroup(range: $0.0, pids: $0.1) }
        }
    }

    var body: some View {
        // Anchor the X axis to the newest sample (not wall-clock time at render), so fresh
        // samples never land past the right edge; a small trailing pad keeps the line in view.
        let latest = seriesPIDs
            .compactMap { coordinator.telemetry.samples(for: $0.id, within: windowSeconds).last?.timestamp }
            .max() ?? Date()
        let xDomain = latest.addingTimeInterval(-windowSeconds)...latest.addingTimeInterval(windowSeconds * 0.03)

        VStack(alignment: .leading, spacing: 12) {
            legend

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(groups) { group in
                        let visible = group.pids.filter { !hiddenPIDIDs.contains($0.id) }
                        if !visible.isEmpty {
                            row(for: group, visible: visible, xDomain: xDomain)
                        }
                    }
                    if seriesPIDs.allSatisfy({ hiddenPIDIDs.contains($0.id) }) {
                        Text("All channels hidden — tap a legend chip to show one.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    }
                }
            }
        }
    }

    private var legend: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(seriesPIDs) { pid in
                let isHidden = hiddenPIDIDs.contains(pid.id)
                Button {
                    if isHidden { hiddenPIDIDs.remove(pid.id) } else { hiddenPIDIDs.insert(pid.id) }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isHidden ? Color.clear : color(for: pid))
                            .overlay(Circle().stroke(color(for: pid), lineWidth: 1.5))
                            .frame(width: 10, height: 10)
                        Text(pid.name)
                            .font(.caption)
                            .lineLimit(1)
                            .strikethrough(isHidden)
                    }
                    .foregroundStyle(isHidden ? Color.secondary : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .opacity(isHidden ? 0.55 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(pid.name), \(isHidden ? "hidden" : "shown")")
                .accessibilityHint("Double tap to toggle")
            }
        }
    }

    private func row(for group: RangeGroup, visible: [PID], xDomain: ClosedRange<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(visible.map(\.name).joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text("\(group.range.lowerBound.formattedGauge)–\(group.range.upperBound.formattedGauge) \(visible[0].unit)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(visible) { pid in
                    ForEach(coordinator.telemetry.samples(for: pid.id, within: windowSeconds)) { sample in
                        LineMark(
                            x: .value("Time", sample.timestamp),
                            y: .value(pid.name, sample.value.clamped(to: group.range)),
                            series: .value("Channel", pid.name)
                        )
                        .foregroundStyle(color(for: pid))
                        .interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: group.range)
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .chartPlotStyle { $0.clipped() }
            .frame(height: 150)
        }
        .carxCard()
    }
}
