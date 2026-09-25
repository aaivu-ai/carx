import SwiftUI

struct LinearBarGaugeView: View {
    let name: String
    let value: Double
    let unit: String
    let range: ClosedRange<Double>

    private var fraction: Double {
        guard range.upperBound > range.lowerBound else { return 0 }
        return ((value - range.lowerBound) / (range.upperBound - range.lowerBound)).clamped(to: 0...1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value.formattedGauge + " " + unit)
                    .font(.subheadline.weight(.bold).monospaced())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [CaRxTheme.accentSecondary, CaRxTheme.accent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * fraction)
                        .carxGlow(CaRxTheme.accent, radius: 6)
                }
            }
            .frame(height: 10)
            .animation(.easeOut(duration: 0.3), value: fraction)
        }
    }
}

#Preview {
    ZStack {
        CaRxBackground()
        LinearBarGaugeView(name: "Throttle Position", value: 42, unit: "%", range: 0...100)
            .padding()
    }
}
