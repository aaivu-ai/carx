import Foundation
import SwiftData

@Model
final class DashboardLayout {
    var id: UUID
    var name: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \WidgetConfig.layout)
    var widgets: [WidgetConfig] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    /// Builds a default layout seeded from a vehicle pack's recommended PIDs,
    /// pairing gauges/cards sensibly (gauge for the "hero" sensor, cards for the rest).
    static func makeDefault(for pack: VehiclePack) -> DashboardLayout {
        let layout = DashboardLayout(name: "\(pack.displayName) Default")
        let allPIDsByID = Dictionary(uniqueKeysWithValues: pack.allPIDs.map { ($0.id, $0) })
        for (index, pidID) in pack.defaultDashboardPIDIDs.enumerated() {
            guard allPIDsByID[pidID] != nil else { continue }
            let type: WidgetType = index == 0 ? .radialGauge : (index % 3 == 0 ? .sparklineCard : .digitalCard)
            let widget = WidgetConfig(pidID: pidID, widgetType: type, sortOrder: index)
            widget.layout = layout
            layout.widgets.append(widget)
        }
        return layout
    }
}
