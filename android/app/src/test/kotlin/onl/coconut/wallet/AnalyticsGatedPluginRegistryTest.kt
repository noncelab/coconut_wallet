package onl.coconut.wallet

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.PluginRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AnalyticsGatedPluginRegistryTest {
    private open class TestPlugin : FlutterPlugin {
        override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
        override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = Unit
    }

    private class ConsentPlugin : TestPlugin()
    private class SecondConsentPlugin : TestPlugin()
    private class WalletPlugin : TestPlugin()
    private class OtherWalletPlugin : TestPlugin()

    /** 엔진 registry처럼 같은 클래스의 두 번째 등록은 무시하고 호출 순서를 기록한다. */
    private class FakeRegistry(private val events: MutableList<String>) : PluginRegistry {
        val plugins = linkedMapOf<Class<out FlutterPlugin>, FlutterPlugin>()
        var failNextAdd = false

        override fun add(plugin: FlutterPlugin) {
            if (failNextAdd) {
                failNextAdd = false
                throw IllegalStateException("attach failed")
            }
            if (plugins.putIfAbsent(plugin.javaClass, plugin) == null) events += "attach:${plugin.javaClass.simpleName}"
        }

        override fun add(plugins: Set<FlutterPlugin>) = plugins.forEach(::add)

        override fun has(pluginClass: Class<out FlutterPlugin>): Boolean = plugins.containsKey(pluginClass)

        override fun get(pluginClass: Class<out FlutterPlugin>): FlutterPlugin? = plugins[pluginClass]

        override fun remove(pluginClass: Class<out FlutterPlugin>) {
            events += "remove:${pluginClass.simpleName}"
            plugins.remove(pluginClass)
        }

        override fun remove(pluginClasses: Set<Class<out FlutterPlugin>>) = pluginClasses.forEach(::remove)

        override fun removeAll() {
            events += "removeAll"
            plugins.clear()
        }
    }

    private val events = mutableListOf<String>()
    private val delegate = FakeRegistry(events)
    private var failBeforeAttach = false
    private val registry = AnalyticsGatedPluginRegistry(
        delegate,
        { it is ConsentPlugin || it is SecondConsentPlugin },
        {
            if (failBeforeAttach) {
                failBeforeAttach = false
                throw IllegalStateException("before attach failed")
            }
            events += "beforeAttach"
        },
    )

    @Test
    fun holdsConsentPluginWhileOtherPluginsAttachInOrder() {
        registry.add(linkedSetOf(WalletPlugin(), ConsentPlugin(), OtherWalletPlugin()))

        assertEquals(listOf("attach:WalletPlugin", "attach:OtherWalletPlugin"), events)
        assertTrue(registry.hasHeldPlugins())
        assertFalse(registry.has(ConsentPlugin::class.java))
    }

    @Test
    fun releaseAttachesHeldPluginsInRegistrationOrderAfterBeforeAttach() {
        registry.add(SecondConsentPlugin())
        registry.add(ConsentPlugin())

        registry.releaseHeld()

        assertEquals(
            listOf("beforeAttach", "attach:SecondConsentPlugin", "beforeAttach", "attach:ConsentPlugin"),
            events,
        )
        assertFalse(registry.hasHeldPlugins())
        assertTrue(registry.has(ConsentPlugin::class.java))
    }

    @Test
    fun duplicateConsentRegistrationKeepsFirstInstance() {
        val first = ConsentPlugin()
        registry.add(first)
        registry.add(ConsentPlugin())

        registry.releaseHeld()

        assertEquals(listOf("beforeAttach", "attach:ConsentPlugin"), events)
        assertSame(first, registry.get(ConsentPlugin::class.java))
    }

    @Test
    fun consentPluginAddedAfterReleaseAttachesImmediately() {
        registry.releaseHeld()

        registry.add(ConsentPlugin())

        assertEquals(listOf("beforeAttach", "attach:ConsentPlugin"), events)
        assertFalse(registry.hasHeldPlugins())
    }

    @Test
    fun removeDropsHeldPluginSoReleaseAttachesNothing() {
        registry.add(ConsentPlugin())

        registry.remove(setOf(ConsentPlugin::class.java))
        registry.releaseHeld()

        assertEquals(listOf("remove:ConsentPlugin"), events)
        assertFalse(registry.hasHeldPlugins())
    }

    @Test
    fun removeAllClearsHeldAndAttachedPlugins() {
        registry.add(WalletPlugin())
        registry.add(ConsentPlugin())

        registry.removeAll()
        registry.releaseHeld()

        assertEquals(listOf("attach:WalletPlugin", "removeAll"), events)
        assertFalse(registry.hasHeldPlugins())
        assertFalse(registry.has(WalletPlugin::class.java))
    }

    @Test
    fun beforeAttachFailureKeepsPluginHeldForRetry() {
        registry.add(ConsentPlugin())
        failBeforeAttach = true

        assertThrows(IllegalStateException::class.java) { registry.releaseHeld() }
        assertTrue(registry.hasHeldPlugins())
        assertFalse(registry.has(ConsentPlugin::class.java))

        registry.releaseHeld()

        assertEquals(listOf("beforeAttach", "attach:ConsentPlugin"), events)
        assertFalse(registry.hasHeldPlugins())
    }

    @Test
    fun attachFailureKeepsPluginHeldForRetry() {
        registry.add(ConsentPlugin())
        delegate.failNextAdd = true

        assertThrows(IllegalStateException::class.java) { registry.releaseHeld() }
        assertTrue(registry.hasHeldPlugins())

        registry.releaseHeld()

        assertEquals(listOf("beforeAttach", "beforeAttach", "attach:ConsentPlugin"), events)
        assertFalse(registry.hasHeldPlugins())
    }
}
