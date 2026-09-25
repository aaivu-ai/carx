import Foundation
import Observation

/// Live, in-memory telemetry state shared by the dashboard, charts, and the
/// CarPlay templates -- everything reads from this one store so phone and car
/// screen never show different numbers.
@Observable
final class TelemetryStore {
    private(set) var buffers: [String: RollingBuffer] = [:]
    var connectionState: ConnectionState = .disconnected
    var currentDTCs: [DiagnosticCode] = []
    var pendingDTCs: [DiagnosticCode] = []
    var permanentDTCs: [DiagnosticCode] = []
    var lastDTCPollDate: Date?
    var activePack: VehiclePack = VehiclePackLoader.genericPack

    func value(for pidID: String) -> Double? {
        buffers[pidID]?.latest
    }

    func samples(for pidID: String, within window: TimeInterval) -> [RollingBuffer.Sample] {
        buffers[pidID]?.samples(within: window) ?? []
    }

    func record(_ value: Double, for pidID: String) {
        var buffer = buffers[pidID] ?? RollingBuffer()
        buffer.append(value)
        buffers[pidID] = buffer
    }

    func reset() {
        buffers.removeAll()
        currentDTCs = []
        pendingDTCs = []
        permanentDTCs = []
    }
}

struct DiagnosticCode: Identifiable, Hashable {
    var id: String { code }
    let code: String
    let description: String

    init(code: String) {
        self.code = code
        self.description = DTCDatabase.description(for: code)
    }
}
