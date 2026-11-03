package onl.coconut.wallet

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Flutter 업그레이드 뒤에도 생성된 등록 코드가 엔진 registry를 거쳐야 attach 보류가 동작한다. */
class GeneratedPluginRegistrantBindingTest {
    @Test
    fun analyticsPluginIsRegisteredOnlyThroughEnginePlugins() {
        val registrant = File("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
        assertTrue("Run flutter pub get before Android unit tests", registrant.isFile)
        val source = registrant.readText()

        assertEquals(1, Regex("""new io\.flutter\.plugins\.firebase\.analytics\.FlutterFirebaseAnalyticsPlugin\(""").findAll(source).count())
        assertTrue(
            source.contains(
                "flutterEngine.getPlugins().add(new io.flutter.plugins.firebase.analytics.FlutterFirebaseAnalyticsPlugin());",
            ),
        )
    }
}
