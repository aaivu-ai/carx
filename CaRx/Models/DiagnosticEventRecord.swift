import Foundation
import SwiftData

enum DiagnosticEventType: String, Codable {
    case read
    case cleared
}

/// A logged DTC read/clear event, kept for session history review.
@Model
final class DiagnosticEventRecord {
    var id: UUID
    var timestamp: Date
    var eventTypeRaw: String
    var codes: [String]
    var vehicleProfileName: String

    var eventType: DiagnosticEventType {
        get { DiagnosticEventType(rawValue: eventTypeRaw) ?? .read }
        set { eventTypeRaw = newValue.rawValue }
    }

    init(eventType: DiagnosticEventType, codes: [String], vehicleProfileName: String) {
        self.id = UUID()
        self.timestamp = Date()
        self.eventTypeRaw = eventType.rawValue
        self.codes = codes
        self.vehicleProfileName = vehicleProfileName
    }
}
