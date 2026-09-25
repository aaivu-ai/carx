import SwiftUI

/// Shared "modern & futuristic" visual language: deep near-black backgrounds,
/// a single neon accent, glassy cards, and a glow modifier for live/active state.
enum CaRxTheme {
    static let background = Color(red: 0.043, green: 0.059, blue: 0.078)   // #0B0F14
    static let surface = Color(red: 0.086, green: 0.106, blue: 0.133)      // #161B22-ish
    static let surfaceElevated = Color(red: 0.11, green: 0.135, blue: 0.165)
    static let accent = Color(red: 0.0, green: 0.898, blue: 1.0)           // electric cyan
    static let accentSecondary = Color(red: 0.55, green: 0.36, blue: 1.0)  // violet
    static let danger = Color(red: 1.0, green: 0.29, blue: 0.29)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.2)
    static let success = Color(red: 0.2, green: 0.9, blue: 0.55)

    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 14
}

extension View {
    /// Frosted, subtly-bordered card surface used across dashboard widgets, DTC rows, and settings.
    func carxCard() -> some View {
        self
            .padding(CaRxTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: CaRxTheme.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: CaRxTheme.cornerRadius, style: .continuous)
                            .fill(CaRxTheme.surface.opacity(0.6))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaRxTheme.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    /// Soft neon glow, used on live-updating traces and active/connected indicators.
    func carxGlow(_ color: Color = CaRxTheme.accent, radius: CGFloat = 10, active: Bool = true) -> some View {
        self.shadow(color: active ? color.opacity(0.6) : .clear, radius: radius)
    }
}

struct CaRxBackground: View {
    var body: some View {
        LinearGradient(
            colors: [CaRxTheme.background, Color(red: 0.02, green: 0.03, blue: 0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
