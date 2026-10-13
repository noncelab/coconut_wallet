package onl.coconut.wallet

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flushes flutter_secure_storage 9.x pending writes without reading or logging values. */
class PinAuthStorageHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "flush") {
            result.notImplemented()
            return
        }
        try {
            // flutter_secure_storage uses apply(). A synchronous commit waits for
            // pending apply writes. Run this handler on a background task queue.
            // Persist the wrapped storage key before the encrypted verifier record.
            val keySaved = context.getSharedPreferences("FlutterSecureKeyStorage", Context.MODE_PRIVATE)
                .edit().commit()
            val dataSaved = context.getSharedPreferences("FlutterSecureStorage", Context.MODE_PRIVATE)
                .edit().commit()
            if (keySaved && dataSaved) {
                result.success(true)
            } else {
                result.error("PIN_STORAGE_FLUSH_FAILED", "Authentication storage unavailable", null)
            }
        } catch (_: Exception) {
            result.error("PIN_STORAGE_FLUSH_FAILED", "Authentication storage unavailable", null)
        }
    }
}
