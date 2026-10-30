package onl.coconut.wallet

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

internal data class AnalyticsComponentGateResult(val enabled: Boolean, val applied: Boolean)

/** SDK manifest defaults stay enabled; only the app's runtime component overrides follow its saved choice. */
internal object AnalyticsComponentGate {
    private val executor = Executors.newSingleThreadExecutor()
    private val components = listOf(
        "com.google.android.gms.measurement.AppMeasurementReceiver",
        "com.google.android.gms.measurement.AppMeasurementService",
        "com.google.android.gms.measurement.AppMeasurementJobService",
    )

    fun savedCollectionEnabled(context: Context): Boolean {
        val preferences = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return preferences.all["flutter.ANALYTICS_COLLECTION_ENABLED"] as? Boolean != false
    }

    // Application waits before any Activity/service starts. PM disk work still belongs to the same worker.
    fun applyBeforeStartup(context: Context, enabled: Boolean) {
        val application = context.applicationContext
        try {
            executor.submit<Unit> { applyNow(application, enabled) }.get()
        } catch (error: ExecutionException) {
            val cause = error.cause
            if (cause is Error) throw cause
            throw (cause as? Exception ?: error)
        } catch (error: InterruptedException) {
            Thread.currentThread().interrupt()
            throw error
        }
    }

    fun applyAsync(context: Context, enabled: Boolean, complete: (Exception?) -> Unit) {
        val application = context.applicationContext
        executor.execute {
            val failure = try {
                applyNow(application, enabled)
                null
            } catch (error: Exception) {
                error
            }
            complete(failure)
        }
    }

    private fun applyNow(context: Context, enabled: Boolean) {
        AnalyticsProcessState.componentGateResult = AnalyticsComponentGateResult(enabled, false)
        val manager = context.packageManager
        val target = if (enabled) PackageManager.COMPONENT_ENABLED_STATE_DEFAULT
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        var flags = PackageManager.DONT_KILL_APP
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) flags = flags or PackageManager.SYNCHRONOUS
        for (name in components) {
            val component = ComponentName(context.packageName, name)
            if (manager.getComponentEnabledSetting(component) != target) {
                manager.setComponentEnabledSetting(component, target, flags)
            }
        }
        AnalyticsProcessState.componentGateResult = AnalyticsComponentGateResult(enabled, true)
    }
}
