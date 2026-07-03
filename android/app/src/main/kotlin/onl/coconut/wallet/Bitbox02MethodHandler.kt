package onl.coconut.wallet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import bridge.Bridge
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class Bitbox02MethodHandler(
    private val context: Context,
    flutterEngine: FlutterEngine,
) {
    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bitbox02")
    private var usbManager: Bitbox02UsbManager? = null
    private val connectedDevices = mutableSetOf<String>()
    private val tcpTransports = mutableMapOf<String, TcpTransport>()
    private val executor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var connectivityEventSink: EventChannel.EventSink? = null
    private var connectivityDetachReceiver: BroadcastReceiver? = null

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                handleMethod(call, result)
            } catch (e: Exception) {
                result.error("BITBOX02_ERROR", e.message ?: "Unknown error", null)
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "bitbox02/connectivity")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    connectivityEventSink = sink
                    val receiver = object : BroadcastReceiver() {
                        override fun onReceive(ctx: Context, intent: Intent) {
                            if (UsbManager.ACTION_USB_DEVICE_DETACHED != intent.action) return
                            val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                            if (device?.vendorId == Bitbox02UsbManager.VENDOR_ID &&
                                device?.productId == Bitbox02UsbManager.PRODUCT_ID_NOVA
                            ) {
                                mainHandler.post { sink.success(false) }
                            }
                        }
                    }
                    val filter = IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED)
                    context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
                    connectivityDetachReceiver = receiver
                }

                override fun onCancel(arguments: Any?) {
                    connectivityDetachReceiver?.let { context.unregisterReceiver(it) }
                    connectivityDetachReceiver = null
                    connectivityEventSink = null
                }
            })
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> connect(call, result)
            "init" -> init(call, result)
            "rootFingerprint" -> rootFingerprint(call, result)
            "restoreFromMnemonic" -> restoreFromMnemonic(call, result)
            "setPassword" -> setPassword(call, result)
            "channelHashVerify" -> channelHashVerify(call, result)
            "deviceInitialized" -> deviceInitialized(call, result)
            "btcXPub" -> btcXPub(call, result)
            "btcAddress" -> btcAddress(call, result)
            "btcSignPSBT" -> btcSignPSBT(call, result)
            "setPrevTxHex" -> setPrevTxHex(call, result)
            "btcSignMessage" -> btcSignMessage(call, result)
            "saveConfig" -> saveConfig(call, result)
            "loadConfig" -> loadConfig(call, result)
            "disconnect" -> disconnect(call, result)
            "setLoggerEnabled" -> setLoggerEnabled(call, result)
            "isConnected" -> isConnected(result)
            else -> result.notImplemented()
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val transportType = call.argument<String>("transport") ?: "usb"
        android.util.Log.d("BB02", "connect called, transport=$transportType")

        if (transportType == "tcp") {
            val host = call.argument<String>("host") ?: "10.0.2.2"
            val port = call.argument<Int>("port") ?: 15423
            val product = call.argument<String>("product") ?: "multi"
            val version = call.argument<String>("version") ?: "9.26.1"
            android.util.Log.d("BB02", "connecting TCP: $host:$port product=$product version=$version")
            executor.execute {
                try {
                    val transport = TcpTransport(host, port)
                    android.util.Log.d("BB02_TCP", "socket connected, isConnected=${transport.isConnected()}")
                    val deviceId = Bridge.connectWithInfo(transport, product, version)
                    synchronized(this) { tcpTransports[deviceId] = transport }
                    connectedDevices.add(deviceId)
                    android.util.Log.d("BB02", "TCP connect success, deviceId=$deviceId")
                    mainHandler.post { result.success(deviceId) }
                } catch (e: Exception) {
                    android.util.Log.e("BB02", "TCP connect failed: ${e.message}", e)
                    mainHandler.post { result.error("CONNECT_FAILED", e.message, null) }
                }
            }
            return
        }

        if (transportType != "usb") {
            result.error("UNSUPPORTED", "Transport not supported: $transportType", null)
            return
        }
        val mgr = Bitbox02UsbManager(context)
        usbManager = mgr
        val device = mgr.findDevice()
        android.util.Log.d("BB02", "device found: $device, name=${device?.productName}")
        if (device == null) {
            result.error("NO_DEVICE", "BitBox02 Nova not found. Connect via USB.", null)
            return
        }
        if (mgr.hasPermission(device)) {
            android.util.Log.d("BB02", "has permission, opening device")
            openAndConnect(mgr, device, result)
        } else {
            android.util.Log.d("BB02", "no permission, requesting...")
            mgr.setOnDeviceConnected { dev -> openAndConnect(mgr, dev, result) }
            mgr.requestPermission(device)
        }
    }

    private fun openAndConnect(
        mgr: Bitbox02UsbManager,
        device: android.hardware.usb.UsbDevice,
        result: MethodChannel.Result,
    ) {
        android.util.Log.d("BB02", "openAndConnect called for device: ${device.productName}")
        val transport = mgr.openDevice(device)
        if (transport == null) {
            android.util.Log.e("BB02", "openDevice returned null")
            result.error("OPEN_FAILED", "Failed to open USB device", null)
            return
        }
        android.util.Log.d("BB02", "USB device opened, calling Bridge.connect")
        try {
            val deviceId = Bridge.connect(transport)
            connectedDevices.add(deviceId)
            android.util.Log.d("BB02", "Bridge.connect success, deviceId=$deviceId")
            result.success(deviceId)
        } catch (e: Exception) {
            android.util.Log.e("BB02", "Bridge.connect failed: ${e.message}", e)
            transport.close()
            result.error("CONNECT_FAILED", e.message, null)
        }
    }

    private fun init(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        android.util.Log.d("BB02", "init called, deviceId=$deviceId")
        runOnExecutor(result) {
            android.util.Log.d("BB02", "init: calling Bridge.init($deviceId)...")
            val status = Bridge.init(deviceId)
            android.util.Log.d("BB02", "init: success, status=$status")
            status
        }
    }

    private fun rootFingerprint(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        runOnExecutor(result) { Bridge.rootFingerprint(deviceId) }
    }

    private fun restoreFromMnemonic(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        executor.execute {
            try {
                Bridge.restoreFromMnemonic(deviceId)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("RESTORE_FAILED", e.message, null) }
            }
        }
    }

    private fun setPassword(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val seedLen = (call.argument<Int>("seedLen") ?: 32).toLong()
        executor.execute {
            try {
                Bridge.setPassword(deviceId, seedLen)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("SET_PASSWORD_FAILED", e.message, null) }
            }
        }
    }

    private fun channelHashVerify(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val ok = call.argument<Boolean>("ok") ?: true
        executor.execute {
            try {
                Bridge.channelHashVerify(deviceId, ok)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("CHANNEL_HASH_VERIFY_FAILED", e.message, null) }
            }
        }
    }

    private fun deviceInitialized(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        runOnExecutor(result) { Bridge.deviceInitialized(deviceId) }
    }

    private fun btcXPub(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val coin = (call.argument<Int>("coin") ?: 0).toLong()
        val keypath = call.argument<String>("keypath") ?: "m/84'/0'/0'/0/0"
        val xpubType = (call.argument<Int>("xpubType") ?: 3).toLong()
        val display = call.argument<Boolean>("display") ?: false
        runOnExecutor(result) { Bridge.btcxPub(deviceId, coin, keypath, xpubType, display) }
    }

    private fun btcAddress(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val coin = (call.argument<Int>("coin") ?: 0).toLong()
        val keypath = call.argument<String>("keypath") ?: "m/84'/0'/0'/0/0"
        val scriptType = call.argument<String>("scriptType") ?: "p2wpkh"
        val display = call.argument<Boolean>("display") ?: false
        runOnExecutor(result) { Bridge.btcAddress(deviceId, coin, keypath, scriptType, display) }
    }

    private fun btcSignPSBT(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val coin = (call.argument<Int>("coin") ?: 0).toLong()
        val psbtBytes = call.argument<ByteArray>("psbtBytes") ?: run {
            result.error("INVALID_ARG", "psbtBytes is required", null)
            return
        }
        val formatUnit = (call.argument<Int>("formatUnit") ?: 0).toLong()
        executor.execute {
            try {
                val signed = Bridge.btcSignPSBT(deviceId, coin, psbtBytes, formatUnit)
                mainHandler.post { result.success(signed) }
            } catch (e: Exception) {
                mainHandler.post { result.error("BTC_SIGN_PSBT_FAILED", e.message, null) }
            }
        }
    }

    private fun setPrevTxHex(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val inputIndex = call.argument<Int>("inputIndex") ?: run {
            result.error("INVALID_ARG", "inputIndex is required", null)
            return
        }
        val rawTxHex = call.argument<String>("rawTxHex") ?: run {
            result.error("INVALID_ARG", "rawTxHex is required", null)
            return
        }
        Bridge.setPrevTxHex(deviceId, inputIndex.toLong(), rawTxHex)
        result.success(null)
    }

    private fun btcSignMessage(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val coin = (call.argument<Int>("coin") ?: 0).toLong()
        val keypath = call.argument<String>("keypath") ?: "m/84'/0'/0'/0/0"
        val scriptType = call.argument<String>("scriptType") ?: "p2wpkh"
        val message = call.argument<ByteArray>("message") ?: run {
            result.error("INVALID_ARG", "message is required", null)
            return
        }
        executor.execute {
            try {
                val sigJson = Bridge.btcSignMessage(deviceId, coin, keypath, scriptType, message)
                mainHandler.post { result.success(sigJson) }
            } catch (e: Exception) {
                mainHandler.post { result.error("BTC_SIGN_MESSAGE_FAILED", e.message, null) }
            }
        }
    }

    private fun saveConfig(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        runOnExecutor(result) { Bridge.saveConfig(deviceId) }
    }

    private fun loadConfig(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val configJson = call.argument<String>("config") ?: ""
        executor.execute {
            try {
                Bridge.loadConfig(deviceId, configJson)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("LOAD_CONFIG_FAILED", e.message, null) }
            }
        }
    }

    private fun disconnect(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        executor.execute {
            try {
                Bridge.disconnect(deviceId)
                connectedDevices.remove(deviceId)
                synchronized(this) { tcpTransports.remove(deviceId)?.close() }
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("DISCONNECT_FAILED", e.message, null) }
            }
        }
    }

    // Helper: run a block on the executor and post success/error back to main thread
    private fun <T> runOnExecutor(result: MethodChannel.Result, block: () -> T) {
        executor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post { result.error("BB02_ERROR", e.message, null) }
            }
        }
    }

    private fun setLoggerEnabled(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        Bridge.setLoggerEnabled(enabled)
        result.success(null)
    }

    private fun isConnected(result: MethodChannel.Result) {
        val usbMgr = context.getSystemService(Context.USB_SERVICE) as UsbManager
        val found = usbMgr.deviceList.values.any { device ->
            device.vendorId == Bitbox02UsbManager.VENDOR_ID &&
                device.productId == Bitbox02UsbManager.PRODUCT_ID_NOVA
        }
        result.success(found)
    }

    fun dispose() {
        connectivityDetachReceiver?.let { context.unregisterReceiver(it) }
        connectivityDetachReceiver = null
        connectivityEventSink = null
        usbManager?.dispose()
        synchronized(this) {
            tcpTransports.values.forEach { it.close() }
            tcpTransports.clear()
        }
        connectedDevices.clear()
        executor.shutdown()
    }
}
