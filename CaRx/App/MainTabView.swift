import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(OBDCoordinator.self) private var coordinator
    @AppStorage("useMockHardware") private var useMockHardware: Bool = true
    let activeProfile: VehicleProfile
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(activeProfile: activeProfile)
                .tabItem { Label("Dashboard", systemImage: "gauge.with.needle") }
                .tag(0)

            DTCView(activeProfile: activeProfile)
                .tabItem { Label("Codes", systemImage: "exclamationmark.triangle.fill") }
                .tag(1)

            ChartsView()
                .tabItem { Label("Charts", systemImage: "chart.xyaxis.line") }
                .tag(2)

            SettingsView(activeProfile: activeProfile)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(CaRxTheme.accent)
        .task(id: "\(activeProfile.id)-\(useMockHardware)") {
            coordinator.useMockHardware = useMockHardware
            await coordinator.start(profile: activeProfile)
        }
    }
}

/// Always-visible connection state pill so a dropped adapter is never buried in a settings screen.
struct ConnectionStatusBanner: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .carxGlow(color, radius: 6)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(.ultraThinMaterial))
    }

    private var label: String {
        switch state {
        case .disconnected: return "DISCONNECTED"
        case .connecting: return "CONNECTING"
        case .connected: return "LIVE"
        case .reconnecting: return "RECONNECTING"
        case .failed: return "CONNECTION FAILED"
        }
    }

    private var color: Color {
        switch state {
        case .connected: return CaRxTheme.success
        case .connecting, .reconnecting: return CaRxTheme.warning
        case .disconnected: return .gray
        case .failed: return CaRxTheme.danger
        }
    }
}
