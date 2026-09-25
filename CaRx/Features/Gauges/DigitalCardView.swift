import SwiftUI

struct DigitalCardView: View {
    let name: String
    let value: Double?
    let unit: String
    let isVerified: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !isVerified {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(CaRxTheme.warning)
                }
                Spacer()
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value.map { $0.formattedGauge } ?? "--")
                    .font(.system(size: 26, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.3), value: value)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack {
        CaRxBackground()
        DigitalCardView(name: "Battery IBS Voltage", value: 12.6, unit: "V", isVerified: false)
            .carxCard()
            .padding()
    }
}
