package onl.coconut.wallet

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.PluginRegistry

/** 생성된 등록 목록을 그대로 사용하면서 동의가 필요한 플러그인의 attach만 보류한다. */
internal class AnalyticsGatedPluginRegistry(
    private val delegate: PluginRegistry,
    private val requiresConsent: (FlutterPlugin) -> Boolean,
    private val beforeAttach: () -> Unit,
) : PluginRegistry {
    private val held = linkedMapOf<Class<out FlutterPlugin>, FlutterPlugin>()
    private var holding = true

    override fun add(plugin: FlutterPlugin) {
        if (requiresConsent(plugin)) {
            if (holding) {
                held.putIfAbsent(plugin.javaClass, plugin)
                return
            }
            beforeAttach()
        }
        delegate.add(plugin)
    }

    override fun add(plugins: Set<FlutterPlugin>) = plugins.forEach(::add)

    override fun has(pluginClass: Class<out FlutterPlugin>): Boolean = delegate.has(pluginClass)

    override fun get(pluginClass: Class<out FlutterPlugin>): FlutterPlugin? = delegate.get(pluginClass)

    override fun remove(pluginClass: Class<out FlutterPlugin>) {
        held.remove(pluginClass)
        delegate.remove(pluginClass)
    }

    override fun remove(pluginClasses: Set<Class<out FlutterPlugin>>) = pluginClasses.forEach(::remove)

    override fun removeAll() {
        held.clear()
        delegate.removeAll()
    }

    fun releaseHeld() {
        holding = false
        for (plugin in held.values.toList()) {
            add(plugin)
            held.remove(plugin.javaClass)
        }
    }

    fun hasHeldPlugins(): Boolean = held.isNotEmpty()
}
