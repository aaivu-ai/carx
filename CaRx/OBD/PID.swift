import Foundation

/// A single readable sensor: how to request it from the ECU and how to decode the response.
struct PID: Identifiable, Hashable {
    let id: String
    let name: String
    let request: String        // e.g. "010C" (mode 01, PID 0C) or "2211B0" (mode 22, extended PID 11B0)
    let header: String         // target ECU header, e.g. "7E0"
    let unit: String
    let minValue: Double
    let maxValue: Double
    /// Whether this PID's exact hex code has been confirmed against a real vehicle.
    /// Manufacturer-specific PIDs are reverse-engineered by the community and vary by
    /// trim/engine/ECU revision -- see CaRx_iOS_CarPlay_Development_Prompt.md §5b.
    let verified: Bool
    let decode: @Sendable (Data) -> Double

    var range: ClosedRange<Double> { minValue...maxValue }

    static func == (lhs: PID, rhs: PID) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PIDDecoders {
    /// Standard formula: A - 40, both in Celsius. Used by coolant/intake/oil temp PIDs.
    static func temperatureCelsius(_ data: Data) -> Double {
        guard let a = data.first else { return 0 }
        return Double(a) - 40
    }

    static func temperatureFahrenheit(_ data: Data) -> Double {
        temperatureCelsius(data) * 9 / 5 + 32
    }

    /// RPM = ((A*256)+B)/4
    static func rpm(_ data: Data) -> Double {
        guard data.count >= 2 else { return 0 }
        return (Double(data[0]) * 256 + Double(data[1])) / 4
    }

    /// Speed in km/h = A, converted to mph.
    static func speedMph(_ data: Data) -> Double {
        guard let a = data.first else { return 0 }
        return Double(a) * 0.621371
    }

    /// Percent = A * 100 / 255
    static func percent(_ data: Data) -> Double {
        guard let a = data.first else { return 0 }
        return Double(a) * 100 / 255
    }

    /// Single raw byte, no scaling.
    static func rawByte(_ data: Data) -> Double {
        guard let a = data.first else { return 0 }
        return Double(a)
    }

    /// Timing advance = A/2 - 64 degrees.
    static func timingAdvance(_ data: Data) -> Double {
        guard let a = data.first else { return 0 }
        return Double(a) / 2 - 64
    }

    /// Voltage from two bytes = ((A*256)+B)/1000
    static func voltage(_ data: Data) -> Double {
        guard data.count >= 2 else { return 0 }
        return (Double(data[0]) * 256 + Double(data[1])) / 1000
    }

    /// kPa absolute pressure -> PSI, using single raw byte in kPa.
    static func kPaToPsi(_ data: Data) -> Double {
        guard let a = data.first else { return 0 }
        return Double(a) * 0.145038
    }

    /// Boost gauge PSI relative to atmosphere: raw kPa byte - 101.3 kPa baseline, to PSI.
    static func boostPsiRelative(_ data: Data) -> Double {
        guard let a = data.first else { return 0 }
        return (Double(a) - 101.3) * 0.145038
    }

    /// MAF g/s = ((A*256)+B)/100
    static func mafGramsPerSecond(_ data: Data) -> Double {
        guard data.count >= 2 else { return 0 }
        return (Double(data[0]) * 256 + Double(data[1])) / 100
    }
}
