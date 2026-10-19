package com.adventure.onepush.rn

import com.adventure.onepush.OnePush
import com.adventure.onepush.OnePushConfig
import com.adventure.onepush.OnePushEnvironment
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
import com.facebook.react.bridge.ReadableMap

/** React Native köprüsü (Android). Metot adları src/index.ts ile birebir. */
class OnePushModule(private val ctx: ReactApplicationContext) : ReactContextBaseJavaModule(ctx) {
    override fun getName() = "OnePushModule"

    private fun ReadableMap.strings(): Map<String, String?> {
        val out = HashMap<String, String?>()
        val it = keySetIterator()
        while (it.hasNextKey()) { val k = it.nextKey(); out[k] = if (isNull(k)) null else getDynamic(k).asString() }
        return out
    }

    @ReactMethod fun start(cfg: ReadableMap, p: Promise) {
        val key = cfg.getString("appKey") ?: return p.reject("arg", "appKey gerekli")
        val env = cfg.getString("environment")?.let { e -> OnePushEnvironment.values().firstOrNull { it.wire == e } } ?: OnePushEnvironment.AUTO
        OnePush.start(ctx, OnePushConfig(
            appKey = key,
            endpoint = cfg.getString("endpoint") ?: "https://one.adventuredigital.com/push/v1",
            environment = env,
            guestMode = if (cfg.hasKey("guestMode")) cfg.getBoolean("guestMode") else true,
        ))
        p.resolve(null)
    }
    @ReactMethod fun setPushToken(t: String, p: Promise) { OnePush.setPushToken(t); p.resolve(null) }
    @ReactMethod fun setAppInstanceId(id: String, p: Promise) { OnePush.setAppInstanceId(id); p.resolve(null) }
    @ReactMethod fun setUserId(id: String?, p: Promise) { if (id == null) OnePush.clearUserId() else OnePush.setUserId(id); p.resolve(null) }
    @ReactMethod fun setUserAttribute(k: String, v: String?, p: Promise) { OnePush.setUserAttribute(k, v); p.resolve(null) }
    @ReactMethod fun addTag(t: String, p: Promise) { OnePush.addTag(t); p.resolve(null) }
    @ReactMethod fun removeTag(t: String, p: Promise) { OnePush.removeTag(t); p.resolve(null) }
    @ReactMethod fun setConsent(g: Boolean, p: Promise) { OnePush.setConsent(g); p.resolve(null) }
    @ReactMethod fun track(e: String, params: ReadableMap, p: Promise) {
        OnePush.track(e, params.strings().mapValues { it.value ?: "" }); p.resolve(null)
    }
    @ReactMethod fun flush(p: Promise) { OnePush.flush(); p.resolve(null) }
    @ReactMethod fun handle(d: ReadableMap, p: Promise) = p.resolve(OnePush.handle(d.strings()))
    @ReactMethod fun didOpen(d: ReadableMap, p: Promise) = p.resolve(OnePush.didOpen(d.strings()))
    @ReactMethod fun inbox(limit: Double, p: Promise) {
        val arr = Arguments.createArray()
        OnePush.inbox.take(limit.toInt()).forEach {
            arr.pushMap(Arguments.createMap().apply {
                putString("pushId", it.pushId); putString("title", it.title); putString("body", it.body)
                putString("deepLink", it.deepLink); putDouble("receivedAt", it.receivedAtMs.toDouble()); putBoolean("read", it.read)
            })
        }
        p.resolve(arr)
    }
    @ReactMethod fun markInboxRead(id: String, p: Promise) { OnePush.markInboxRead(id); p.resolve(null) }
    @ReactMethod fun requestPermission(p: Promise) {
        val act = currentActivity ?: return p.resolve(false)
        OnePush.requestPermission(act)
        // Sonuç Activity'ye düşer; uygulama onRequestPermissionsResult'ta refreshPermissionStatus çağırır.
        p.resolve(android.os.Build.VERSION.SDK_INT < 33)
    }
    @ReactMethod fun refreshPermissionStatus(p: Promise) { OnePush.refreshPermissionStatus(ctx); p.resolve(null) }
}
