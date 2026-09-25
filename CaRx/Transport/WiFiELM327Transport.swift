import Foundation
import Network

/// TCP transport for Wi-Fi ELM327 adapters, which typically host a small TCP
/// server at 192.168.0.10:35000 once the phone joins their access point.
///
/// All mutable state here is only ever touched from the `.main` queue that the
/// `NWConnection` is started with (every stateUpdateHandler/receive/send completion
/// runs there), so the type is safe despite being `@unchecked Sendable` -- Swift's
/// concurrency checker just can't see that single-queue confinement on its own.
final class WiFiELM327Transport: OBDTransport, @unchecked Sendable {
    private let host: String
    private let port: UInt16
    private var connection: NWConnection?
    private var didResumeConnect = false

    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private var lineContinuation: AsyncStream<String>.Continuation?

    let connectionState: AsyncStream<ConnectionState>
    let incomingLines: AsyncStream<String>

    private var lineBuffer = ""

    init(host: String = "192.168.0.10", port: UInt16 = 35000) {
        self.host = host
        self.port = port

        var stateCont: AsyncStream<ConnectionState>.Continuation!
        connectionState = AsyncStream { stateCont = $0 }
        stateContinuation = stateCont

        var lineCont: AsyncStream<String>.Continuation!
        incomingLines = AsyncStream { lineCont = $0 }
        lineContinuation = lineCont
    }

    func connect() async throws {
        guard let nwHost = IPv4Address(host).map({ NWEndpoint.Host.ipv4($0) }) ?? Optional(NWEndpoint.Host(host)),
              let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw TransportError.invalidHostOrPort
        }

        stateContinuation?.yield(.connecting)

        let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        self.connection = connection

        didResumeConnect = false
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard !self.didResumeConnect else {
                        self.stateContinuation?.yield(.connected)
                        return
                    }
                    self.didResumeConnect = true
                    self.stateContinuation?.yield(.connected)
                    self.startReceiveLoop()
                    continuation.resume()
                case .failed(let error):
                    self.stateContinuation?.yield(.failed(error.localizedDescription))
                    if !self.didResumeConnect {
                        self.didResumeConnect = true
                        continuation.resume(throwing: TransportError.underlying(error))
                    }
                case .cancelled:
                    self.stateContinuation?.yield(.disconnected)
                default:
                    break
                }
            }
            connection.start(queue: .main)
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        stateContinuation?.yield(.disconnected)
    }

    func send(_ command: String) async throws {
        guard let connection else { throw TransportError.notConnected }
        let payload = Data((command + "\r").utf8)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: payload, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: TransportError.underlying(error))
                } else {
                    continuation.resume()
                }
            })
        }
    }

    private func startReceiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.emitLines(from: data)
            }
            if let error {
                self.stateContinuation?.yield(.failed(error.localizedDescription))
                return
            }
            if isComplete {
                self.stateContinuation?.yield(.disconnected)
                return
            }
            self.startReceiveLoop()
        }
    }

    private func emitLines(from data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        lineBuffer += chunk
        let normalized = lineBuffer.replacingOccurrences(of: ">", with: "\r")
        let parts = normalized.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
        for part in parts.dropLast() where !part.trimmingCharacters(in: .whitespaces).isEmpty {
            lineContinuation?.yield(part.trimmingCharacters(in: .whitespaces))
        }
        lineBuffer = parts.last ?? ""
    }
}
