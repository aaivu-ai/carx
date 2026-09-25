import Foundation
@preconcurrency import CoreBluetooth

/// Bluetooth LE transport for ELM327-compatible adapters that expose a UART-style
/// GATT service (e.g. Nordic UART Service, used by most BLE ELM327 dongles such as
/// the Vgate iCar Pro BLE and OBDLink CX/MX+).
///
/// NOTE: classic Bluetooth (SPP/RFCOMM) ELM327 clones are NOT supported here — iOS has
/// no public API for Bluetooth Classic RFCOMM without an MFi chip. Only BLE adapters work.
///
/// `@unchecked Sendable`: the `CBCentralManager` here is created with `queue: .main`,
/// so every delegate callback -- and therefore every mutation of this class's state --
/// happens serially on the main queue, even though CoreBluetooth doesn't express that
/// confinement in the type system itself.
final class BLEELM327Transport: NSObject, OBDTransport, @unchecked Sendable {
    // Nordic UART Service, the de-facto standard most BLE ELM327 adapters implement.
    static let uartServiceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let uartTXCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E") // write (phone -> adapter)
    static let uartRXCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E") // notify (adapter -> phone)

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txCharacteristic: CBCharacteristic?
    private var rxCharacteristic: CBCharacteristic?

    private var stateContinuation: AsyncStream<ConnectionState>.Continuation?
    private var lineContinuation: AsyncStream<String>.Continuation?
    private var connectContinuation: CheckedContinuation<Void, Error>?

    let connectionState: AsyncStream<ConnectionState>
    let incomingLines: AsyncStream<String>

    private var lineBuffer = ""
    private let targetPeripheralIdentifier: UUID?

    /// - Parameter savedPeripheralIdentifier: identifier of a previously-paired peripheral
    ///   (persisted on the `VehicleProfile`). If nil, connects to the first matching peripheral found.
    init(savedPeripheralIdentifier: UUID? = nil) {
        self.targetPeripheralIdentifier = savedPeripheralIdentifier

        var stateCont: AsyncStream<ConnectionState>.Continuation!
        connectionState = AsyncStream { stateCont = $0 }
        stateContinuation = stateCont

        var lineCont: AsyncStream<String>.Continuation!
        incomingLines = AsyncStream { lineCont = $0 }
        lineContinuation = lineCont

        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func connect() async throws {
        stateContinuation?.yield(.connecting)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectContinuation = continuation
            if centralManager.state == .poweredOn {
                centralManager.scanForPeripherals(withServices: [Self.uartServiceUUID])
            }
            // If Bluetooth isn't ready yet, centralManagerDidUpdateState will start the scan
            // once it powers on; the continuation is fulfilled from didConnect/didFailToConnect.
        }
    }

    func disconnect() {
        centralManager.stopScan()
        if let peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        stateContinuation?.yield(.disconnected)
    }

    func send(_ command: String) async throws {
        guard let peripheral, let txCharacteristic else { throw TransportError.notConnected }
        let payload = Data((command + "\r").utf8)
        peripheral.writeValue(payload, for: txCharacteristic, type: .withResponse)
    }

    private func emitLines(from data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        lineBuffer += chunk
        // ELM327 terminates responses with '>' prompt; split on CR and prompt characters.
        let normalized = lineBuffer.replacingOccurrences(of: ">", with: "\r")
        let parts = normalized.components(separatedBy: CharacterSet(charactersIn: "\r\n"))
        for part in parts.dropLast() where !part.trimmingCharacters(in: .whitespaces).isEmpty {
            lineContinuation?.yield(part.trimmingCharacters(in: .whitespaces))
        }
        lineBuffer = parts.last ?? ""
    }
}

extension BLEELM327Transport: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if connectContinuation != nil {
                central.scanForPeripherals(withServices: [Self.uartServiceUUID])
            }
        case .unauthorized, .unsupported, .poweredOff:
            stateContinuation?.yield(.failed("Bluetooth is unavailable. Check Settings > Bluetooth."))
            connectContinuation?.resume(throwing: TransportError.peripheralUnavailable)
            connectContinuation = nil
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let targetPeripheralIdentifier, peripheral.identifier != targetPeripheralIdentifier {
            return
        }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.uartServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        stateContinuation?.yield(.failed(error?.localizedDescription ?? "Failed to connect."))
        connectContinuation?.resume(throwing: TransportError.underlying(error ?? TransportError.peripheralUnavailable))
        connectContinuation = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        stateContinuation?.yield(.reconnecting)
    }
}

extension BLEELM327Transport: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.uartServiceUUID }) else {
            connectContinuation?.resume(throwing: TransportError.peripheralUnavailable)
            connectContinuation = nil
            return
        }
        peripheral.discoverCharacteristics([Self.uartTXCharacteristicUUID, Self.uartRXCharacteristicUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.uartTXCharacteristicUUID {
                txCharacteristic = characteristic
            } else if characteristic.uuid == Self.uartRXCharacteristicUUID {
                rxCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        if txCharacteristic != nil && rxCharacteristic != nil {
            stateContinuation?.yield(.connected)
            connectContinuation?.resume()
            connectContinuation = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.uartRXCharacteristicUUID, let data = characteristic.value else { return }
        emitLines(from: data)
    }
}
