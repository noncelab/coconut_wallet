package onl.coconut.wallet

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class AnalyticsProcessStateTest {
    private class FatalError : Error()

    private var appProbes = 0
    private var disables = 0
    private var defaultAppExists = false
    private var failure: Throwable? = null
    private val probeDefaultApp = {
        appProbes++
        defaultAppExists
    }
    private val disable = {
        disables++
        failure?.let { throw it }
        Unit
    }

    @Before
    @After
    fun resetProcess() {
        AnalyticsProcessState.measurementTouched = false
    }

    @Test
    fun coldSavedRefusalWithoutSdkStartsNothing() {
        assertNull(AnalyticsProcessState.applySavedRefusal(false, probeDefaultApp, disable))

        assertEquals(1, appProbes)
        assertEquals(0, disables)
        assertFalse(AnalyticsProcessState.measurementTouched)
    }

    @Test
    fun savedConsentLeavesExistingSdkAlone() {
        AnalyticsProcessState.measurementTouched = true

        assertNull(AnalyticsProcessState.applySavedRefusal(true, probeDefaultApp, disable))

        assertEquals(0, appProbes)
        assertEquals(0, disables)
    }

    @Test
    fun warmSavedRefusalDisablesExistingSdkWithoutProbingFirebase() {
        AnalyticsProcessState.measurementTouched = true

        assertNull(AnalyticsProcessState.applySavedRefusal(false, probeDefaultApp, disable))

        assertEquals(0, appProbes)
        assertEquals(1, disables)
    }

    @Test
    fun existingDefaultAppCountsAsStartedSdk() {
        defaultAppExists = true

        assertNull(AnalyticsProcessState.applySavedRefusal(false, probeDefaultApp, disable))

        assertEquals(1, disables)
        assertTrue(AnalyticsProcessState.measurementTouched)
    }

    @Test
    fun attachedPluginMarksProcessTouched() {
        AnalyticsProcessState.disableIfActive(true, probeDefaultApp, disable)

        assertEquals(0, appProbes)
        assertEquals(1, disables)
        assertTrue(AnalyticsProcessState.measurementTouched)
    }

    @Test
    fun everyActivityRecreationReappliesRefusal() {
        AnalyticsProcessState.measurementTouched = true

        AnalyticsProcessState.applySavedRefusal(false, probeDefaultApp, disable)
        AnalyticsProcessState.applySavedRefusal(false, probeDefaultApp, disable)

        assertEquals(2, disables)
    }

    @Test
    fun ordinaryFailureIsReturnedAndKeepsSdkMarkedForDartRetry() {
        AnalyticsProcessState.measurementTouched = true
        val error = IllegalStateException("disable failed")
        failure = error

        assertSame(error, AnalyticsProcessState.applySavedRefusal(false, probeDefaultApp, disable))
        assertTrue(AnalyticsProcessState.measurementTouched)
    }

    @Test
    fun channelDisableFailureReachesCaller() {
        AnalyticsProcessState.measurementTouched = true
        failure = IllegalStateException("disable failed")

        assertThrows(IllegalStateException::class.java) {
            AnalyticsProcessState.disableIfActive(false, probeDefaultApp, disable)
        }
    }

    @Test
    fun fatalErrorIsNotSwallowed() {
        AnalyticsProcessState.measurementTouched = true
        failure = FatalError()

        assertThrows(FatalError::class.java) {
            AnalyticsProcessState.applySavedRefusal(false, probeDefaultApp, disable)
        }
    }
}
