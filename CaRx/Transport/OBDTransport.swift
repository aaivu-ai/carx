import Foundation

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed(String)
}

enum ConnectionMode: String, Codable, CaseIterable, Identifiable {
    case bluetoothLE = "Bluetooth LE"
    case wifi = "Wi-Fi"

    var id: String { rawValue }
}

enum TransportError: LocalizedError {
    case notConnected
    case timeout
    case peripheralUnavailable
    case invalidHostOrPort
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to an OBD-II adapter."
        case .timeout: return "The adapter did not respond in time."
        case .peripheralUnavailable: return "No Bluetooth LE adapter was found. Make sure it's powered on and in range."
        case .invalidHostOrPort: return "Invalid Wi-Fi host or port."
        case .underlying(let error): return error.localizedDescription
        }
    }
}

/// Transport-agnostic pipe to an ELM327 adapter. Bluetooth LE and Wi-Fi
/// implementations both speak plain ASCII AT/OBD command-response lines
/// over this protocol so `ELM327Session` never needs to know which one it's using.
/// `Sendable` because `ELM327Session` (an actor) holds and calls into it; every
/// conformer confines its actual mutable state to a single queue/actor internally.
protocol OBDTransport: AnyObject, Sendable {
    var connectionState: AsyncStream<ConnectionState> { get }
    var incomingLines: AsyncStream<String> { get }

    func connect() async throws
    func disconnect()
    func send(_ command: String) async throws
}
