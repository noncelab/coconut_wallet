import CoreBluetooth
import Foundation

class BluetoothTransport: NSObject {

    private static let serviceUUID = CBUUID(string: "e1511a45-f3db-44c0-82b8-6c880790d1f1")
    private static let writeUUID   = CBUUID(string: "799d485c-d354-4ed0-b577-f8ee79ec275a")
    private static let readUUID    = CBUUID(string: "419572a5-9f53-4eb1-8db7-61bcab928867")
    private static let productUUID = CBUUID(string: "9d1c9a77-8b03-4e49-8053-3955cda7da93")

    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?

    private let readQueue = DispatchQueue(label: "bitbox02.ble.read")
    private var readSemaphore = DispatchSemaphore(value: 0)
    private var readBuffer = Data()

    private var connectCompletion: ((Result<Void, Error>) -> Void)?
    private var productString: String?

    override init() {
        super.init()
    }

    var product: String? {
        return productString
    }

    func scanAndConnect(timeout: TimeInterval, completion: @escaping (Result<Void, Error>) -> Void) {
        connectCompletion = completion
        centralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue(label: "bitbox02.ble.central"),
            options: [CBCentralManagerOptionShowPowerAlertKey: false]
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self, self.peripheral == nil else { return }
            self.connectCompletion?(.failure(
                NSError(domain: "BitBox02", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "BLE scan timed out"])
            ))
            self.connectCompletion = nil
        }
    }

    func disconnect() {
        if let peripheral = peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        readSemaphore.signal()
    }
}

// MARK: - BitboxbridgeTransport Protocol

extension BluetoothTransport: BitboxbridgeTransport {

    func read(_ p0: Data?, ret0_: UnsafeMutablePointer<Int>?, error: NSErrorPointer) -> Bool {
        guard let p0 = p0 else {
            error?.pointee = NSError(domain: "BitBox02", code: -2,
                                     userInfo: [NSLocalizedDescriptionKey: "null buffer"])
            return false
        }

        return readQueue.sync {
            while readBuffer.isEmpty {
                guard peripheral?.state == .connected else {
                    error?.pointee = NSError(domain: "BitBox02", code: -2,
                                             userInfo: [NSLocalizedDescriptionKey: "BLE disconnected"])
                    return false
                }
                if readSemaphore.wait(timeout: .now() + 5) == .timedOut {
                    if peripheral?.state != .connected {
                        error?.pointee = NSError(domain: "BitBox02", code: -2,
                                                 userInfo: [NSLocalizedDescriptionKey: "BLE disconnected"])
                        return false
                    }
                }
            }

            let count = min(readBuffer.count, p0.count)
            let dest = UnsafeMutableRawPointer(mutating: p0.withUnsafeBytes { $0.baseAddress! })
            readBuffer.withUnsafeBytes { src in
                memcpy(dest, src.baseAddress!, count)
            }
            readBuffer.removeFirst(count)

            ret0_?.pointee = count
            return true
        }
    }

    func write(_ p0: Data?, ret0_: UnsafeMutablePointer<Int>?, error: NSErrorPointer) -> Bool {
        guard let data = p0,
              let peripheral = peripheral,
              let writeChar = writeCharacteristic else {
            error?.pointee = NSError(domain: "BitBox02", code: -3,
                                     userInfo: [NSLocalizedDescriptionKey: "BLE not connected"])
            return false
        }

        let semaphore = DispatchSemaphore(value: 0)
        var writeError: Error?

        peripheral.writeValue(data, for: writeChar, type: .withResponse)

        if semaphore.wait(timeout: .now() + 5) == .timedOut {
            error?.pointee = NSError(domain: "BitBox02", code: -3,
                                     userInfo: [NSLocalizedDescriptionKey: "Write timeout"])
            return false
        }
        if let writeError = writeError {
            error?.pointee = writeError as NSError
            return false
        }

        ret0_?.pointee = data.count
        return true
    }

    func close(_ error: NSErrorPointer) -> Bool {
        disconnect()
        return true
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothTransport: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            connectCompletion?(.failure(
                NSError(domain: "BitBox02", code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Bluetooth not available"])
            ))
            connectCompletion = nil
            return
        }
        central.scanForPeripherals(
            withServices: [BluetoothTransport.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([BluetoothTransport.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        readSemaphore.signal()
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connectCompletion?(.failure(error ?? NSError(domain: "BitBox02", code: -5,
            userInfo: [NSLocalizedDescriptionKey: "BLE connection failed"])))
        connectCompletion = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothTransport: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            connectCompletion?(.failure(error))
            connectCompletion = nil
            return
        }
        guard let service = peripheral.services?.first else { return }
        peripheral.discoverCharacteristics(
            [BluetoothTransport.writeUUID, BluetoothTransport.readUUID, BluetoothTransport.productUUID],
            for: service
        )
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            connectCompletion?(.failure(error))
            connectCompletion = nil
            return
        }
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case BluetoothTransport.writeUUID:
                writeCharacteristic = characteristic
            case BluetoothTransport.readUUID:
                readCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            case BluetoothTransport.productUUID:
                peripheral.readValue(for: characteristic)
            default:
                break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        if characteristic.uuid == BluetoothTransport.readUUID {
            connectCompletion?(.success(()))
            connectCompletion = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if characteristic.uuid == BluetoothTransport.readUUID,
           let data = characteristic.value {
            readBuffer.append(data)
            readSemaphore.signal()
        } else if characteristic.uuid == BluetoothTransport.productUUID,
                  let data = characteristic.value {
            productString = String(data: data, encoding: .utf8)
        }
    }
}
