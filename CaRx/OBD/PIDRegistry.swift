import Foundation

/// The standard SAE J1979 Mode 01 PID set, available on essentially every
/// OBD-II compliant vehicle regardless of make. Manufacturer-specific "enhanced"
/// PIDs are layered on top of this via `VehiclePack` (see VehiclePacks/).
enum StandardPIDRegistry {
    static let all: [PID] = [
        PID(id: "STD_RPM", name: "Engine Speed", request: "010C", header: "7E0",
            unit: "RPM", minValue: 0, maxValue: 8000, verified: true, decode: PIDDecoders.rpm),

        PID(id: "STD_SPEED", name: "Vehicle Speed", request: "010D", header: "7E0",
            unit: "MPH", minValue: 0, maxValue: 160, verified: true, decode: PIDDecoders.speedMph),

        PID(id: "STD_ECT", name: "Engine Coolant Temp", request: "0105", header: "7E0",
            unit: "°F", minValue: -40, maxValue: 260, verified: true, decode: PIDDecoders.temperatureFahrenheit),

        PID(id: "STD_IAT", name: "Intake Air Temp", request: "010F", header: "7E0",
            unit: "°F", minValue: -40, maxValue: 200, verified: true, decode: PIDDecoders.temperatureFahrenheit),

        PID(id: "STD_MAF", name: "Mass Air Flow", request: "0110", header: "7E0",
            unit: "g/s", minValue: 0, maxValue: 400, verified: true, decode: PIDDecoders.mafGramsPerSecond),

        PID(id: "STD_THROTTLE", name: "Throttle Position", request: "0111", header: "7E0",
            unit: "%", minValue: 0, maxValue: 100, verified: true, decode: PIDDecoders.percent),

        PID(id: "STD_LOAD", name: "Calculated Engine Load", request: "0104", header: "7E0",
            unit: "%", minValue: 0, maxValue: 100, verified: true, decode: PIDDecoders.percent),

        PID(id: "STD_FUEL_LEVEL", name: "Fuel Level", request: "012F", header: "7E0",
            unit: "%", minValue: 0, maxValue: 100, verified: true, decode: PIDDecoders.percent),

        PID(id: "STD_TIMING_ADV", name: "Timing Advance", request: "010E", header: "7E0",
            unit: "°", minValue: -64, maxValue: 64, verified: true, decode: PIDDecoders.timingAdvance),

        PID(id: "STD_MAP", name: "Intake Manifold Pressure", request: "010B", header: "7E0",
            unit: "PSI", minValue: 0, maxValue: 45, verified: true, decode: PIDDecoders.kPaToPsi),

        PID(id: "STD_CONTROL_VOLTAGE", name: "Control Module Voltage", request: "0142", header: "7E0",
            unit: "V", minValue: 8, maxValue: 18, verified: true, decode: PIDDecoders.voltage),

        PID(id: "STD_O2_B1S1", name: "O2 Sensor B1S1", request: "0114", header: "7E0",
            unit: "V", minValue: 0, maxValue: 1.275, verified: true, decode: { data in
                guard let a = data.first else { return 0 }
                return Double(a) / 200
            }),
    ]

    static func byID(_ id: String) -> PID? { all.first { $0.id == id } }
}
