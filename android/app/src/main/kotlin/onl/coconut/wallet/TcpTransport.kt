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
            throw Exception("transport closed")
        }
        val buf = ByteArray(n.toInt())
        var offset = 0
        val total = buf.size
        while (offset < total) {
            val got = inputStream.read(buf, offset, total - offset)
            if (got < 0) break
            offset += got
        }
        if (offset == 0) throw Exception("EOF")
        return buf
    }

    override fun write(p: ByteArray): Long {
        if (closed) {
            return -1
        }
        return try {
            outputStream.write(p, 0, p.size)
            outputStream.flush()
            p.size.toLong()
        } catch (e: Exception) {
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
