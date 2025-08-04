package onl.coconut.wallet

import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "onl.coconut.wallet/os"
    private val ORBOT_CHECK_CHANNEL = "orbot_check"
    private val ORBOT_LAUNCHER_CHANNEL = "orbot_launcher"

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

        // Orbot 설치 확인 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ORBOT_CHECK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isOrbotInstalled" -> {
                    try {
                        packageManager.getPackageInfo("org.torproject.android", PackageManager.GET_ACTIVITIES)
                        result.success(true)
                    } catch (e: PackageManager.NameNotFoundException) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Orbot 앱 실행 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ORBOT_LAUNCHER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "launchOrbot" -> {
                    try {
                        val launchIntent = packageManager.getLaunchIntentForPackage("org.torproject.android")
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                            result.success(true)
                        } else {
                            // Orbot이 설치되지 않은 경우 Play Store로 이동
                            val playStoreIntent = Intent(Intent.ACTION_VIEW).apply {
                                data = Uri.parse("https://play.google.com/store/apps/details?id=org.torproject.android")
                                setPackage("com.android.vending")
                            }
                            startActivity(playStoreIntent)
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("LAUNCH_ERROR", "Failed to launch Orbot: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()   
            }
        }
    }
}
