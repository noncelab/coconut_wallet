package onl.coconut.wallet

import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import bridge.Transport

class UsbTransport(
    private val connection: UsbDeviceConnection,
    private val usbInterface: UsbInterface,
    private val epIn: UsbEndpoint,
    private val epOut: UsbEndpoint,
    private val claimOnClose: Boolean = true,
) : Transport {

    private var closed = false

    override fun read(n: Long): ByteArray {
        if (closed) throw Exception("transport closed")
        val buf = ByteArray(n.toInt())
        val result = connection.bulkTransfer(epIn, buf, buf.size, 5000)
        if (result < 0) throw Exception("USB read failed: $result")
        return if (result == buf.size) buf else buf.copyOf(result)
    }

    override fun write(p: ByteArray): Long {
        if (closed) return -1
        val written = connection.bulkTransfer(epOut, p, p.size, 5000)
        return if (written < 0) -1 else written.toLong()
    }

    override fun close() {
        if (closed) return
        closed = true
        if (claimOnClose) {
            connection.releaseInterface(usbInterface)
        }
        connection.close()
    }
}
