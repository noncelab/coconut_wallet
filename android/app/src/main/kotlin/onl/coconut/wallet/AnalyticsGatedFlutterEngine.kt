package onl.coconut.wallet

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.PluginRegistry
import io.flutter.plugins.firebase.analytics.FlutterFirebaseAnalyticsPlugin

/** 엔진보다 오래 사는 SDK를 새 Dart isolate에서도 확인할 수 있도록 프로세스 안에서만 기록한다. */
internal object AnalyticsProcessState {
    @Volatile
    var measurementTouched = false

    @Volatile
    var componentGateResult: AnalyticsComponentGateResult? = null

    /** 이 프로세스에서 이미 시작된 SDK에만 수집 OFF를 적용한다. 감지 자체는 SDK를 시작하지 않는다. */
    fun disableIfActive(attached: Boolean, defaultAppExists: () -> Boolean, disable: () -> Unit) {
        if (!measurementTouched && !attached && !defaultAppExists()) return
        measurementTouched = true
        disable()
    }

    /** 새 Activity의 수명주기가 기존 SDK에 전달되기 전에 저장된 OFF를 다시 적용한다. 일반 오류는 Dart 재시도에 맡긴다. */
    fun applySavedRefusal(savedEnabled: Boolean, defaultAppExists: () -> Boolean, disable: () -> Unit): Exception? {
        if (savedEnabled) return null
        return try {
            disableIfActive(false, defaultAppExists, disable)
            null
        } catch (error: Exception) {
            error
        }
    }
}

internal class AnalyticsGatedFlutterEngine(context: Context, shellArgs: Array<String>) :
    FlutterEngine(context, shellArgs, false, true) {
    // Java 상위 생성자에서 getter가 호출될 수 있으므로, 초기화 전에는 원래 registry를 돌려준다.
    private var gatedRegistry: AnalyticsGatedPluginRegistry? = null

    init {
        gatedRegistry = AnalyticsGatedPluginRegistry(
            super.getPlugins(),
            { it is FlutterFirebaseAnalyticsPlugin },
            { AnalyticsProcessState.measurementTouched = true },
        )
    }

    override fun getPlugins(): PluginRegistry = gatedRegistry ?: super.getPlugins()

    fun attachAnalytics() {
        if (super.getPlugins().has(FlutterFirebaseAnalyticsPlugin::class.java)) return
        val registry = checkNotNull(gatedRegistry)
        check(registry.hasHeldPlugins()) { "Analytics plugin was not registered" }
        registry.releaseHeld()
    }
}
