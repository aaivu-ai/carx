import CarPlay
import UIKit

/// CarPlay entry point. IMPORTANT: this only renders once Apple has granted CaRx a
/// CarPlay entitlement for an approved category (see §8b of the dev prompt) -- there is
/// no public entitlement for freeform custom UI/gauges on the CarPlay screen, so this
/// intentionally sticks to standard CPTemplate types (list/grid/information), fed by the
/// same `OBDCoordinator.telemetry` the iPhone dashboard uses.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var dashboardController: CarPlayDashboardController?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController

        let coordinator = AppEnvironment.shared.coordinator
        let dashboardController = CarPlayDashboardController(interfaceController: interfaceController, coordinator: coordinator)
        self.dashboardController = dashboardController
        dashboardController.start()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        dashboardController?.stop()
        dashboardController = nil
        self.interfaceController = nil
    }
}

/// Small shared-instance holder so the CarPlay scene (which has no SwiftUI environment)
/// can reach the same `OBDCoordinator` the phone UI uses.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    let coordinator = OBDCoordinator()
    private init() {}
}
