package onl.coconut.wallet

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.provider.Settings

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "onl.coconut.wallet/os"
    private val CHANNEL_EVENT_ICON = "onl.coconut.wallet/app-event-icon"
    private val CHANNEL_OPEN_APP_SETTINGS = "app-settings"
    
    // Activity Alias 이름 (AndroidManifest.xml과 일치해야 함)
    private val EVENT_ICON_ALIAS = "onl.coconut.wallet.MainActivityEventIcon"
    private val MAIN_ACTIVITY = "onl.coconut.wallet.MainActivity"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getPlatformVersion") {
                val version = Build.VERSION.RELEASE
                result.success(version)
            } else if(call.method == "getSdkVersion"){
                result.success(Build.VERSION.SDK_INT)
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
}

