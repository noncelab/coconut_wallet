package onl.coconut.wallet

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import androidx.core.content.ContextCompat

class TrezorUsbManager(private val context: Context) {
    companion object {
        private val SUPPORTED_DEVICE_IDS = setOf(
            0x534c to 0x0001,
            0x1209 to 0x53c1,
        )
        private const val ACTION_USB_PERMISSION = "onl.coconut.wallet.TREZOR_USB_PERMISSION"
    }

    private val usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    private var permissionCallback: ((UsbDevice, Boolean) -> Unit)? = null
    private var detachCallback: ((UsbDevice) -> Unit)? = null

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_USB_PERMISSION) return
            val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE) ?: findDevice()
            if (device == null) return
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false) || hasPermission(device)
            permissionCallback?.invoke(device, granted)
            permissionCallback = null
        }
    }

    private val detachReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != UsbManager.ACTION_USB_DEVICE_DETACHED) return
            val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE) ?: return
            if (isSupportedTrezor(device)) detachCallback?.invoke(device)
        }
    }

    init {
        ContextCompat.registerReceiver(
            context,
            permissionReceiver,
            IntentFilter(ACTION_USB_PERMISSION),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        ContextCompat.registerReceiver(
            context,
            detachReceiver,
            IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    fun findDevice(): UsbDevice? = usbManager.deviceList.values.firstOrNull(::isSupportedTrezor)

    fun hasPermission(device: UsbDevice): Boolean = usbManager.hasPermission(device)

    fun requestPermission(device: UsbDevice, callback: (UsbDevice, Boolean) -> Unit) {
        permissionCallback = callback
        val intent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(ACTION_USB_PERMISSION).setPackage(context.packageName),
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        usbManager.requestPermission(device, intent)
    }

    fun open(device: UsbDevice): TrezorUsbConnection? {
        if (!hasPermission(device)) return null
        val usbInterface = findInterface(device) ?: return null
        val endpoints = findEndpoints(usbInterface) ?: return null
        val connection = usbManager.openDevice(device) ?: return null
        if (!connection.claimInterface(usbInterface, true)) {
            connection.close()
            return null
        }
        return TrezorUsbConnection(device, connection, usbInterface, endpoints.first, endpoints.second)
    }

    fun setDetachCallback(callback: (UsbDevice) -> Unit) {
        detachCallback = callback
    }

    fun dispose() {
        permissionCallback = null
        detachCallback = null
        context.unregisterReceiver(permissionReceiver)
        context.unregisterReceiver(detachReceiver)
    }

    private fun isSupportedTrezor(device: UsbDevice): Boolean =
        device.vendorId to device.productId in SUPPORTED_DEVICE_IDS

    private fun findInterface(device: UsbDevice): UsbInterface? {
        for (index in 0 until device.interfaceCount) {
            val candidate = device.getInterface(index)
            if (candidate.id == 0 && findEndpoints(candidate) != null) return candidate
        }
        return null
    }

    private fun findEndpoints(usbInterface: UsbInterface): Pair<UsbEndpoint, UsbEndpoint>? {
        var endpointIn: UsbEndpoint? = null
        var endpointOut: UsbEndpoint? = null
        for (index in 0 until usbInterface.endpointCount) {
            val endpoint = usbInterface.getEndpoint(index)
            if (endpoint.type != UsbConstants.USB_ENDPOINT_XFER_INT) continue
            when (endpoint.direction) {
                UsbConstants.USB_DIR_IN -> endpointIn = endpoint
                UsbConstants.USB_DIR_OUT -> endpointOut = endpoint
            }
        }
        return if (endpointIn != null && endpointOut != null) Pair(endpointIn, endpointOut) else null
    }
}

class TrezorUsbConnection(
    val device: UsbDevice,
    private val connection: UsbDeviceConnection,
    private val usbInterface: UsbInterface,
    private val endpointIn: UsbEndpoint,
    private val endpointOut: UsbEndpoint,
) {
    private val lock = Any()
    @Volatile private var closed = false

    fun read(timeoutMs: Int = 5000): ByteArray? = synchronized(lock) {
        if (closed) return null
        val buffer = ByteArray(64)
        val count = connection.bulkTransfer(endpointIn, buffer, buffer.size, timeoutMs)
        if (count <= 0) null else buffer.copyOf(count)
    }

    fun write(data: ByteArray, timeoutMs: Int = 5000): Boolean = synchronized(lock) {
        if (closed || data.size != 64) return false
        connection.bulkTransfer(endpointOut, data, data.size, timeoutMs) == data.size
    }

    fun close() = synchronized(lock) {
        if (closed) return
        closed = true
        connection.releaseInterface(usbInterface)
        connection.close()
    }

    fun isOpen(): Boolean = !closed
}
