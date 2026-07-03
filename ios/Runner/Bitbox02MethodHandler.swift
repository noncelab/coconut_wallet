import Flutter
import Foundation

class Bitbox02MethodHandler: NSObject {
    private var channel: FlutterMethodChannel
    private var bleTransport: BluetoothTransport?
    private var connectivityEventSink: FlutterEventSink?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "bitbox02", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result)
        }

        let eventChannel = FlutterEventChannel(name: "bitbox02/connectivity", binaryMessenger: messenger)
        eventChannel.setStreamHandler(self)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "connect":
            connect(call, result: result)
        case "init":
            initDevice(call, result: result)
        case "rootFingerprint":
            rootFingerprint(call, result: result)
        case "btcXPub":
            btcXPub(call, result: result)
        case "btcAddress":
            btcAddress(call, result: result)
        case "btcSignPSBT":
            btcSignPSBT(call, result: result)
        case "setPrevTxHex":
            setPrevTxHex(call, result: result)
        case "btcSignMessage":
            btcSignMessage(call, result: result)
        case "saveConfig":
            saveConfig(call, result: result)
        case "loadConfig":
            loadConfig(call, result: result)
        case "disconnect":
            disconnect(call, result: result)
        case "setLoggerEnabled":
            setLoggerEnabled(call, result: result)
        case "isConnected":
            result(bleTransport?.isConnected ?? false)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let transport = args["transport"] as? String ?? "ble"
        let config = args["config"] as? String ?? ""

        guard transport == "ble" else {
            result(FlutterError(code: "UNSUPPORTED",
                                message: "USB not supported on iOS", details: nil))
            return
        }

        let bt = BluetoothTransport()
        self.bleTransport = bt

        bt.onDisconnect = { [weak self] in
            DispatchQueue.main.async {
                self?.connectivityEventSink?(false)
            }
        }

        bt.scanAndConnect(timeout: 15) { [weak self] connectResult in
            switch connectResult {
            case .success:
                do {
                    var err: NSError?
                    let deviceId = BitboxbridgeConnect(bt, config, &err)
                    if let err = err {
                        result(FlutterError(code: "CONNECT_FAILED",
                                            message: err.localizedDescription, details: nil))
                        return
                    }
                    result(deviceId)
                }
            case .failure(let error):
                result(FlutterError(code: "BLE_FAILED",
                                    message: error.localizedDescription, details: nil))
            }
        }
    }

    private func initDevice(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        do {
            var err: NSError?
            let status = BitboxbridgeInit(deviceId, &err)
            if let err = err {
                result(FlutterError(code: "INIT_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(status)
        }
    }

    private func rootFingerprint(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        do {
            var err: NSError?
            let fingerprint = BitboxbridgeRootFingerprint(deviceId, &err)
            if let err = err {
                result(FlutterError(code: "ROOT_FINGERPRINT_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(fingerprint)
        }
    }

    private func btcXPub(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let coin = args["coin"] as? Int ?? 0
        let keypath = args["keypath"] as? String ?? ""
        let xpubType = args["xpubType"] as? Int ?? 3
        let display = args["display"] as? Bool ?? false
        do {
            var err: NSError?
            let xpub = BitboxbridgeBtcXPub(deviceId, Int64(coin), keypath, Int64(xpubType), display, &err)
            if let err = err {
                result(FlutterError(code: "BTC_XPUB_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(xpub)
        }
    }

    private func btcAddress(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let coin = args["coin"] as? Int ?? 0
        let keypath = args["keypath"] as? String ?? ""
        let scriptType = args["scriptType"] as? String ?? "p2wpkh"
        let display = args["display"] as? Bool ?? false
        do {
            var err: NSError?
            let address = BitboxbridgeBtcAddress(deviceId, Int64(coin), keypath, scriptType, display, &err)
            if let err = err {
                result(FlutterError(code: "BTC_ADDRESS_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(address)
        }
    }

    private func btcSignPSBT(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let coin = args["coin"] as? Int ?? 0
        guard let psbtData = args["psbtBytes"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARG", message: "psbtBytes required", details: nil))
            return
        }
        let formatUnit = args["formatUnit"] as? Int ?? 0
        do {
            var err: NSError?
            let signed = BitboxbridgeBtcSignPSBT(deviceId, Int64(coin), psbtData.data, Int64(formatUnit), &err)
            if let err = err {
                result(FlutterError(code: "BTC_SIGN_PSBT_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(FlutterStandardTypedData(bytes: signed))
        }
    }

    private func setPrevTxHex(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let inputIndex = args["inputIndex"] as? Int ?? 0
        guard let rawTxHex = args["rawTxHex"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "rawTxHex required", details: nil))
            return
        }
        BitboxbridgeSetPrevTxHex(deviceId, Int64(inputIndex), rawTxHex)
        result(nil)
    }

    private func btcSignMessage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let coin = args["coin"] as? Int ?? 0
        let keypath = args["keypath"] as? String ?? ""
        let scriptType = args["scriptType"] as? String ?? "p2wpkh"
        guard let message = (args["message"] as? FlutterStandardTypedData)?.data else {
            result(FlutterError(code: "INVALID_ARG", message: "message required", details: nil))
            return
        }
        do {
            var err: NSError?
            let sigJson = BitboxbridgeBtcSignMessage(deviceId, Int64(coin), keypath, scriptType, message, &err)
            if let err = err {
                result(FlutterError(code: "BTC_SIGN_MESSAGE_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(sigJson)
        }
    }

    private func saveConfig(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        do {
            var err: NSError?
            let configJson = BitboxbridgeSaveConfig(deviceId, &err)
            if let err = err {
                result(FlutterError(code: "SAVE_CONFIG_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(configJson)
        }
    }

    private func loadConfig(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        let configJson = args["config"] as? String ?? ""
        do {
            var err: NSError?
            BitboxbridgeLoadConfig(deviceId, configJson, &err)
            if let err = err {
                result(FlutterError(code: "LOAD_CONFIG_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            result(nil)
        }
    }

    private func disconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let deviceId = args["id"] as? String else {
            result(FlutterError(code: "INVALID_ARG", message: "id required", details: nil))
            return
        }
        do {
            var err: NSError?
            BitboxbridgeDisconnect(deviceId, &err)
            if let err = err {
                result(FlutterError(code: "DISCONNECT_FAILED", message: err.localizedDescription, details: nil))
                return
            }
            bleTransport?.disconnect()
            bleTransport = nil
            result(nil)
        }
    }

    private func setLoggerEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let enabled = args["enabled"] as? Bool ?? true
        BitboxbridgeSetLoggerEnabled(enabled)
        result(nil)
    }
}

// MARK: - FlutterStreamHandler (bitbox02/connectivity EventChannel)

extension Bitbox02MethodHandler: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        connectivityEventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        connectivityEventSink = nil
        return nil
    }
}
