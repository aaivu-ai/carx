import SwiftUI
import SwiftData

@main
struct CaRxApp: App {
    let modelContainer: ModelContainer
    // Shared with the CarPlay scene (see CarPlaySceneDelegate/AppEnvironment) so both
    // screens always reflect the same live telemetry, connection state, and DTCs.
    private let coordinator = AppEnvironment.shared.coordinator

    init() {
        do {
            modelContainer = try ModelContainer(for: VehicleProfile.self, DashboardLayout.self, WidgetConfig.self, ChartPreset.self, DiagnosticEventRecord.self)
        } catch {
            fatalError("Failed to create SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
