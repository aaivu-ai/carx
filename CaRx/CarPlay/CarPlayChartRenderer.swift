import SwiftUI
import Charts
import UIKit

/// CarPlay has no chart template and no freeform drawing surface, but templates accept
/// `UIImage`s. Each chart tile is a SwiftUI view rasterized to an image and shown as a
/// `CPGridButton` icon, so the trend is visible without any custom CarPlay UI.
private struct CarPlayChartTile: View {
    let value: Double?
    let unit: String
    let samples: [RollingBuffer.Sample]
    let range: ClosedRange<Double>

    var body: some View {
        ZStack {
            CaRxTheme.background
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value.map { $0.formattedGauge } ?? "--")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    Text(unit)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.gray)
                }
                Chart(samples) { sample in
                    AreaMark(x: .value("Time", sample.timestamp), y: .value("Value", sample.value.clamped(to: range)))
                        .foregroundStyle(LinearGradient(colors: [CaRxTheme.accent.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Time", sample.timestamp), y: .value("Value", sample.value.clamped(to: range)))
                        .foregroundStyle(CaRxTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                }
                .chartYScale(domain: range)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartPlotStyle { $0.clipped() }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .padding(.top, 6)
        }
    }
}

@MainActor
enum CarPlayChartRenderer {
    static func tileImage(pid: PID, samples: [RollingBuffer.Sample], value: Double?, size: CGSize, scale: CGFloat) -> UIImage {
        let view = CarPlayChartTile(value: value, unit: pid.unit, samples: samples, range: pid.range)
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage ?? UIImage()
    }
}
