import Foundation
import Observation

/// Top-level runtime engine: owns the active transport + ELM327 session, runs the
/// adaptive polling loop over whichever PIDs the dashboard/charts currently need,
/// and publishes everything into a `TelemetryStore` for the UI (and CarPlay) to read.
/// `@MainActor` because every caller (SwiftUI views, CarPlayDashboardController) is
/// already on the main actor -- this keeps SwiftData model handoff (e.g. `VehicleProfile`
/// in `start(profile:)`) isolation-safe under Swift 6 strict concurrency.
@Observable
@MainActor
final class OBDCoordinator {
    let telemetry = TelemetryStore()

    private var transport: OBDTransport?
    private var session: ELM327Session?
    private var pollingTask: Task<Void, Never>?
    private var stateObservationTask: Task<Void, Never>?

    /// PIDs the currently-visible UI actually needs. The polling loop only requests
    /// these, so refresh rate stays high instead of round-robining the entire registry.
    private(set) var activePIDs: [PID] = []
    private var activeProfile: VehicleProfile?

    var connectionState: ConnectionState { telemetry.connectionState }

    func setActivePIDs(_ pids: [PID]) {
        activePIDs = pids
    }

    /// When true, connects a `MockTransport` instead of real hardware -- lets the whole
    /// app (dashboard, DTCs, charts) be demoed in Simulator with zero physical adapter.
    var useMockHardware = false

    func start(profile: VehicleProfile) async {
        stop()
        activeProfile = profile
        telemetry.reset()
        telemetry.activePack = VehiclePackLoader.load(named: profile.vehiclePackID) ?? VehiclePackLoader.genericPack

        let transport = useMockHardware ? MockTransport() : makeTransport(for: profile)
        self.transport = transport
        let session = ELM327Session(transport: transport)
        self.session = session

        observeConnectionState(of: transport)

        do {
            telemetry.connectionState = .connecting
            try await transport.connect()
            try await session.initialize()
            telemetry.connectionState = .connected
            startPollingLoop()
        } catch {
            telemetry.connectionState = .failed(error.localizedDescription)
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        stateObservationTask?.cancel()
        stateObservationTask = nil
        transport?.disconnect()
        transport = nil
        session = nil
        telemetry.connectionState = .disconnected
    }

    func refreshDTCs() async {
        guard let session else { return }
        do {
            async let current = session.readDTCs(mode: .current)
            async let pending = session.readDTCs(mode: .pending)
            async let permanent = session.readDTCs(mode: .permanent)
            let (currentCodes, pendingCodes, permanentCodes) = try await (current, pending, permanent)
            telemetry.currentDTCs = currentCodes.map(DiagnosticCode.init)
            telemetry.pendingDTCs = pendingCodes.map(DiagnosticCode.init)
            telemetry.permanentDTCs = permanentCodes.map(DiagnosticCode.init)
            telemetry.lastDTCPollDate = Date()
        } catch {
            // Leave prior DTC state in place rather than clearing it on a transient read failure.
        }
    }

    /// Sends Mode 04 and re-polls to confirm codes actually cleared, since some ECUs
    /// silently reject a clear request while MIL-on conditions are still active.
    @discardableResult
    func eraseDTCs() async -> Bool {
        guard let session else { return false }
        do {
            try await session.clearDTCs()
            try await Task.sleep(nanoseconds: 300_000_000)
            await refreshDTCs()
            return telemetry.currentDTCs.isEmpty
        } catch {
            return false
        }
    }

    func readFreezeFrameDTC() async -> String? {
        try? await session?.readFreezeFrameDTC()
    }

    func sendRawDiagnostic(header: String, request: String) async -> Result<String, Error> {
        guard let session else { return .failure(TransportError.notConnected) }
        do {
            return .success(try await session.sendRawDiagnostic(header: header, request: request))
        } catch {
            return .failure(error)
        }
    }

    private func startPollingLoop() {
        pollingTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                guard let session = self.session, self.connectionState == .connected else {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
                let pids = self.activePIDs
                guard !pids.isEmpty else {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
                for pid in pids {
                    guard !Task.isCancelled else { break }
                    if let value = try? await session.read(pid) {
                        self.telemetry.record(value, for: pid.id)
                    }
                }
            }
        }
    }

    private func observeConnectionState(of transport: OBDTransport) {
        stateObservationTask = Task { [weak self] in
            for await state in transport.connectionState {
                self?.telemetry.connectionState = state
            }
        }
    }

    private func makeTransport(for profile: VehicleProfile) -> OBDTransport {
        switch profile.connectionMode {
        case .bluetoothLE:
            let identifier = profile.blePeripheralIdentifier.flatMap(UUID.init(uuidString:))
            return BLEELM327Transport(savedPeripheralIdentifier: identifier)
        case .wifi:
            return WiFiELM327Transport(host: profile.wifiHost, port: UInt16(clamping: profile.wifiPort))
        }
    }
}
