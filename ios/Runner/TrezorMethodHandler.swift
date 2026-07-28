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

    static func credentialFilePath() -> String {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let credDir = dir.appendingPathComponent("trezor", isDirectory: true)
        try? fm.createDirectory(at: credDir, withIntermediateDirectories: true)
        return credDir.appendingPathComponent("thp-credentials.json").path
    }

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
        case "createSession":
            createSession(call, result: result)
        case "applySettings":
            applySettings(call, result: result)
        case "getXPub":
            getXPub(call, result: result)
        case "getFingerprint":
            getFingerprint(call, result: result)
        case "signTransaction":
            signTransaction(call, result: result)
        case "setPrevTxHex":
            setPrevTxHex(call, result: result)
        case "clearPrevTxHexes":
            clearPrevTxHexes(call, result: result)
        case "disconnect":
            disconnect(call, result: result)
        case "isConnected":
            result(bleManager?.isPeripheralConnected ?? false)
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

        print("[TrezorBLE] connect: starting scanAndConnect with 25s timeout")
        manager.scanAndConnect(timeout: 25) { [weak self] connectResult in
            switch connectResult {
            case .success:
                // BLE GATT connected + characteristics discovered.
                print("[TrezorBLE] BLE GATT connected — flushing read queue, then draining for 2s")
                manager.flushReadQueue()
                manager.drainThenConnect(delay: 2.0) {
                    print("[TrezorBLE] Drain complete — starting Rust THP handshake")
                    do {
#if canImport(trezor_bridgeFFI)
                        let nativeCbs = SwiftBleCallbacks(manager: manager, channel: self!.channel)
                        trezorRegisterCallbacks(bleHandle: handle, callbacks: nativeCbs)
                        let deviceUUID = manager.peripheralUUID ?? "ble-\(handle)"
                        let credPath = Self.credentialFilePath()
                        print("[TrezorBLE] Callbacks registered, calling trezorConnect(handle=\(handle), uuid=\(deviceUUID), credPath=\(credPath))")
                        let deviceId = try trezorConnect(bleHandle: handle, deviceUuid: deviceUUID, credentialPath: credPath)
                        print("[TrezorBLE] trezorConnect succeeded: deviceId=\(deviceId)")
                        TrezorMethodHandler.handleMap.removeValue(forKey: handle)
                        DispatchQueue.main.async { result(deviceId) }
#else
                        let deviceId = manager.peripheralUUID ?? "ble-\(handle)"
                        DispatchQueue.main.async { result(deviceId) }
#endif
                    } catch {
                        print("[TrezorBLE] trezorConnect FAILED: \(error.localizedDescription)")
                        TrezorMethodHandler.handleMap.removeValue(forKey: handle)
                        let msg = error.localizedDescription
                        let code: String
                        if msg.contains("Pairing cancelled by user") {
                            code = "PAIRING_CANCELLED"
                        } else if msg.contains("Code verification failed") {
                            code = "PAIRING_CODE_WRONG"
                        } else if msg.contains("airing") || msg.contains("pairing") {
                            code = "PAIRING_FAILED"
                        } else if msg.contains("Decryption error") || msg.contains("aead") {
                            code = "PEER_REMOVED_PAIRING"
                        } else {
                            code = "CONNECT_FAILED"
                        }
                        DispatchQueue.main.async {
                            result(FlutterError(code: code, message: msg, details: nil))
                        }
                    }
                }
            case .failure(let error):
                print("[TrezorBLE] scanAndConnect FAILED: \(error.localizedDescription) [domain=\((error as NSError).domain) code=\((error as NSError).code)]")
                TrezorMethodHandler.handleMap.removeValue(forKey: handle)
                DispatchQueue.main.async {
                    self?.bleManager = nil
                    let nsError = error as NSError
                    let code: String
                    if nsError.domain == "TrezorBLE" && nsError.code == -7 {
                        code = "PEER_REMOVED_PAIRING"
                    } else if nsError.domain == "TrezorBLE" && nsError.code == -8 {
                        code = "PERMISSION_DENIED"
                    } else if nsError.domain == "TrezorBLE" && nsError.code == -2 {
                        code = "BLE_DISABLED"
                    } else {
                        code = "CONNECT_FAILED"
                    }
                    result(FlutterError(code: code, message: error.localizedDescription, details: nil))
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

    // MARK: - createSession
    private func createSession(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let passphraseType = (args["passphraseType"] as? String) ?? "standard"
        let passphraseValue = (args["passphraseValue"] as? String) ?? ""

        DispatchQueue.global(qos: .userInitiated).async {
            do {
#if canImport(trezor_bridgeFFI)
                try trezorCreateSession(deviceId: deviceId, passphraseType: passphraseType, passphraseValue: passphraseValue)
                DispatchQueue.main.async { result(nil) }
#else
                throw NSError(domain: "TrezorBridge", code: -99,
                    userInfo: [NSLocalizedDescriptionKey: "TrezorBridgeFFI not linked"])
#endif
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CREATE_SESSION_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - applySettings
    private func applySettings(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let usePassphrase = args["usePassphrase"] as? Bool

        DispatchQueue.global(qos: .userInitiated).async {
            do {
#if canImport(trezor_bridgeFFI)
                try trezorApplySettings(deviceId: deviceId, usePassphrase: usePassphrase)
                DispatchQueue.main.async { result(nil) }
#else
                throw NSError(domain: "TrezorBridge", code: -99,
                    userInfo: [NSLocalizedDescriptionKey: "TrezorBridgeFFI not linked"])
#endif
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "APPLY_SETTINGS_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - setPrevTxHex
    private func setPrevTxHex(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String,
              let inputIndex = args["inputIndex"] as? Int,
              let rawTxHex = args["rawTxHex"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id, inputIndex, and rawTxHex required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
#if canImport(trezor_bridgeFFI)
                try trezorSetPrevTxHex(deviceId: deviceId, inputIndex: UInt32(inputIndex), rawTxHex: rawTxHex)
                DispatchQueue.main.async { result(nil) }
#else
                throw NSError(domain: "TrezorBridge", code: -99,
                    userInfo: [NSLocalizedDescriptionKey: "TrezorBridgeFFI not linked"])
#endif
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SET_PREV_TX_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - clearPrevTxHexes
    private func clearPrevTxHexes(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
#if canImport(trezor_bridgeFFI)
                try trezorClearPrevTxHexes(deviceId: deviceId)
                DispatchQueue.main.async { result(nil) }
#else
                throw NSError(domain: "TrezorBridge", code: -99,
                    userInfo: [NSLocalizedDescriptionKey: "TrezorBridgeFFI not linked"])
#endif
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CLEAR_PREV_TX_FAILED", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    // MARK: - signTransaction
    private func signTransaction(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String,
              let psbtBase64 = args["psbtBase64"] as? String,
              let psbtData = Data(base64Encoded: psbtBase64) else {
            result(FlutterError(code: "INVALID_ARG", message: "id and psbtBase64 required", details: nil))
            return
        }
        let network = (args["network"] as? String) ?? "mainnet"

        DispatchQueue.global(qos: .userInitiated).async {
            do {
#if canImport(trezor_bridgeFFI)
                let signedBytes = try trezorSignTransaction(
                    deviceId: deviceId,
                    psbtBytes: [UInt8](psbtData),
                    network: network
                )
                let signedBase64 = Data(signedBytes).base64EncodedString()
                DispatchQueue.main.async { result(signedBase64) }
#else
                throw NSError(domain: "TrezorBridge", code: -99,
                    userInfo: [NSLocalizedDescriptionKey: "TrezorBridgeFFI not linked. Run: make trezor-ios"])
#endif
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "SIGN_FAILED", message: error.localizedDescription, details: nil))
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
    var isPeripheralConnected: Bool {
        guard let peripheral = peripheral else { return false }
        return peripheral.state == .connected
    }

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

    // Timeout timer reference so we can cancel it on success/error
    private var scanTimeoutTimer: Timer?

    // Semaphore for BLE write buffer management (.withoutResponse)
    private var writeReadySemaphore: DispatchSemaphore?

    // Pending write completion for .withResponse error detection
    private var pendingWriteResult: ((Bool) -> Void)?

    // MARK: - BLE I/O — called by SwiftBleCallbacks (UniFFI callback impl)
    func bleWrite(_ data: Data) -> Bool {
        guard let char = rxChar, let p = peripheral else {
            print("[TrezorBLE] bleWrite: FAILED — rxChar or peripheral is nil")
            return false
        }
        print("[TrezorBLE] bleWrite: \(data.count) bytes, char.properties=0x\(String(char.properties.rawValue, radix: 16))")
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
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
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
    }

    func disconnect() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
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
        print("[TrezorBLE] centralManagerDidUpdateState: state=\(central.state.rawValue)")
        guard central.state == .poweredOn else {
            if completion != nil {
                let errorCode: Int
                let errorDesc: String
                if central.state == .unauthorized {
                    errorCode = -8
                    errorDesc = "Bluetooth permission denied."
                } else {
                    errorCode = -2
                    errorDesc = "Bluetooth is not available."
                }
                let error = NSError(
                    domain: "TrezorBLE",
                    code: errorCode,
                    userInfo: [NSLocalizedDescriptionKey: errorDesc]
                )
                print("[TrezorBLE] Bluetooth not powered on — state=\(central.state.rawValue) code=\(errorCode)")
                completion?(.failure(error))
                completion = nil
            }
            return
        }
        print("[TrezorBLE] Bluetooth powered on — starting scan")
        startScan()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? "(unknown)"
        print("[TrezorBLE] didDiscover: name=\(name) uuid=\(peripheral.identifier.uuidString) rssi=\(RSSI)")
        central.stopScan()
        self.peripheral = peripheral
        print("[TrezorBLE] Connecting to peripheral...")
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("[TrezorBLE] didConnect: uuid=\(peripheral.identifier.uuidString)")
        peripheral.delegate = self
        print("[TrezorBLE] Discovering services...")
        peripheral.discoverServices([TrezorBleManager.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[TrezorBLE] didFailToConnect: uuid=\(peripheral.identifier.uuidString) error=\(String(describing: error))")
        scanTimeoutTimer?.invalidate()
        if let cbError = error as? CBError,
           #available(iOS 13.4, *), cbError.code == .peerRemovedPairingInformation {
            print("[TrezorBLE] peerRemovedPairingInformation — returning PEER_REMOVED_PAIRING error")
            let err = NSError(
                domain: "TrezorBLE",
                code: -7,
                userInfo: [NSLocalizedDescriptionKey: "Peer removed pairing information"]
            )
            self.peripheral = nil
            completion?(.failure(err))
            completion = nil
            return
        }
        let err = error ?? NSError(
            domain: "TrezorBLE",
            code: -3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to connect to Trezor Safe 7."]
        )
        self.peripheral = nil
        completion?(.failure(err))
        completion = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("[TrezorBLE] didDisconnectPeripheral: uuid=\(peripheral.identifier.uuidString) error=\(String(describing: error)) completion!=nil=\(completion != nil)")
        if completion != nil {
            scanTimeoutTimer?.invalidate()
            if let cbError = error as? CBError,
               #available(iOS 13.4, *), cbError.code == .peerRemovedPairingInformation {
                print("[TrezorBLE] peerRemovedPairingInformation on disconnect — returning error")
                let err = NSError(
                    domain: "TrezorBLE",
                    code: -7,
                    userInfo: [NSLocalizedDescriptionKey: "Peer removed pairing information"]
                )
                self.peripheral = nil
                self.deviceId = nil
                completion?(.failure(err))
                completion = nil
                return
            }
            if let error = error {
                completion?(.failure(error))
            } else {
                completion?(.failure(NSError(
                    domain: "TrezorBLE",
                    code: -6,
                    userInfo: [NSLocalizedDescriptionKey: "Device disconnected during connection setup."]
                )))
            }
            self.peripheral = nil
            self.deviceId = nil
            completion = nil
            return
        }
        // Normal post-connection disconnect
        self.peripheral = nil
        self.deviceId = nil
        onDisconnect?()
    }
}

// MARK: - CBPeripheralDelegate
extension TrezorBleManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("[TrezorBLE] didDiscoverServices ERROR: \(error.localizedDescription)")
            completion?(.failure(error))
            completion = nil
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == TrezorBleManager.serviceUUID }) else {
            print("[TrezorBLE] didDiscoverServices: Trezor service not found. Services: \(peripheral.services?.map { $0.uuid.uuidString } ?? [])")
            completion?(.failure(NSError(domain: "TrezorBLE", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Trezor service not found"])))
            completion = nil
            return
        }
        print("[TrezorBLE] didDiscoverServices: found Trezor service")
        peripheral.discoverCharacteristics([TrezorBleManager.rxCharUUID, TrezorBleManager.txCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("[TrezorBLE] didDiscoverCharacteristics ERROR: \(error.localizedDescription)")
            completion?(.failure(error))
            completion = nil
            return
        }
        var needsNotifyConfirmation = false
        for char in service.characteristics ?? [] {
            print("[TrezorBLE] Found char: uuid=\(char.uuid.uuidString) properties=0x\(String(char.properties.rawValue, radix: 16))")
            if char.uuid == TrezorBleManager.rxCharUUID {
                rxChar = char
                print("[TrezorBLE] RX char found (host to device)")
            }
            if char.uuid == TrezorBleManager.txCharUUID {
                txChar = char
                print("[TrezorBLE] TX char found (device to host) — enabling notifications")
                peripheral.setNotifyValue(true, for: char)
                needsNotifyConfirmation = true
            }
        }
        guard rxChar != nil, txChar != nil else {
            print("[TrezorBLE] Missing required characteristics. rxChar=\(rxChar != nil) txChar=\(txChar != nil)")
            completion?(.failure(NSError(domain: "TrezorBLE", code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Required BLE characteristics not found"])))
            completion = nil
            return
        }
        let id = peripheral.identifier.uuidString
        self.deviceId = id
        if !needsNotifyConfirmation {
            print("[TrezorBLE] No notify confirmation needed — completing with deviceId=\(id)")
            completion?(.success(id))
            completion = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[TrezorBLE] didUpdateNotificationStateFor ERROR: \(error.localizedDescription)")
            completion?(.failure(error))
            completion = nil
            return
        }
        print("[TrezorBLE] didUpdateNotificationStateFor: notifications enabled for \(characteristic.uuid.uuidString)")
        if let id = deviceId {
            print("[TrezorBLE] BLE setup complete — deviceId=\(id)")
            completion?(.success(id))
            completion = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[TrezorBLE] didWriteValueFor ERROR: \(error.localizedDescription)")
        } else {
            print("[TrezorBLE] didWriteValueFor OK: \(characteristic.uuid.uuidString)")
        }
        pendingWriteResult?(error == nil)
        pendingWriteResult = nil
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        queueLock.lock()
        writeReadySemaphore?.signal()
        writeReadySemaphore = nil
        queueLock.unlock()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("[TrezorBLE] didUpdateValueFor ERROR: \(error.localizedDescription)")
            return
        }
        guard let data = characteristic.value else { return }
        print("[TrezorBLE] didUpdateValueFor: \(data.count) bytes")
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

    func getPin() -> String {
        return requestFlutterString(method: "showPinMatrix", arguments: nil)
    }

    func getPassphrase(onDevice: Bool) -> String {
        return requestFlutterString(
            method: "showPassphraseDialog",
            arguments: ["onDevice": onDevice],
            fallback: "{\"type\":\"cancel\"}"
        )
    }

    func getPairingCode() -> String {
        // Trezor Safe 7 shows a 6-digit code on the device screen.
        // Ask Flutter to show an input dialog and block until the user submits.
        let code = requestFlutterString(method: "showPairingCodeDialog", arguments: nil)
        // Flush any BLE packets that arrived while the dialog was open.
        // These are stale notifications unrelated to the current handshake step.
        manager.flushReadQueue()
        return code
    }

    private func requestFlutterString(method: String, arguments: Any?, fallback: String = "") -> String {
        let sema = DispatchSemaphore(value: 0)
        var value = fallback
        DispatchQueue.main.async {
            self.channel.invokeMethod(method, arguments: arguments) { result in
                if let result = result as? String {
                    value = result
                }
                sema.signal()
            }
        }
        sema.wait()
        return value
    }
}
#endif
