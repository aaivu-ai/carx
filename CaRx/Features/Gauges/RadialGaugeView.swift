import SwiftUI

struct RadialGaugeView: View {
    let name: String
    let value: Double
    let unit: String
    let range: ClosedRange<Double>
    var redlineStart: Double? = nil

    private var fraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return ((value - range.lowerBound) / (range.upperBound - range.lowerBound)).clamped(to: 0...1)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(90))

                if let redlineStart, range.upperBound > range.lowerBound {
                    let redlineFraction = ((redlineStart - range.lowerBound) / (range.upperBound - range.lowerBound)).clamped(to: 0...1)
                    Circle()
                        .trim(from: 0.12 + 0.76 * redlineFraction, to: 0.88)
                        .stroke(CaRxTheme.danger.opacity(0.55), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(90))
                }

                Circle()
                    .trim(from: 0.12, to: 0.12 + 0.76 * fraction)
                    .stroke(
                        AngularGradient(colors: [CaRxTheme.accentSecondary, CaRxTheme.accent], center: .center),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .carxGlow(CaRxTheme.accent, radius: 8)
                    .animation(.easeOut(duration: 0.35), value: fraction)

                VStack(spacing: 2) {
                    Text(value.formattedGauge)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.3), value: value)
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Text(name)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    var formattedGauge: String {
        abs(self) >= 100 ? String(format: "%.0f", self) : String(format: "%.1f", self)
    }
}

#Preview {
    ZStack {
        CaRxBackground()
        RadialGaugeView(name: "Engine Speed", value: 3200, unit: "RPM", range: 0...8000, redlineStart: 6500)
            .frame(width: 180, height: 220)
    }
}
