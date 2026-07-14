import CoreBluetooth
import Flutter
import Foundation
#if canImport(trezor_bridgeFFI)
import trezor_bridgeFFI
#endif

// MARK: - TrezorMethodHandler
// Handles MethodChannel("trezor") calls from Dart.
// Trezor Safe 7: BLE scan/connect via CoreBluetooth → THP v2 handshake via Rust UniFFI.

class TrezorMethodHandler: NSObject {
    private let channel: FlutterMethodChannel
    private var connectivityEventSink: FlutterEventSink?
    private var bleManager: TrezorBleManager?
    // Maps numeric BLE handle → active manager (used by UniFFI callbacks)
    private static var handleMap: [UInt64: TrezorBleManager] = [:]
    private static var nextHandle: UInt64 = 1

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "trezor", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        FlutterEventChannel(name: "trezor/connectivity", binaryMessenger: messenger)
            .setStreamHandler(self)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            connect(result: result)
        case "getXPub":
            getXPub(call, result: result)
        case "getFingerprint":
            getFingerprint(call, result: result)
        case "disconnect":
            disconnect(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - connect
    private func connect(result: @escaping FlutterResult) {
        let manager = TrezorBleManager()
        self.bleManager = manager

        let handle = TrezorMethodHandler.nextHandle
        TrezorMethodHandler.nextHandle += 1
        TrezorMethodHandler.handleMap[handle] = manager

        manager.onDisconnect = { [weak self] in
            TrezorMethodHandler.handleMap.removeValue(forKey: handle)
            DispatchQueue.main.async { self?.connectivityEventSink?(false) }
        }

        manager.scanAndConnect(timeout: 15) { [weak self] connectResult in
            switch connectResult {
            case .success:
                // BLE GATT connected + characteristics discovered.
                // Flush immediately, then wait for Trezor to finish sending any stale session
                // packets from the previous THP channel before we start a new handshake.
                manager.flushReadQueue()
                // Continuously drain stale packets Trezor sends after BLE connect,
                // then do a final flush right before the THP handshake.
                manager.drainThenConnect(delay: 2.0) {
                    do {
#if canImport(trezor_bridgeFFI)
                        let nativeCbs = SwiftBleCallbacks(manager: manager, channel: self!.channel)
                        trezorRegisterCallbacks(bleHandle: handle, callbacks: nativeCbs)
                        let deviceId = try trezorConnect(bleHandle: handle)
                        TrezorMethodHandler.handleMap.removeValue(forKey: handle)
                        DispatchQueue.main.async { result(deviceId) }
#else
                        // XCFramework not yet linked — return BLE peripheral UUID as stub
                        let deviceId = manager.peripheralUUID ?? "ble-\(handle)"
                        DispatchQueue.main.async { result(deviceId) }
#endif
                    } catch {
                        TrezorMethodHandler.handleMap.removeValue(forKey: handle)
                        DispatchQueue.main.async {
                            let msg = error.localizedDescription
                            let code: String
                            if msg.contains("Pairing cancelled by user") {
                                code = "PAIRING_CANCELLED"
                            } else if msg.contains("Code verification failed") {
                                code = "PAIRING_CODE_WRONG"
                            } else if msg.contains("airing") || msg.contains("pairing") {
                                code = "PAIRING_FAILED"
                            } else {
                                code = "CONNECT_FAILED"
                            }
                            result(FlutterError(code: code, message: msg, details: nil))
                        }
                    }
                }
            case .failure(let error):
                TrezorMethodHandler.handleMap.removeValue(forKey: handle)
                DispatchQueue.main.async {
                    self?.bleManager = nil
                    result(FlutterError(code: "CONNECT_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - getXPub
    private func getXPub(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let keypath = args["keypath"] as? String ?? "m/84'/0'/0'"
        let network = args["network"] as? String ?? "mainnet"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
#if canImport(trezor_bridgeFFI)
                let json = try trezorGetXpub(deviceId: deviceId, keypath: keypath, network: network)
                DispatchQueue.main.async { result(json) }
#else
                throw NSError(domain: "TrezorBridge", code: -99,
                    userInfo: [NSLocalizedDescriptionKey: "TrezorBridgeFFI not linked. Run: make trezor-ios"])
#endif
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "XPUB_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - getFingerprint
    private func getFingerprint(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
#if canImport(trezor_bridgeFFI)
                let fp = try trezorGetFingerprint(deviceId: deviceId)
                DispatchQueue.main.async { result(fp) }
#else
                throw NSError(domain: "TrezorBridge", code: -99,
                    userInfo: [NSLocalizedDescriptionKey: "TrezorBridgeFFI not linked. Run: make trezor-ios"])
#endif
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "FINGERPRINT_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - disconnect
    private func disconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
#if canImport(trezor_bridgeFFI)
            try? trezorDisconnect(deviceId: deviceId)
#endif
            DispatchQueue.main.async { [weak self] in
                self?.bleManager?.disconnect()
                self?.bleManager = nil
                result(nil)
            }
        }
    }
}

// MARK: - FlutterStreamHandler
extension TrezorMethodHandler: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        connectivityEventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        connectivityEventSink = nil
        return nil
    }
}

// MARK: - TrezorBleManager
// Handles CoreBluetooth scanning and connection for Trezor Safe 7.
// Trezor Safe 7 advertises the service UUID defined in THP v2 spec.
// Once connected, the Rust UniFFI bridge takes ownership of the peripheral
// for the Noise XX handshake and subsequent communication.

// MARK: - BLE I/O callback types for Rust FFI
typealias TrezorWriteCallback = (Data) -> Bool
typealias TrezorReadCallback = () -> Data?

fileprivate class TrezorBleManager: NSObject {
    // Trezor Safe 7 BLE GATT UUIDs
    // Source: trezorlib/transport/ble.py
    static let serviceUUID      = CBUUID(string: "8c000001-a59b-4d58-a9ad-073df69fa1b1")
    static let rxCharUUID       = CBUUID(string: "8c000002-a59b-4d58-a9ad-073df69fa1b1") // host→device
    static let txCharUUID       = CBUUID(string: "8c000003-a59b-4d58-a9ad-073df69fa1b1") // device→host (notify)

    var onDisconnect: (() -> Void)?
    var peripheralUUID: String? { peripheral?.identifier.uuidString }

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var rxChar: CBCharacteristic?
    private var txChar: CBCharacteristic?
    private var completion: ((Result<String, Error>) -> Void)?
    private var timeoutTimer: Timer?
    private var deviceId: String?

    // Read queue for incoming BLE notifications (populated by didUpdateValueFor)
    private var readQueue: [Data] = []
    private var readWaiters: [(Data) -> Void] = []
    private let queueLock = NSLock()

    // MARK: - BLE I/O — called by SwiftBleCallbacks (UniFFI callback impl)
    func bleWrite(_ data: Data) -> Bool {
        guard let char = rxChar, let p = peripheral else { return false }
        p.writeValue(data, for: char, type: .withResponse)
        return true
    }

    func bleRead() -> Data? {
        queueLock.lock()
        if !readQueue.isEmpty {
            let data = readQueue.removeFirst()
            queueLock.unlock()
            return data
        }
        var received: Data?
        let sema = DispatchSemaphore(value: 0)
        readWaiters.append { data in received = data; sema.signal() }
        queueLock.unlock()
        _ = sema.wait(timeout: .now() + 5)
        return received
    }

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "trezor.ble.central"))
    }

    func flushReadQueue() {
        queueLock.lock()
        readQueue.removeAll()
        queueLock.unlock()
    }

    /// Continuously discard incoming BLE packets for `delay` seconds, then call `completion`
    /// on a background thread. This ensures no stale THP packets from a previous session
    /// remain in the queue when the Rust handshake begins.
    func drainThenConnect(delay: TimeInterval, completion: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(delay)
        let drainQueue = DispatchQueue(label: "trezor.ble.drain", qos: .userInitiated)
        drainQueue.async { [weak self] in
            while Date() < deadline {
                self?.flushReadQueue()
                Thread.sleep(forTimeInterval: 0.1)
            }
            self?.flushReadQueue()
            completion()
        }
    }

    func scanAndConnect(timeout: TimeInterval, completion: @escaping (Result<String, Error>) -> Void) {
        flushReadQueue()
        self.completion = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            guard let self = self, self.deviceId == nil else { return }
            self.centralManager.stopScan()
            let error = NSError(
                domain: "TrezorBLE",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Scan timed out. Make sure Trezor Safe 7 is unlocked and nearby."]
            )
            self.completion?(.failure(error))
            self.completion = nil
        }

        if centralManager.state == .poweredOn {
            startScan()
        }
        // else: scan starts in centralManagerDidUpdateState once powered on
    }

    func disconnect() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        if let peripheral = peripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        peripheral = nil
        deviceId = nil
    }

    private func startScan() {
        centralManager.scanForPeripherals(
            withServices: [TrezorBleManager.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }
}

extension TrezorBleManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            if completion != nil {
                let error = NSError(
                    domain: "TrezorBLE",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Bluetooth is not available."]
                )
                completion?(.failure(error))
                completion = nil
            }
            return
        }
        startScan()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        central.stopScan()
        self.peripheral = peripheral
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([TrezorBleManager.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let err = error ?? NSError(
            domain: "TrezorBLE",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Trezor Safe 7."]
        )
        completion?(.failure(err))
        completion = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        self.deviceId = nil
        onDisconnect?()
    }
}

// MARK: - CBPeripheralDelegate
extension TrezorBleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == TrezorBleManager.serviceUUID }) else {
            completion?(.failure(error ?? NSError(domain: "TrezorBLE", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Trezor service not found"])))
            completion = nil
            return
        }
        peripheral.discoverCharacteristics([TrezorBleManager.rxCharUUID, TrezorBleManager.txCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            completion?(.failure(error!))
            completion = nil
            return
        }
        for char in service.characteristics ?? [] {
            if char.uuid == TrezorBleManager.rxCharUUID { rxChar = char }
            if char.uuid == TrezorBleManager.txCharUUID {
                txChar = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
        guard rxChar != nil, txChar != nil else {
            completion?(.failure(NSError(domain: "TrezorBLE", code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Required BLE characteristics not found"])))
            completion = nil
            return
        }
        let id = peripheral.identifier.uuidString
        self.deviceId = id
        completion?(.success(id))
        completion = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        queueLock.lock()
        if let waiter = readWaiters.first {
            readWaiters.removeFirst()
            queueLock.unlock()
            waiter(data)
        } else {
            readQueue.append(data)
            queueLock.unlock()
        }
    }
}

// MARK: - SwiftBleCallbacks
// Implements the UniFFI TrezorBleCallbacks protocol so Rust can call back into
// CoreBluetooth for BLE I/O during the THP v2 handshake.
#if canImport(trezor_bridgeFFI)
fileprivate class SwiftBleCallbacks: TrezorBleCallbacks {
    private let manager: TrezorBleManager
    private let channel: FlutterMethodChannel

    fileprivate init(manager: TrezorBleManager, channel: FlutterMethodChannel) {
        self.manager = manager
        self.channel = channel
    }

    func write(data: [UInt8]) -> Bool {
        return manager.bleWrite(Data(data))
    }

    func read() -> [UInt8]? {
        guard let data = manager.bleRead() else { return nil }
        return Array(data)
    }

    func getPairingCode() -> String {
        // Trezor Safe 7 shows a 6-digit code on the device screen.
        // Ask Flutter to show an input dialog and block until the user submits.
        let sema = DispatchSemaphore(value: 0)
        var code = ""
        DispatchQueue.main.async {
            self.channel.invokeMethod("showPairingCodeDialog", arguments: nil) { result in
                if let entered = result as? String, !entered.isEmpty {
                    code = entered
                }
                sema.signal()
            }
        }
        sema.wait()
        // Flush any BLE packets that arrived while the dialog was open.
        // These are stale notifications unrelated to the current handshake step.
        manager.flushReadQueue()
        return code
    }
}
#endif
