import SwiftUI
import Charts

struct SparklineCardView: View {
    let name: String
    let value: Double?
    let unit: String
    let samples: [RollingBuffer.Sample]
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(alignment: .center, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value.map { $0.formattedGauge } ?? "--")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Chart(samples) { sample in
                    LineMark(x: .value("Time", sample.timestamp), y: .value("Value", sample.value))
                        .foregroundStyle(CaRxTheme.accent)
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: range)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 34)
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: value)
    }
}

#Preview {
    ZStack {
        CaRxBackground()
        SparklineCardView(
            name: "Turbo Boost Pressure",
            value: 8.4,
            unit: "PSI",
            samples: (0..<30).map { .init(timestamp: Date().addingTimeInterval(Double($0)), value: Double.random(in: -2...15)) },
            range: -14.7...30
        )
        .carxCard()
        .padding()
    }
}
