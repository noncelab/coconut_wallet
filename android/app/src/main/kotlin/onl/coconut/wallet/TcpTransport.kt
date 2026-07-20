package onl.coconut.wallet

import bridge.Transport
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.net.Socket

class TcpTransport(
    host: String,
    port: Int,
) : Transport {

    private var closed = false
    private val socket = Socket(host, port)
    private val inputStream = BufferedInputStream(socket.getInputStream(), 4096)
    private val outputStream = BufferedOutputStream(socket.getOutputStream(), 4096)

    override fun read(n: Long): ByteArray {
        if (closed) {
            android.util.Log.w("BB02_TCP", "read called on closed transport")
            throw Exception("transport closed")
        }
        return try {
            val buf = ByteArray(n.toInt())
            var offset = 0
            val total = buf.size
            while (offset < total) {
                val got = inputStream.read(buf, offset, total - offset)
                if (got < 0) break
                offset += got
            }
            if (offset == 0) throw Exception("EOF")
            buf
        } catch (e: Exception) {
            android.util.Log.e("BB02_TCP", "read error: ${e.javaClass.name}: ${e.message}", e)
            throw e
        }
    }

    override fun write(p: ByteArray): Long {
        if (closed) {
            android.util.Log.w("BB02_TCP", "write called on closed transport")
            return -1
        }
        return try {
            outputStream.write(p, 0, p.size)
            outputStream.flush()
            p.size.toLong()
        } catch (e: Exception) {
            android.util.Log.e("BB02_TCP", "write error: ${e.javaClass.name}: ${e.message}", e)
            -1
        }
    }

    override fun close() {
        if (closed) return
        closed = true
        try { socket.close() } catch (_: Exception) {}
    }

    fun isConnected(): Boolean = socket.isConnected && !socket.isClosed
}
