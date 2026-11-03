package onl.coconut.wallet

import android.app.Application
import android.util.Log

class CoconutApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val enabled = AnalyticsComponentGate.savedCollectionEnabled(this)
        try {
            AnalyticsComponentGate.applyBeforeStartup(this, enabled)
        } catch (error: Exception) {
            // Analytics must not make the wallet unavailable. Dart retries and surfaces an unresolved application.
            AnalyticsProcessState.componentGateResult = AnalyticsComponentGateResult(enabled, false)
            Log.e("AnalyticsConsentGate", "Application component gate failed: ${error.javaClass.simpleName}")
        }
        Log.i("AnalyticsConsentGate", "Application component gate checked")
    }
}
