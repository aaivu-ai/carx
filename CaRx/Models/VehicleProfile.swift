import Foundation
import SwiftData

@Model
final class VehicleProfile {
    var id: UUID
    var name: String
    var vehiclePackID: String
    var connectionModeRaw: String
    var wifiHost: String
    var wifiPort: Int
    var blePeripheralIdentifier: String?
    var createdAt: Date

    var connectionMode: ConnectionMode {
        get { ConnectionMode(rawValue: connectionModeRaw) ?? .wifi }
        set { connectionModeRaw = newValue.rawValue }
    }

    init(
        name: String,
        vehiclePackID: String,
        connectionMode: ConnectionMode = .wifi,
        wifiHost: String = "192.168.0.10",
        wifiPort: Int = 35000,
        blePeripheralIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.vehiclePackID = vehiclePackID
        self.connectionModeRaw = connectionMode.rawValue
        self.wifiHost = wifiHost
        self.wifiPort = wifiPort
        self.blePeripheralIdentifier = blePeripheralIdentifier
        self.createdAt = Date()
    }
}
