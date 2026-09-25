import CarPlay
import UIKit

/// Drives the CarPlay screen using only standard templates (CPListTemplate /
/// CPInformationTemplate / CPAlertTemplate) -- see the disclaimer in
/// CarPlaySceneDelegate.swift for why this can't be a custom gauge dashboard.
@MainActor
final class CarPlayDashboardController {
    private let interfaceController: CPInterfaceController
    private let coordinator: OBDCoordinator
    private var refreshTask: Task<Void, Never>?

    private lazy var liveDataTemplate: CPListTemplate = {
        let template = CPListTemplate(title: "CaRx Live", sections: [])
        template.tabTitle = "Live"
        template.tabImage = UIImage(systemName: "gauge.with.needle")
        return template
    }()

    private lazy var dtcTemplate: CPInformationTemplate = {
        let template = CPInformationTemplate(title: "Trouble Codes", layout: .leading, items: [], actions: [clearCodesAction])
        template.tabTitle = "Codes"
        template.tabImage = UIImage(systemName: "exclamationmark.triangle")
        return template
    }()

    private lazy var clearCodesAction = CPTextButton(title: "Clear Codes", textStyle: .confirm) { [weak self] _ in
        self?.presentClearConfirmation()
    }

    init(interfaceController: CPInterfaceController, coordinator: OBDCoordinator) {
        self.interfaceController = interfaceController
        self.coordinator = coordinator
    }

    func start() {
        let tabBar = CPTabBarTemplate(templates: [liveDataTemplate, dtcTemplate])
        interfaceController.setRootTemplate(tabBar, animated: true, completion: nil)
        refreshTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                self.render()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func render() {
        let telemetry = coordinator.telemetry
        let pack = telemetry.activePack
        let pidsByID = Dictionary(uniqueKeysWithValues: pack.allPIDs.map { ($0.id, $0) })

        // CarPlay is glanceable-only: cap to the pack's top few dashboard PIDs.
        let items: [CPListItem] = pack.defaultDashboardPIDIDs.prefix(6).compactMap { pidID in
            guard let pid = pidsByID[pidID] else { return nil }
            let value = telemetry.value(for: pidID)
            let text = value.map { "\($0.formattedGauge) \(pid.unit)" } ?? "--"
            return CPListItem(text: pid.name, detailText: text)
        }
        liveDataTemplate.updateSections([CPListSection(items: items)])

        let dtcItems = telemetry.currentDTCs.map {
            CPInformationItem(title: $0.code, detail: $0.description)
        }
        dtcTemplate.items = dtcItems.isEmpty ? [CPInformationItem(title: "No codes", detail: "No trouble codes detected.")] : dtcItems
    }

    private func presentClearConfirmation() {
        let confirm = CPAlertAction(title: "Clear Codes", style: .destructive) { [weak self] _ in
            Task { await self?.coordinator.eraseDTCs() }
        }
        let cancel = CPAlertAction(title: "Cancel", style: .cancel) { _ in }
        let alert = CPAlertTemplate(titleVariants: ["Clear all stored trouble codes? This cannot be undone."], actions: [confirm, cancel])
        interfaceController.presentTemplate(alert, animated: true, completion: nil)
    }
}
