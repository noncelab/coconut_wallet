package onl.coconut.wallet

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbManager

class Bitbox02UsbManager(private val context: Context) {

    companion object {
        const val VENDOR_ID = 0x03eb  // 1003
        const val PRODUCT_ID_NOVA = 0x2403  // 9219
        const val ACTION_USB_PERMISSION = "com.android.example.USB_PERMISSION"
    }

    private val usbManager: UsbManager =
        context.getSystemService(Context.USB_SERVICE) as UsbManager

    private var onDeviceConnected: ((UsbDevice) -> Unit)? = null
    private var onDeviceDisconnected: ((UsbDevice) -> Unit)? = null

    private val permissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ACTION_USB_PERMISSION != intent.action) return
            val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
            if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                device?.let { onDeviceConnected?.invoke(it) }
            }
        }
    }

    private val detachReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (UsbManager.ACTION_USB_DEVICE_DETACHED != intent.action) return
            val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
            device?.let { onDeviceDisconnected?.invoke(it) }
        }
    }

    init {
        val permFilter = IntentFilter(ACTION_USB_PERMISSION)
        context.registerReceiver(permissionReceiver, permFilter, Context.RECEIVER_NOT_EXPORTED)

        val detachFilter = IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED)
        context.registerReceiver(detachReceiver, detachFilter, Context.RECEIVER_NOT_EXPORTED)
    }

    fun findDevice(): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull { isBitBox02(it) }
    }

    fun requestPermission(device: UsbDevice) {
        val permissionIntent = PendingIntent.getBroadcast(
            context, 0, Intent(ACTION_USB_PERMISSION),
            PendingIntent.FLAG_IMMUTABLE
        )
        usbManager.requestPermission(device, permissionIntent)
    }

    fun hasPermission(device: UsbDevice): Boolean {
        return usbManager.hasPermission(device)
    }
    fun openDevice(device: UsbDevice): UsbTransport? {
        if (!hasPermission(device)) return null
        val iface = findHidInterface(device)
        if (iface == null) return null
        val endpointPair = findEndpoints(iface)
        if (endpointPair == null) return null
        val epIn = endpointPair.first
        val epOut = endpointPair.second

        // BitBox02 Nova has exactly 1 interface; official app uses getInterface(0)
        val hidIface = device.getInterface(0)

        for (attempt in 1..3) {
            val connection = usbManager.openDevice(device)
            if (connection == null) continue

            var claimed = connection.claimInterface(hidIface, true)
            if (!claimed) {
                connection.close()
                Thread.sleep(500)
                continue
            }

            return UsbTransport(connection, hidIface, epIn, epOut)
        }

        return null
    }

    fun setOnDeviceConnected(callback: (UsbDevice) -> Unit) {
        onDeviceConnected = callback
    }

    fun setOnDeviceDisconnected(callback: (UsbDevice) -> Unit) {
        onDeviceDisconnected = callback
    }

    fun dispose() {
        context.unregisterReceiver(permissionReceiver)
        context.unregisterReceiver(detachReceiver)
    }

    private fun isBitBox02(device: UsbDevice): Boolean {
        return device.vendorId == VENDOR_ID && device.productId == PRODUCT_ID_NOVA
    }

    private fun findHidInterface(device: UsbDevice): android.hardware.usb.UsbInterface? {
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == UsbConstants.USB_CLASS_HID) {
                return iface
            }
        }
        return null
    }

    private fun findEndpoints(iface: android.hardware.usb.UsbInterface): Pair<UsbEndpoint, UsbEndpoint>? {
        var epIn: UsbEndpoint? = null
        var epOut: UsbEndpoint? = null
        for (i in 0 until iface.endpointCount) {
            val ep = iface.getEndpoint(i)
            when (ep.direction) {
                UsbConstants.USB_DIR_IN -> epIn = ep
                UsbConstants.USB_DIR_OUT -> epOut = ep
            }
        }
        if (epIn == null || epOut == null) return null
        return Pair(epIn, epOut)
    }
}
