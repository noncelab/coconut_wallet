package onl.coconut.wallet

import android.content.ComponentName
import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.embedding.engine.plugins.util.GeneratedPluginRegister
import io.flutter.plugins.firebase.analytics.FlutterFirebaseAnalyticsPlugin
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import java.lang.ref.WeakReference

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "onl.coconut.wallet/os"
    private val CHANNEL_EVENT_ICON = "onl.coconut.wallet/app-event-icon"
    private val CHANNEL_OPEN_APP_SETTINGS = "app-settings"
    private val CHANNEL_BITBOX02 = "bitbox02"
    private val CHANNEL_DEVICE_DEK = "onl.coconut.wallet/device-dek"
    private var osChannel: MethodChannel? = null
    private var analyticsChannelGeneration = 0
    private var pendingBitcoinUri: String? = null
    private var bitbox02Handler: Bitbox02MethodHandler? = null
    private var trezorHandler: TrezorMethodHandler? = null
    
    // Activity Alias 이름 (AndroidManifest.xml과 일치해야 함)
    private val EVENT_ICON_ALIAS = "onl.coconut.wallet.MainActivityEventIcon"
    private val MAIN_ACTIVITY = "onl.coconut.wallet.MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        // super.onCreate가 수명주기를 SDK에 넘기기 전이다. SDK 22.5.0은 수집 설정과 수명주기를 한 FIFO 큐로 처리한다.
        AnalyticsProcessState.applySavedRefusal(
            AnalyticsComponentGate.savedCollectionEnabled(this),
            ::defaultFirebaseAppExists,
            ::disableNativeCollection,
        )?.let { Log.e("AnalyticsConsentGate", "Saved refusal not reapplied: ${it.javaClass.simpleName}") }
        super.onCreate(savedInstanceState)
    }

    private fun defaultFirebaseAppExists(): Boolean =
        FirebaseApp.getApps(applicationContext).any { it.name == FirebaseApp.DEFAULT_APP_NAME }

    private fun disableNativeCollection() {
        FirebaseAnalytics.getInstance(applicationContext).setAnalyticsCollectionEnabled(false)
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return if (!AnalyticsComponentGate.savedCollectionEnabled(context)) {
            AnalyticsGatedFlutterEngine(context, FlutterShellArgs.fromIntent(intent).toArray())
        } else {
            null
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (flutterEngine is AnalyticsGatedFlutterEngine) {
            // 제공한 엔진에는 기본 Activity가 자동 등록하지 않는다. 생성된 목록을 필터를 통해 등록한다.
            GeneratedPluginRegister.registerGeneratedPlugins(flutterEngine)
            if (flutterEngine.plugins.has(FlutterFirebaseAnalyticsPlugin::class.java)) {
                // 사후 감지는 이미 일어난 SDK 초기화를 되돌리지 않는다. Flutter 변경 시 실제 no-init 검증이 필요하다.
                Log.e("AnalyticsConsentGate", "Analytics plugin attached before saved consent; recheck Flutter registration")
            }
        } else if (flutterEngine.plugins.has(FlutterFirebaseAnalyticsPlugin::class.java)) {
            AnalyticsProcessState.measurementTouched = true
        }
        osChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        analyticsChannelGeneration++
        pendingBitcoinUri = extractBitcoinUri(intent)

        osChannel?.setMethodCallHandler { call, result ->
            if (call.method == "setAnalyticsComponentsEnabled") {
                val enabled = call.arguments as? Boolean
                if (enabled == null) {
                    result.error("INVALID_ARGUMENT", "Expected a boolean", null)
                } else {
                    val hostReference = WeakReference(this)
                    val channel = osChannel
                    val generation = analyticsChannelGeneration
                    AnalyticsComponentGate.applyAsync(applicationContext, enabled) { error ->
                        Handler(Looper.getMainLooper()).post {
                            val host = hostReference.get()
                            if (host != null && !host.isDestroyed && host.osChannel === channel &&
                                host.analyticsChannelGeneration == generation) {
                                if (error == null) result.success(null)
                                else result.error("ANALYTICS_COMPONENTS_FAILED", error.javaClass.simpleName, null)
                            }
                        }
                    }
                }
            } else if (call.method == "attachAnalytics") {
                try {
                    if (flutterEngine is AnalyticsGatedFlutterEngine) flutterEngine.attachAnalytics()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("ANALYTICS_ATTACH_FAILED", e.javaClass.simpleName, null)
                }
            } else if (call.method == "disableAnalyticsIfActive") {
                try {
                    AnalyticsProcessState.disableIfActive(
                        flutterEngine.plugins.has(FlutterFirebaseAnalyticsPlugin::class.java),
                        ::defaultFirebaseAppExists,
                        ::disableNativeCollection,
                    )
                    result.success(null)
                } catch (e: Exception) {
                    result.error("ANALYTICS_DISABLE_FAILED", e.javaClass.simpleName, null)
                }
            } else if (call.method == "getPlatformVersion") {
                val version = Build.VERSION.RELEASE
                result.success(version)
            } else if(call.method == "getSdkVersion"){
                result.success(Build.VERSION.SDK_INT)
            } else if(call.method == "isDevicePasscodeSet"){
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                result.success(keyguardManager.isDeviceSecure)
            } else if(call.method == "openDeviceSecuritySettings"){
                try {
                    startActivity(Intent(DevicePolicyManager.ACTION_SET_NEW_PASSWORD))
                } catch (_: Exception) {
                    startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                }
                result.success(null)
            } else if(call.method == "getInitialBitcoinUri" || call.method == "getPendingBitcoinUri"){
                result.success(pendingBitcoinUri)
                pendingBitcoinUri = null
            }
            else {
                result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_EVENT_ICON).setMethodCallHandler { call, result ->
            when (call.method) {
                "changeAppEventIcon" -> {
                    val args = call.arguments as? Map<*, *>
                    val appEventIconChange = args?.get("app_event_icon_change") as? Boolean
                    
                    if (appEventIconChange == null) {
                        result.error(
                            "INVALID_ARGUMENT",
                            "app_event_icon_change must be a boolean",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    
                    try {
                        changeAppIcon(appEventIconChange)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error(
                            "ICON_CHANGE_FAILED",
                            e.message ?: "Failed to change app icon",
                            null
                        )
                    }
                }
                "getCurrentIconName" -> {
                    try {
                        val currentIconName = getCurrentIconName()
                        result.success(currentIconName)
                    } catch (e: Exception) {
                        result.error(
                            "GET_ICON_FAILED",
                            e.message ?: "Failed to get current icon name",
                            null
                        )
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        bitbox02Handler = Bitbox02MethodHandler(this, flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_DEVICE_DEK,
        ).setMethodCallHandler(DeviceDekKeystoreHandler())
        trezorHandler = TrezorMethodHandler(this, this, flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_OPEN_APP_SETTINGS).setMethodCallHandler { call, result ->
            if (call.method == "openAppSettings") {
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:" + applicationContext.packageName)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val bitcoinUri = extractBitcoinUri(intent) ?: return
        pendingBitcoinUri = bitcoinUri
        osChannel?.invokeMethod("onBitcoinUri", bitcoinUri)
    }
    
    /**
     * 앱 아이콘 변경
     * @param enableEventIcon true면 이벤트 아이콘 활성화, false면 기본 아이콘으로 복구
     */
    private fun changeAppIcon(enableEventIcon: Boolean) {
        val packageManager = packageManager
        val eventIconComponent = ComponentName(this, EVENT_ICON_ALIAS)
        val mainActivityComponent = ComponentName(this, MAIN_ACTIVITY)
        
        if (enableEventIcon) {
            // 이벤트 아이콘 활성화: MainActivity 비활성화, MainActivityEventIcon 활성화
            packageManager.setComponentEnabledSetting(
                mainActivityComponent,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                eventIconComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        } else {
            // 기본 아이콘으로 복구: MainActivityEventIcon 비활성화, MainActivity 활성화
            packageManager.setComponentEnabledSetting(
                eventIconComponent,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
            packageManager.setComponentEnabledSetting(
                mainActivityComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        }
    }
    
    /**
     * 현재 활성화된 아이콘 이름 반환
     * @return 현재 활성화된 아이콘 이름 (이벤트 아이콘이면 "birthday", 기본이면 null)
     */
    private fun getCurrentIconName(): String? {
        val packageManager = packageManager
        val eventIconComponent = ComponentName(this, EVENT_ICON_ALIAS)
        
        val state = packageManager.getComponentEnabledSetting(eventIconComponent)
        return if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
            "birthday"
        } else {
            null
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        trezorHandler?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        analyticsChannelGeneration++
        osChannel?.setMethodCallHandler(null)
        osChannel = null
        trezorHandler?.dispose()
        trezorHandler = null
        super.onDestroy()
    }

    private fun extractBitcoinUri(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null

        val dataString = intent.dataString ?: return null
        return if (dataString.startsWith("bitcoin:", ignoreCase = true)) {
            dataString
        } else {
            null
        }
    }
}
