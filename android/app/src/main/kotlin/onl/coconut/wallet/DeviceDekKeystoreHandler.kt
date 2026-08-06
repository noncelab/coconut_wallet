package onl.coconut.wallet

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.spec.MGF1ParameterSpec
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

class DeviceDekKeystoreHandler : MethodChannel.MethodCallHandler {
    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "RSA/ECB/OAEPWithSHA-256AndMGF1Padding"
    }

    private val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    private val executor = Executors.newSingleThreadExecutor()
    private val oaepSpec = OAEPParameterSpec(
        "SHA-256",
        "MGF1",
        MGF1ParameterSpec.SHA1,
        PSource.PSpecified.DEFAULT,
    )

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val alias = call.argument<String>("alias")
        if (alias.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "alias is required", null)
            return
        }

        when (call.method) {
            "wrap" -> executor.execute {
                wrap(alias, call.argument<ByteArray>("plaintext"), result)
            }
            "unwrap" -> executor.execute {
                unwrap(alias, call.argument<ByteArray>("ciphertext"), result)
            }
            "delete" -> executor.execute { delete(alias, result) }
            else -> result.notImplemented()
        }
    }

    private fun delete(alias: String, result: MethodChannel.Result) {
        try {
            keyStore.deleteEntry(alias)
            result.success(null)
        } catch (error: Exception) {
            result.error("KEYSTORE_FAILED", error.message, null)
        }
    }

    private fun wrap(
        alias: String,
        plaintext: ByteArray?,
        result: MethodChannel.Result,
    ) {
        if (plaintext == null) {
            result.error("INVALID_ARGUMENT", "plaintext is required", null)
            return
        }
        try {
            val protection = ensureHardwareBackedKey(alias)
            val publicKey = keyStore.getCertificate(alias).publicKey
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, publicKey, oaepSpec)
            result.success(
                mapOf(
                    "ciphertext" to cipher.doFinal(plaintext),
                    "protection" to protection,
                ),
            )
        } catch (error: HardwareUnavailableException) {
            result.error("HARDWARE_UNAVAILABLE", error.message, null)
        } catch (error: Exception) {
            result.error("KEYSTORE_FAILED", error.message, null)
        }
    }

    private fun unwrap(
        alias: String,
        ciphertext: ByteArray?,
        result: MethodChannel.Result,
    ) {
        if (ciphertext == null) {
            result.error("INVALID_ARGUMENT", "ciphertext is required", null)
            return
        }
        try {
            val privateKey = keyStore.getKey(alias, null)
                ?: throw IllegalStateException("Device key not found")
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, privateKey, oaepSpec)
            result.success(cipher.doFinal(ciphertext))
        } catch (error: Exception) {
            result.error("UNWRAP_FAILED", error.message, null)
        }
    }

    private fun ensureHardwareBackedKey(alias: String): String {
        if (keyStore.containsAlias(alias)) {
            return hardwareProtection(alias)
                ?: throw HardwareUnavailableException("Existing key is not hardware-backed")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P &&
            hasStrongBox()
        ) {
            try {
                generateKey(alias, strongBox = true)
                val protection = hardwareProtection(alias)
                if (protection != null) return "androidStrongBox"
                keyStore.deleteEntry(alias)
            } catch (_: StrongBoxUnavailableException) {
                keyStore.deleteEntry(alias)
            } catch (_: Exception) {
                keyStore.deleteEntry(alias)
            }
        }

        try {
            generateKey(alias, strongBox = false)
            val protection = hardwareProtection(alias)
            if (protection == "androidTee" ||
                protection == "androidStrongBox"
            ) {
                return protection
            }
            keyStore.deleteEntry(alias)
            throw HardwareUnavailableException(
                "Android Keystore key is software-backed",
            )
        } catch (error: HardwareUnavailableException) {
            throw error
        } catch (error: Exception) {
            keyStore.deleteEntry(alias)
            throw HardwareUnavailableException(
                "Hardware-backed Android Keystore is unavailable",
                error,
            )
        }
    }

    private fun generateKey(alias: String, strongBox: Boolean) {
        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(2048)
            .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA1)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setUserAuthenticationRequired(false)

        if (strongBox && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            builder.setIsStrongBoxBacked(true)
        }

        KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_RSA,
            ANDROID_KEYSTORE,
        ).apply {
            initialize(builder.build())
            generateKeyPair()
        }
    }

    @Suppress("DEPRECATION")
    private fun hardwareProtection(alias: String): String? {
        val privateKey = keyStore.getKey(alias, null) as? PrivateKey ?: return null
        val keyFactory = KeyFactory.getInstance(privateKey.algorithm, ANDROID_KEYSTORE)
        val keyInfo = keyFactory.getKeySpec(privateKey, KeyInfo::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return when (keyInfo.securityLevel) {
                KeyProperties.SECURITY_LEVEL_STRONGBOX -> "androidStrongBox"
                KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> "androidTee"
                else -> null
            }
        }
        return if (keyInfo.isInsideSecureHardware) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && hasStrongBox()) {
                // API 28~30은 TEE와 StrongBox를 안정적으로 구분할 API가 없다.
                // StrongBox 요청 경로에서만 StrongBox로 확정하며, 일반 생성 키는
                // 보수적으로 TEE로 기록한다.
                "androidTee"
            } else {
                "androidTee"
            }
        } else {
            null
        }
    }

    private fun hasStrongBox(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.P

    private class HardwareUnavailableException(
        message: String,
        cause: Throwable? = null,
    ) : Exception(message, cause)
}
