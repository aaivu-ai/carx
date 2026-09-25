import Foundation

/// Simulated ELM327 adapter so the whole app is demoable in Simulator
/// with zero physical hardware. Understands the same AT handshake and
/// mode 01 / mode 22 / mode 03 / mode 04 requests the real adapters do,
/// and fabricates plausible drifting values for whichever PIDs are asked for.
///
/// `@unchecked Sendable`: `ELM327Session` only ever has one command in flight at a
/// time and awaits each `send()` before issuing the next, so there's no real
/// concurrent access to this class's mutable state despite it not being an actor.
final class MockTransport: OBDTransport, @unchecked Sendable {
    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private var lineContinuation: AsyncStream<String>.Continuation?

    let connectionState: AsyncStream<ConnectionState>
    let incomingLines: AsyncStream<String>

    private var simulatedDTCs: [String] = ["P0234", "P0171"]
    private var phase: Double = 0
    private var driveTask: Task<Void, Never>?

    init() {
        var stateCont: AsyncStream<ConnectionState>.Continuation!
        connectionState = AsyncStream { stateCont = $0 }
        stateContinuation = stateCont

        var lineCont: AsyncStream<String>.Continuation!
        incomingLines = AsyncStream { lineCont = $0 }
        lineContinuation = lineCont
    }

    func connect() async throws {
        stateContinuation?.yield(.connecting)
        try? await Task.sleep(nanoseconds: 400_000_000)
        stateContinuation?.yield(.connected)
        phase = 0
    }

    func disconnect() {
        driveTask?.cancel()
        stateContinuation?.yield(.disconnected)
    }

    func send(_ command: String) async throws {
        let cmd = command.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        try? await Task.sleep(nanoseconds: 30_000_000)

        if cmd.hasPrefix("AT") {
            lineContinuation?.yield("OK")
            return
        }

        if cmd == "03" {
            if simulatedDTCs.isEmpty {
                lineContinuation?.yield("43 00")
            } else {
                lineContinuation?.yield(encodeMode03(simulatedDTCs))
            }
            return
        }

        if cmd == "04" {
            simulatedDTCs.removeAll()
            lineContinuation?.yield("44")
            return
        }

        if cmd == "07" || cmd == "0A" {
            lineContinuation?.yield("NO DATA")
            return
        }

        if cmd == "0202" {
            if let first = simulatedDTCs.first {
                lineContinuation?.yield("42 02 00 " + encodeDTC(first))
            } else {
                lineContinuation?.yield("NO DATA")
            }
            return
        }

        // Mode 01 / mode 22 PID request -> fabricate a response frame.
        phase += 0.12
        lineContinuation?.yield(fabricatedResponse(for: cmd))
    }

    private func fabricatedResponse(for request: String) -> String {
        // Very rough simulation: derive a wobbling byte pair from the PID hash and a running phase.
        let seed = Double(request.hashValue.magnitude % 1000)
        let wobble = sin(phase + seed) * 0.5 + 0.5 // 0...1
        let byte = UInt8(wobble * 200 + 20)
        let mode = String(request.prefix(2))
        let echoMode = mode == "22" ? "62" : "41"
        let pid = String(request.dropFirst(2))
        return "\(echoMode) \(pid) \(String(format: "%02X", byte)) \(String(format: "%02X", byte))"
    }

    private func encodeMode03(_ codes: [String]) -> String {
        "43 0\(codes.count) " + codes.map(encodeDTC).joined(separator: " ")
    }

    private func encodeDTC(_ code: String) -> String {
        // Rough P0234 -> hex byte pair encoding for the mock only; DTCParser does the real decode.
        guard code.count == 5 else { return "00 00" }
        let letterBits: UInt8
        switch code.first! {
        case "P": letterBits = 0b00
        case "C": letterBits = 0b01
        case "B": letterBits = 0b10
        default: letterBits = 0b11
        }
        let digits = code.dropFirst()
        guard let firstDigit = UInt8(String(digits.prefix(1))),
              let rest = UInt16(digits.dropFirst(), radix: 16) else { return "00 00" }
        let firstByte = (letterBits << 6) | (firstDigit << 4)
        let combined = UInt16(firstByte) << 8 | rest
        return String(format: "%02X %02X", UInt8(combined >> 8), UInt8(combined & 0xFF))
    }
}
