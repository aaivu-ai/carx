import Foundation

enum DTCMode {
    case current   // Mode 03
    case pending   // Mode 07
    case permanent // Mode 0A

    var requestCode: String {
        switch self {
        case .current: return "03"
        case .pending: return "07"
        case .permanent: return "0A"
        }
    }

    var responseEcho: String {
        switch self {
        case .current: return "43"
        case .pending: return "47"
        case .permanent: return "4A"
        }
    }
}

/// Owns the AsyncStream iterator so it never has to cross an isolation boundary as a
/// bare (non-`Sendable`) value -- `ELM327Session` just calls `await lineReader.next()`,
/// a plain actor-to-actor call.
private actor LineReader {
    // `nonisolated(unsafe)` because `AsyncIterator.next()` isn't `Sendable`-checked
    // cleanly by the compiler even from within its own owning actor; safe here because
    // the actor's own isolation already serializes every call into `next()` below,
    // so this is never touched by more than one caller at a time.
    private nonisolated(unsafe) var iterator: AsyncStream<String>.AsyncIterator
    init(stream: AsyncStream<String>) { iterator = stream.makeAsyncIterator() }

    func next() async -> String? {
        await iterator.next()
    }
}

/// Owns the ELM327 AT handshake, ECU header switching, and command/response
/// matching on top of a transport-agnostic `OBDTransport`. Only one command
/// is ever in flight at a time, matching how ELM327 adapters actually behave.
actor ELM327Session {
    private let transport: OBDTransport
    private var lineReader: LineReader?
    private var currentHeader: String = ""

    init(transport: OBDTransport) {
        self.transport = transport
    }

    func initialize() async throws {
        lineReader = LineReader(stream: transport.incomingLines)
        currentHeader = ""
        try await sendRaw("ATZ")
        try await sendRaw("ATE0")   // echo off
        try await sendRaw("ATL0")  // linefeeds off
        try await sendRaw("ATH1")  // headers on, needed to tell ECM/TCM responses apart
        try await sendRaw("ATSP0") // auto protocol
    }

    /// Reads one PID, switching the ECU header first if this PID targets a different module.
    func read(_ pid: PID) async throws -> Double {
        try await ensureHeader(pid.header)
        try await transport.send(pid.request)
        let line = try await nextNonEmptyLine()
        let bytes = Self.dataBytes(fromResponse: line, request: pid.request)
        return pid.decode(bytes)
    }

    func readDTCs(mode: DTCMode) async throws -> [String] {
        try await ensureHeader("7E0")
        try await transport.send(mode.requestCode)
        let line = try await nextNonEmptyLine()
        return DTCParser.parse(response: line, expectedEcho: mode.responseEcho)
    }

    /// Mode 02, PID 02: which DTC (if any) triggered the currently-stored freeze frame.
    func readFreezeFrameDTC() async throws -> String? {
        try await ensureHeader("7E0")
        try await transport.send("0202")
        let line = try await nextNonEmptyLine()
        return DTCParser.parseFreezeFrameDTC(response: line)
    }

    /// Advanced/discovery tool: send an arbitrary mode+PID hex string at an arbitrary
    /// header and return the raw response, unparsed. This is how enhanced PID packs
    /// (see §5b of the dev prompt) get verified and corrected against a real vehicle.
    func sendRawDiagnostic(header: String, request: String) async throws -> String {
        try await ensureHeader(header)
        try await transport.send(request)
        return try await nextNonEmptyLine()
    }

    /// Mode 04: clear all stored DTCs. Returns true if the adapter acknowledged the clear.
    @discardableResult
    func clearDTCs() async throws -> Bool {
        try await ensureHeader("7E0")
        try await transport.send("04")
        let line = try await nextNonEmptyLine()
        return line.uppercased().contains("44")
    }

    private func ensureHeader(_ header: String) async throws {
        guard header != currentHeader else { return }
        try await sendRaw("AT SH \(header)")
        currentHeader = header
    }

    @discardableResult
    private func sendRaw(_ command: String) async throws -> String {
        try await transport.send(command)
        return try await nextNonEmptyLine()
    }

    private func nextNonEmptyLine() async throws -> String {
        while true {
            guard let line = try await lineWithTimeout() else { throw TransportError.timeout }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
    }

    /// Races a single `pullNextLine()` against a 2s timeout. Both sides only ever touch
    /// actor-isolated state through `self`, so nothing mutable crosses the task boundary.
    private func lineWithTimeout() async throws -> String? {
        try await withThrowingTaskGroup(of: String?.self) { group in
            group.addTask { await self.pullNextLine() }
            group.addTask {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                throw TransportError.timeout
            }
            guard let result = try await group.next() else { throw TransportError.timeout }
            group.cancelAll()
            return result
        }
    }

    private func pullNextLine() async -> String? {
        guard let lineReader else { return nil }
        return await lineReader.next()
    }

    /// Strips the mode/PID echo bytes from a hex response line, leaving just the data payload.
    static func dataBytes(fromResponse response: String, request: String) -> Data {
        let hex = response.replacingOccurrences(of: " ", with: "").uppercased()
        guard hex.count.isMultiple(of: 2), hex.count >= 4 else { return Data() }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { break }
            bytes.append(byte)
            index = next
        }
        // Drop the leading echo bytes: 1 byte for mode-01 echo (0x41+PID) or
        // 2 bytes for mode-22 echo (0x62 + 2-byte extended PID).
        let requestIsExtended = request.hasPrefix("22")
        let echoByteCount = requestIsExtended ? 3 : 2
        guard bytes.count > echoByteCount else { return Data() }
        return Data(bytes.dropFirst(echoByteCount))
    }
}
