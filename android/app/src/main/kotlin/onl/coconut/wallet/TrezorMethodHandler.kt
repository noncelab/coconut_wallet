package onl.coconut.wallet

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * TrezorMethodHandler
 * Handles MethodChannel("trezor") calls from Dart.
 * Supports Trezor Safe 7 BLE (THP v2 / Noise XX) on Android via Rust UniFFI.
 *
 * UniFFI library is loaded lazily — if the .so is not yet built the app still
 * compiles; only BLE operations will fail with a clear error message.
 */
private object TrezorBridge {
    private var loaded = false
    fun tryLoad(): Boolean {
        if (loaded) return true
        return try {
            System.loadLibrary("trezor_bridge")
            loaded = true
            true
        } catch (_: UnsatisfiedLinkError) { false }
    }
}

class TrezorMethodHandler(
    private val context: Context,
    private val activity: android.app.Activity,
    flutterEngine: FlutterEngine,
) {
    companion object {
        // Trezor Safe 7 BLE GATT UUIDs — source: trezorlib/transport/ble.py
        val TREZOR_SERVICE_UUID: UUID = UUID.fromString("8c000001-a59b-4d58-a9ad-073df69fa1b1")
        val TREZOR_CHAR_RX: UUID    = UUID.fromString("8c000002-a59b-4d58-a9ad-073df69fa1b1") // host→device
        val TREZOR_CHAR_TX: UUID    = UUID.fromString("8c000003-a59b-4d58-a9ad-073df69fa1b1") // device→host (notify)
        val CLIENT_CHAR_CONFIG: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        private const val SCAN_TIMEOUT_MS = 25_000L

        private var nextHandle: Long = 1L

        const val BLE_PERMISSION_REQUEST_CODE = 1001
    }

    // Wraps a MethodChannel.Result so it can be completed from multiple places
    // (e.g. BLE callbacks + an explicit cancel) without double-result crashes.
    private inner class SafeResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
        private val consumed = AtomicBoolean(false)
        private fun consume(): Boolean = consumed.compareAndSet(false, true)

        override fun success(result: Any?) {
            if (consume()) {
                pendingConnectResult = null
                delegate.success(result)
            }
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            if (consume()) {
                pendingConnectResult = null
                delegate.error(errorCode, errorMessage, errorDetails)
            }
        }

        override fun notImplemented() {
            if (consume()) {
                pendingConnectResult = null
                delegate.notImplemented()
            }
        }
    }

    private val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "trezor")
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val usbManager = TrezorUsbManager(context)

    private var connectivityEventSink: EventChannel.EventSink? = null

    private val bluetoothAdapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    // Active BLE connection state
    private var gatt: BluetoothGatt? = null
    private var rxChar: android.bluetooth.BluetoothGattCharacteristic? = null
    private var txChar: android.bluetooth.BluetoothGattCharacteristic? = null
    private var connectedDeviceId: String? = null

    // Thread-safe BLE read queue (notifications from device)
    private val readQueue = java.util.concurrent.LinkedBlockingQueue<ByteArray>()
    private var pendingPairingFuture: CompletableFuture<String>? = null
    private var pendingPinFuture: CompletableFuture<String>? = null
    private var pendingPassphraseFuture: CompletableFuture<String>? = null
    private var usbConnection: TrezorUsbConnection? = null
    private var pendingUsbConnectResult: MethodChannel.Result? = null

    // Pending write future — completed by onCharacteristicWrite callback
    private var pendingWriteFuture: CompletableFuture<Boolean>? = null

    // Called from gattCallback.onCharacteristicWrite to unblock bleWrite
    fun onCharacteristicWriteResult(success: Boolean) {
        pendingWriteFuture?.complete(success)
    }

    // Blocking read used by Rust callback transport (called from executor thread)
    fun bleRead(timeoutMs: Long = 5000): ByteArray? =
        readQueue.poll(timeoutMs, TimeUnit.MILLISECONDS)

    fun usbRead(): ByteArray? = usbConnection?.read()

    fun usbWrite(data: ByteArray): Boolean = usbConnection?.write(data) == true

    // Write to device via RX characteristic.
    // Blocks until onCharacteristicWrite fires (or 5 s timeout) to prevent concurrent writes.
    @Suppress("DEPRECATION")
    fun bleWrite(data: ByteArray): Boolean {
        val char = rxChar ?: return false
        val g = gatt ?: return false
        val future = CompletableFuture<Boolean>()
        pendingWriteFuture = future
        Log.d("TrezorBLE", "bleWrite: ${data.size} bytes, char.properties=0x${char.properties.toString(16)}, SDK=${Build.VERSION.SDK_INT}")
        val queued = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val rc = g.writeCharacteristic(char, data, BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE)
            Log.d("TrezorBLE", "bleWrite API33: rc=$rc (SUCCESS=${android.bluetooth.BluetoothStatusCodes.SUCCESS})")
            rc == android.bluetooth.BluetoothStatusCodes.SUCCESS
        } else {
            char.value = data
            char.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            val ok = g.writeCharacteristic(char)
            Log.d("TrezorBLE", "bleWrite legacy: ok=$ok")
            ok
        }
        if (!queued) {
            pendingWriteFuture = null
            return false
        }
        return try {
            future.get(5, TimeUnit.SECONDS)
        } catch (_: Exception) {
            pendingWriteFuture = null
            false
        }
    }

    init {
        usbManager.setDetachCallback { device ->
            if (usbConnection?.device?.deviceId != device.deviceId) return@setDetachCallback
            usbConnection?.close()
            usbConnection = null
            val deviceId = activeDeviceId
            activeDeviceId = null
            activeHandle = 0UL
            if (deviceId != null) {
                executor.execute {
                    try {
                        if (TrezorBridge.tryLoad()) uniffi.trezor_bridge.trezorDisconnect(deviceId)
                    } catch (_: Exception) {}
                }
            }
            pendingPinFuture?.takeIf { !it.isDone }?.complete("")
            pendingPassphraseFuture?.takeIf { !it.isDone }?.complete("{\"type\":\"cancel\"}")
            mainHandler.post { connectivityEventSink?.success(false) }
        }
        channel.setMethodCallHandler { call, result ->
            try {
                handleMethod(call, result)
            } catch (e: Exception) {
                result.error("TREZOR_ERROR", e.message ?: "Unknown error", null)
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "trezor/connectivity")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    connectivityEventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    connectivityEventSink = null
                }
            })
    }

    private fun handleMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> connect(call, result)
            "createSession" -> createSession(call, result)
            "getXPub" -> getXPub(call, result)
            "getFingerprint" -> getFingerprint(call, result)
            "signTransaction" -> signTransaction(call, result)
            "setPrevTxHex" -> setPrevTxHex(call, result)
            "clearPrevTxHexes" -> clearPrevTxHexes(call, result)
            "disconnect" -> disconnect(call, result)
            "isConnected" -> {
                val transport = call.argument<String>("transport") ?: "ble"
                result.success(if (transport == "usb") usbConnection?.isOpen() == true else connectedDeviceId != null && gatt != null)
            }
            "cancel" -> cancel(result)
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // UniFFI bridge helpers
    // -------------------------------------------------------------------------
    private fun bridgeNotReady() = UnsupportedOperationException(
        "Trezor Rust bridge not loaded. Build with: make trezor-android"
    )

    private fun credentialFilePath(): String {
        val dir = java.io.File(context.filesDir, "trezor")
        if (!dir.exists()) dir.mkdirs()
        return java.io.File(dir, "thp-credentials.json").absolutePath
    }

    // -------------------------------------------------------------------------
    // connect
    // -------------------------------------------------------------------------
    private fun hasBlePermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
                ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private var activeHandle: ULong = 0UL
    private var activeDeviceId: String? = null

    private var pendingConnectResult: MethodChannel.Result? = null

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != BLE_PERMISSION_REQUEST_CODE) return
        val pending = pendingConnectResult ?: return
        pendingConnectResult = null
        if (grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            connectBle(pending)
        } else {
            pending.error(
                "PERMISSION_DENIED",
                "Bluetooth permission not granted. Please allow Bluetooth access in system settings.",
                null
            )
        }
    }

    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        if (call.argument<String>("transport") == "usb") {
            connectUsb(result)
        } else {
            connectBle(result)
        }
    }

    private fun connectBle(result: MethodChannel.Result) {
        val result = SafeResult(result)
        pendingConnectResult = result

        if (!hasBlePermissions()) {
            val perms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
            } else {
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
            }
            ActivityCompat.requestPermissions(activity, perms, BLE_PERMISSION_REQUEST_CODE)
            return
        }

        if (bluetoothAdapter?.isEnabled != true) {
            result.error("BLE_DISABLED", "Bluetooth is not enabled. Please turn on Bluetooth.", null)
            return
        }

        val scanner = bluetoothAdapter.bluetoothLeScanner
        if (scanner == null) {
            result.error("BLE_UNAVAILABLE", "Bluetooth LE is not available on this device.", null)
            return
        }

        var resolved = false

        val timeoutRunnable = Runnable {
            if (!resolved) {
                resolved = true
                scanner.stopScan(scanCallback)
                mainHandler.post {
                    result.error(
                        "SCAN_TIMEOUT",
                        "Scan timed out. Make sure Trezor Safe 7 is unlocked and nearby.",
                        null
                    )
                }
            }
        }

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, scanResult: ScanResult) {
                val device = scanResult.device
                val name = device.name ?: "(no name)"
                Log.d("TrezorBLE", "Found BLE device: $name  addr=${device.address}  uuids=${scanResult.scanRecord?.serviceUuids}")

                if (scanResult.scanRecord?.serviceUuids?.any { it.uuid == TREZOR_SERVICE_UUID } != true) return

                if (resolved) return
                resolved = true
                mainHandler.removeCallbacks(timeoutRunnable)
                scanner.stopScan(this)

                val deviceId = device.address.replace(":", "").lowercase()
                connectToDevice(device, deviceId, result)
            }

            override fun onScanFailed(errorCode: Int) {
                if (resolved) return
                resolved = true
                mainHandler.removeCallbacks(timeoutRunnable)
                mainHandler.post {
                    result.error("SCAN_FAILED", "BLE scan failed with error code $errorCode.", null)
                }
            }
        }

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        // Filter-less scan: logs all nearby BLE devices so we can confirm Trezor is visible.
        // Once confirmed, narrow back to serviceUuid filter.
        scanner.startScan(null, settings, scanCallback!!)
        mainHandler.postDelayed(timeoutRunnable, SCAN_TIMEOUT_MS)
    }

    private var scanCallback: ScanCallback? = null

    private fun connectUsb(result: MethodChannel.Result) {
        val safeResult = SafeResult(result)
        val device = usbManager.findDevice()
        if (device == null) {
            safeResult.error("NO_DEVICE", "Trezor를 찾을 수 없습니다.", null)
            return
        }
        if (!usbManager.hasPermission(device)) {
            pendingUsbConnectResult = safeResult
            usbManager.requestPermission(device) { permittedDevice, granted ->
                val pending = pendingUsbConnectResult ?: return@requestPermission
                pendingUsbConnectResult = null
                if (!granted) {
                    pending.error("USB_PERMISSION_DENIED", "Trezor USB 접근 권한이 거부되었습니다.", null)
                } else {
                    openUsbAndConnect(permittedDevice, pending)
                }
            }
            return
        }
        openUsbAndConnect(device, safeResult)
    }

    private fun usbCredentialDeviceId(device: android.hardware.usb.UsbDevice): String =
        try {
            device.serialNumber?.takeIf { it.isNotBlank() } ?: device.deviceName
        } catch (_: SecurityException) {
            device.deviceName
        }

    private fun openUsbAndConnect(device: android.hardware.usb.UsbDevice, result: MethodChannel.Result) {
        executor.execute {
            try {
                usbConnection?.close()
                val connection = usbManager.open(device)
                    ?: throw IllegalStateException("USB_OPEN_FAILED")
                usbConnection = connection
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                val handle = (nextHandle++).toULong()
                val callbacks = KotlinUsbCallbacks(this)
                uniffi.trezor_bridge.trezorRegisterUsbCallbacks(handle, callbacks)
                val rustDeviceId = uniffi.trezor_bridge.trezorConnectUsb(
                    handle,
                    usbCredentialDeviceId(device),
                    device.vendorId.toUShort(),
                    device.productId.toUShort(),
                    credentialFilePath(),
                )
                activeHandle = handle
                activeDeviceId = rustDeviceId
                mainHandler.post {
                    connectivityEventSink?.success(true)
                    result.success(rustDeviceId)
                }
            } catch (error: Exception) {
                usbConnection?.close()
                usbConnection = null
                val message = error.message ?: "USB connection failed"
                val code = when {
                    message.contains("UNSUPPORTED_FIRMWARE") -> "UNSUPPORTED_FIRMWARE"
                    message.contains("UNSUPPORTED_DEVICE_STATE") -> "UNSUPPORTED_DEVICE_STATE"
                    message.contains("USB_OPEN_FAILED") -> "USB_OPEN_FAILED"
                    message.contains("timeout", ignoreCase = true) -> "USB_TIMEOUT"
                    message.contains("PIN", ignoreCase = true) -> "PIN_ERROR"
                    message.contains("passphrase", ignoreCase = true) -> "PASSPHRASE_ERROR"
                    message.contains("airing", ignoreCase = true) || message.contains("pairing", ignoreCase = true) -> "PAIRING_FAILED"
                    else -> "CONNECT_FAILED"
                }
                mainHandler.post { result.error(code, message, null) }
            }
        }
    }

    private fun connectToDevice(device: BluetoothDevice, deviceId: String, result: MethodChannel.Result) {
        // Close any stale GATT before starting a new connection
        gatt?.close()
        gatt = null
        rxChar = null
        txChar = null
        connectedDeviceId = null

        var callbackFired = false
        var retryCount = 0
        val maxRetries = 2

        val gattCallback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                Log.d("TrezorBLE", "onConnectionStateChange: status=$status newState=$newState callbackFired=$callbackFired retryCount=$retryCount")
                // Allow post-connection disconnect events to pass through so the
                // connectivity EventSink is notified even after callbackFired is set.
                if (callbackFired) {
                    if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        gatt.close()
                        this@TrezorMethodHandler.gatt = null
                        connectedDeviceId = null
                        mainHandler.post {
                            connectivityEventSink?.success(false)
                        }
                    }
                    return
                }
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        this@TrezorMethodHandler.gatt = gatt
                        connectedDeviceId = deviceId
                        gatt.requestMtu(517)
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        if (status == 133 && retryCount < maxRetries) {
                            retryCount++
                            Log.d("TrezorBLE", "status=133, retrying ($retryCount/$maxRetries)")
                            gatt.close()
                            this@TrezorMethodHandler.gatt = null
                            Thread.sleep(500)
                            device.connectGatt(context, false, this, BluetoothDevice.TRANSPORT_LE)
                            return
                        }
                        if (!callbackFired) {
                            callbackFired = true
                            gatt.close()
                            this@TrezorMethodHandler.gatt = null
                            connectedDeviceId = null
                            mainHandler.post {
                                if (status != BluetoothGatt.GATT_SUCCESS) {
                                    result.error("CONNECT_FAILED", "BLE connection failed (status=$status).", null)
                                } else {
                                    connectivityEventSink?.let { sink ->
                                        mainHandler.post { sink.success(false) }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            override fun onMtuChanged(gatt: BluetoothGatt, mtu: Int, status: Int) {
                Log.d("TrezorBLE", "onMtuChanged: mtu=$mtu status=$status")
                if (callbackFired) return
                gatt.discoverServices()
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                if (callbackFired) return
                if (status != BluetoothGatt.GATT_SUCCESS) {
                    callbackFired = true
                    gatt.disconnect()
                    mainHandler.post {
                        result.error("SERVICE_DISCOVERY_FAILED", "BLE service discovery failed (status=$status).", null)
                    }
                    return
                }
                val service = gatt.getService(TREZOR_SERVICE_UUID)
                if (service == null) {
                    callbackFired = true
                    gatt.disconnect()
                    mainHandler.post { result.error("SERVICE_NOT_FOUND", "Trezor BLE service not found on device.", null) }
                    return
                }
                val rx = service.getCharacteristic(TREZOR_CHAR_RX)
                val tx = service.getCharacteristic(TREZOR_CHAR_TX)
                if (rx == null || tx == null) {
                    callbackFired = true
                    gatt.disconnect()
                    mainHandler.post { result.error("CHAR_NOT_FOUND", "Required BLE characteristics not found.", null) }
                    return
                }
                this@TrezorMethodHandler.rxChar = rx
                this@TrezorMethodHandler.txChar = tx
                // Enable notifications on TX characteristic (device→host)
                gatt.setCharacteristicNotification(tx, true)
                val descriptor = tx.getDescriptor(CLIENT_CHAR_CONFIG)
                if (descriptor != null) {
                    Log.d("TrezorBLE", "onServicesDiscovered: writing CCCD descriptor")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val rc = gatt.writeDescriptor(descriptor, android.bluetooth.BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                        Log.d("TrezorBLE", "writeDescriptor API33: rc=$rc")
                    } else {
                        @Suppress("DEPRECATION")
                        descriptor.value = android.bluetooth.BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        @Suppress("DEPRECATION")
                        gatt.writeDescriptor(descriptor)
                    }
                } else {
                    // No descriptor — hand off to Rust immediately
                    callbackFired = true
                    doRustConnect(deviceId, result)
                }
            }

            override fun onDescriptorWrite(gatt: BluetoothGatt, descriptor: android.bluetooth.BluetoothGattDescriptor, status: Int) {
                Log.d("TrezorBLE", "onDescriptorWrite: status=$status uuid=${descriptor.uuid} callbackFired=$callbackFired")
                if (callbackFired) return
                callbackFired = true
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    doRustConnect(deviceId, result)
                } else {
                    gatt.disconnect()
                    mainHandler.post { result.error("NOTIFY_ENABLE_FAILED", "Failed to enable BLE notifications (status=$status).", null) }
                }
            }

            @Suppress("DEPRECATION")
            override fun onCharacteristicWrite(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, status: Int) {
                Log.d("TrezorBLE", "onCharacteristicWrite: status=$status uuid=${characteristic.uuid}")
                onCharacteristicWriteResult(status == BluetoothGatt.GATT_SUCCESS)
            }

            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
                Log.d("TrezorBLE", "onCharacteristicChanged (legacy): ${characteristic.value?.size} bytes")
                characteristic.value?.let { readQueue.offer(it) }
            }

            @Suppress("DEPRECATION")
            override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                Log.d("TrezorBLE", "onCharacteristicChanged (API33): ${value.size} bytes")
                readQueue.offer(value)
            }
        }

        device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
    }

    // Called on executor thread once BLE notifications are enabled.
    // Mirrors iOS drainThenConnect(delay:2.0): flush stale Trezor packets for 2 s before handshake.
    private fun doRustConnect(deviceId: String, result: MethodChannel.Result) {
        Log.d("TrezorBLE", "doRustConnect: called, submitting to executor")
        executor.execute {
            Log.d("TrezorBLE", "doRustConnect: executor started, draining for 2s")
            val deadline = System.currentTimeMillis() + 2000L
            while (System.currentTimeMillis() < deadline) {
                readQueue.clear()
                Thread.sleep(100)
            }
            readQueue.clear()
            Log.d("TrezorBLE", "doRustConnect: drain complete, starting Rust handshake")
            try {
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                val handle = (nextHandle++).toULong()
                val cbs = KotlinBleCallbacks(this)
                val credPath = credentialFilePath()
                Log.d("TrezorBLE", "doRustConnect: registering callbacks, handle=$handle, credPath=$credPath")
                uniffi.trezor_bridge.trezorRegisterCallbacks(handle, cbs)
                Log.d("TrezorBLE", "doRustConnect: invoking trezorConnect")
                val rustDeviceId = uniffi.trezor_bridge.trezorConnect(handle, deviceId, credPath)
                Log.d("TrezorBLE", "doRustConnect: connected, deviceId=$rustDeviceId")
                activeHandle = handle
                activeDeviceId = rustDeviceId
                mainHandler.post { result.success(rustDeviceId) }
            } catch (e: Exception) {
                val msg = e.message ?: "Unknown error"
                val code = when {
                    msg.contains("Pairing cancelled by user") -> "PAIRING_CANCELLED"
                    msg.contains("Code verification failed") -> "PAIRING_CODE_WRONG"
                    msg.contains("airing") || msg.contains("pairing") -> "PAIRING_FAILED"
                    else -> "CONNECT_FAILED"
                }
                mainHandler.post { result.error(code, msg, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // getXPub
    // -------------------------------------------------------------------------
    private fun getXPub(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val keypath = call.argument<String>("keypath") ?: "m/84'/0'/0'"
        val network = call.argument<String>("network") ?: "mainnet"

        executor.execute {
            try {
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                val json = uniffi.trezor_bridge.trezorGetXpub(deviceId, keypath, network)
                mainHandler.post { result.success(json) }
            } catch (e: Exception) {
                mainHandler.post { result.error("XPUB_FAILED", e.message, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // getFingerprint
    // -------------------------------------------------------------------------
    private fun getFingerprint(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }

        executor.execute {
            try {
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                val fp = uniffi.trezor_bridge.trezorGetFingerprint(deviceId)
                mainHandler.post { result.success(fp) }
            } catch (e: Exception) {
                mainHandler.post { result.error("FINGERPRINT_FAILED", e.message, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // createSession
    // -------------------------------------------------------------------------
    private fun createSession(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val passphraseType = call.argument<String>("passphraseType") ?: "standard"
        val passphraseValue = call.argument<String>("passphraseValue") ?: ""

        executor.execute {
            try {
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                uniffi.trezor_bridge.trezorCreateSession(deviceId, passphraseType, passphraseValue)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("CREATE_SESSION_FAILED", e.message, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // setPrevTxHex
    // -------------------------------------------------------------------------
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

        executor.execute {
            try {
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                uniffi.trezor_bridge.trezorSetPrevTxHex(deviceId, inputIndex.toUInt(), rawTxHex)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("SET_PREV_TX_FAILED", e.message, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // clearPrevTxHexes
    // -------------------------------------------------------------------------
    private fun clearPrevTxHexes(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }

        executor.execute {
            try {
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                uniffi.trezor_bridge.trezorClearPrevTxHexes(deviceId)
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("CLEAR_PREV_TX_FAILED", e.message, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // signTransaction
    // -------------------------------------------------------------------------
    private fun signTransaction(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        val psbtBase64 = call.argument<String>("psbtBase64") ?: run {
            result.error("INVALID_ARG", "psbtBase64 is required", null)
            return
        }
        val network = call.argument<String>("network") ?: "mainnet"

        executor.execute {
            try {
                if (!TrezorBridge.tryLoad()) throw bridgeNotReady()
                val psbtBytes = android.util.Base64.decode(psbtBase64, android.util.Base64.DEFAULT)
                val psbtUBytes = psbtBytes.map { it.toUByte() }
                val signedBytes = uniffi.trezor_bridge.trezorSignTransaction(deviceId, psbtUBytes, network)
                val signedBase64 = android.util.Base64.encodeToString(
                    signedBytes.map { it.toByte() }.toByteArray(),
                    android.util.Base64.NO_WRAP,
                )
                mainHandler.post { result.success(signedBase64) }
            } catch (e: Exception) {
                mainHandler.post { result.error("SIGN_FAILED", e.message, null) }
            }
        }
    }

    // -------------------------------------------------------------------------
    // disconnect
    // -------------------------------------------------------------------------
    private fun disconnect(call: MethodCall, result: MethodChannel.Result) {
        val deviceId = call.argument<String>("id") ?: run {
            result.error("INVALID_ARG", "id is required", null)
            return
        }
        executor.execute {
            try {
                if (TrezorBridge.tryLoad()) {
                    uniffi.trezor_bridge.trezorDisconnect(deviceId)
                }
            } catch (_: Exception) {}
            if (deviceId.startsWith("usb:")) {
                usbConnection?.close()
                usbConnection = null
            } else {
                gatt?.disconnect()
                gatt?.close()
                gatt = null
                connectedDeviceId = null
            }
            activeDeviceId = null
            activeHandle = 0UL
            mainHandler.post { result.success(null) }
        }
    }

    private fun cancel(result: MethodChannel.Result) {
        pendingPairingFuture?.takeIf { !it.isDone }?.complete("")
        pendingPinFuture?.takeIf { !it.isDone }?.complete("")
        pendingPassphraseFuture?.takeIf { !it.isDone }?.complete("{\"type\":\"cancel\"}")
        pendingUsbConnectResult?.error("CANCELLED", "Trezor USB connection was cancelled.", null)
        pendingUsbConnectResult = null
        usbConnection?.close()
        usbConnection = null
        val usbDeviceId = activeDeviceId?.takeIf { it.startsWith("usb:") }
        if (usbDeviceId != null) {
            activeDeviceId = null
            activeHandle = 0UL
            executor.execute {
                try {
                    if (TrezorBridge.tryLoad()) uniffi.trezor_bridge.trezorDisconnect(usbDeviceId)
                } catch (_: Exception) {}
            }
        }
        scanCallback?.let { bluetoothAdapter?.bluetoothLeScanner?.stopScan(it) }
        scanCallback = null
        gatt?.disconnect()
        gatt?.close()
        gatt = null
        rxChar = null
        txChar = null
        connectedDeviceId = null
        pendingConnectResult?.let { safe ->
            pendingConnectResult = null
            safe.error("CANCELLED", "Trezor connection was cancelled.", null)
        }
        activeHandle = 0UL
        activeDeviceId = null
        result.success(null)
    }

    fun requestPairingCode(): String {
        Log.d("TrezorBLE", "requestPairingCode: invoking showPairingCodeDialog on Dart")
        val future = CompletableFuture<String>()
        pendingPairingFuture = future
        mainHandler.post {
            channel.invokeMethod(
                "showPairingCodeDialog",
                null,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        val code = (result as? String) ?: ""
                        Log.d("TrezorBLE", "requestPairingCode: Dart returned code=$code")
                        future.complete(code)
                        pendingPairingFuture = null
                    }
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        Log.d("TrezorBLE", "requestPairingCode: Dart error errorCode=$errorCode errorMessage=$errorMessage")
                        future.complete("")
                        pendingPairingFuture = null
                    }
                    override fun notImplemented() {
                        Log.d("TrezorBLE", "requestPairingCode: showPairingCodeDialog not implemented on Dart")
                        future.complete("")
                        pendingPairingFuture = null
                    }
                }
            )
        }
        return try {
            future.get()
        } catch (_: Exception) {
            ""
        } finally {
            pendingPairingFuture = null
        }
    }

    fun requestPin(): String {
        val future = CompletableFuture<String>()
        pendingPinFuture = future
        mainHandler.post {
            channel.invokeMethod("showPinMatrix", null, completerResult(future, ""))
        }
        return try {
            future.get()
        } catch (_: Exception) {
            ""
        } finally {
            pendingPinFuture = null
        }
    }

    fun requestPassphrase(onDevice: Boolean): String {
        val future = CompletableFuture<String>()
        pendingPassphraseFuture = future
        mainHandler.post {
            channel.invokeMethod(
                "showPassphraseDialog",
                mapOf("onDevice" to onDevice),
                completerResult(future, "{\"type\":\"cancel\"}"),
            )
        }
        return try {
            future.get()
        } catch (_: Exception) {
            "{\"type\":\"cancel\"}"
        } finally {
            pendingPassphraseFuture = null
        }
    }

    private fun completerResult(future: CompletableFuture<String>, fallback: String) =
        object : MethodChannel.Result {
            override fun success(result: Any?) {
                future.complete(result as? String ?: fallback)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                future.complete(fallback)
            }

            override fun notImplemented() {
                future.complete(fallback)
            }
        }

    fun dispose() {
        scanCallback?.let { bluetoothAdapter?.bluetoothLeScanner?.stopScan(it) }
        pendingPairingFuture?.takeIf { !it.isDone }?.complete("")
        pendingPinFuture?.takeIf { !it.isDone }?.complete("")
        pendingPassphraseFuture?.takeIf { !it.isDone }?.complete("{\"type\":\"cancel\"}")
        usbConnection?.close()
        usbConnection = null
        usbManager.dispose()
        gatt?.close()
        gatt = null
        connectivityEventSink = null
        executor.shutdown()
    }
}

/**
 * KotlinBleCallbacks
 * Implements the UniFFI TrezorBleCallbacks interface so Rust can call back
 * into Android BLE for I/O during the THP v2 Noise XX handshake.
 *
 * The interface name matches what uniffi-bindgen generates from trezor.udl.
 * If the .so is not yet built this class is never instantiated.
 */
class KotlinBleCallbacks(
    private val handler: TrezorMethodHandler,
) : uniffi.trezor_bridge.TrezorBleCallbacks {

    override fun write(data: List<UByte>): Boolean {
        val bytes = data.map { it.toByte() }.toByteArray()
        return handler.bleWrite(bytes)
    }

    override fun read(): List<UByte>? {
        val bytes = handler.bleRead() ?: return null
        return bytes.map { it.toUByte() }
    }

    override fun getPin(): String = handler.requestPin()

    override fun getPassphrase(onDevice: Boolean): String = handler.requestPassphrase(onDevice)

    override fun getPairingCode(): String {
        Log.d("TrezorBLE", "KotlinBleCallbacks.getPairingCode: Rust requested pairing code")
        return handler.requestPairingCode()
    }
}

class KotlinUsbCallbacks(
    private val handler: TrezorMethodHandler,
) : uniffi.trezor_bridge.TrezorUsbCallbacks {
    override fun write(data: List<UByte>): Boolean =
        handler.usbWrite(data.map { it.toByte() }.toByteArray())

    override fun read(): List<UByte>? = handler.usbRead()?.map { it.toUByte() }

    override fun getPin(): String = handler.requestPin()

    override fun getPassphrase(onDevice: Boolean): String = handler.requestPassphrase(onDevice)

    override fun getPairingCode(): String = handler.requestPairingCode()
}
