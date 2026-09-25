import Foundation
import SwiftData

enum WidgetType: String, Codable, CaseIterable, Identifiable {
    case radialGauge
    case linearBarGauge
    case digitalCard
    case sparklineCard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .radialGauge: return "Radial Gauge"
        case .linearBarGauge: return "Linear Bar"
        case .digitalCard: return "Digital Card"
        case .sparklineCard: return "Sparkline Card"
        }
    }

    var systemImage: String {
        switch self {
        case .radialGauge: return "gauge.with.needle"
        case .linearBarGauge: return "chart.bar.fill"
        case .digitalCard: return "textformat.123"
        case .sparklineCard: return "waveform.path.ecg"
        }
    }
}

@Model
final class WidgetConfig {
    var id: UUID
    var pidID: String
    var widgetTypeRaw: String
    var customMin: Double?
    var customMax: Double?
    var sortOrder: Int
    var layout: DashboardLayout?

    var widgetType: WidgetType {
        get { WidgetType(rawValue: widgetTypeRaw) ?? .digitalCard }
        set { widgetTypeRaw = newValue.rawValue }
    }

    init(pidID: String, widgetType: WidgetType, sortOrder: Int, customMin: Double? = nil, customMax: Double? = nil) {
        self.id = UUID()
        self.pidID = pidID
        self.widgetTypeRaw = widgetType.rawValue
        self.customMin = customMin
        self.customMax = customMax
        self.sortOrder = sortOrder
    }
}
