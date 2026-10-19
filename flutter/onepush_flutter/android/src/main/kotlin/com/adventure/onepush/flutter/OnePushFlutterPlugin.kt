package com.adventure.onepush.flutter

import android.app.Activity
import android.content.Context
import com.adventure.onepush.OnePush
import com.adventure.onepush.OnePushConfig
import com.adventure.onepush.OnePushEnvironment
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Flutter köprüsü (Android). Kanal adı Dart tarafıyla birebir. */
class OnePushFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var pendingPermission: MethodChannel.Result? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.adventure.onepush/flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) = channel.setMethodCallHandler(null)
    override fun onAttachedToActivity(b: ActivityPluginBinding) { activity = b.activity; b.addRequestPermissionsResultListener(this) }
    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) { activity = b.activity; b.addRequestPermissionsResultListener(this) }
    override fun onDetachedFromActivity() { activity = null }

    @Suppress("UNCHECKED_CAST")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val key = call.argument<String>("appKey") ?: return result.error("arg", "appKey gerekli", null)
                val env = call.argument<String>("environment")?.let { e -> OnePushEnvironment.values().firstOrNull { it.wire == e } }
                    ?: OnePushEnvironment.AUTO
                OnePush.start(context, OnePushConfig(
                    appKey = key,
                    endpoint = call.argument<String>("endpoint") ?: "https://one.adventuredigital.com/push/v1",
                    environment = env,
                    guestMode = call.argument<Boolean>("guestMode") ?: true,
                ))
                result.success(null)
            }
            "setPushToken" -> { OnePush.setPushToken(call.argument("token") ?: ""); result.success(null) }
            "setAppInstanceId" -> { OnePush.setAppInstanceId(call.argument("id") ?: ""); result.success(null) }
            "setUserId" -> { OnePush.setUserId(call.argument("id") ?: ""); result.success(null) }
            "clearUserId" -> { OnePush.clearUserId(); result.success(null) }
            "setUserAttribute" -> { OnePush.setUserAttribute(call.argument("key") ?: "", call.argument("value")); result.success(null) }
            "addTag" -> { OnePush.addTag(call.argument("tag") ?: ""); result.success(null) }
            "removeTag" -> { OnePush.removeTag(call.argument("tag") ?: ""); result.success(null) }
            "setConsent" -> { OnePush.setConsent(call.argument("granted") ?: true); result.success(null) }
            "track" -> { OnePush.track(call.argument("event") ?: "", call.argument<Map<String, String>>("params") ?: emptyMap()); result.success(null) }
            "flush" -> { OnePush.flush(); result.success(null) }
            "handle" -> result.success(OnePush.handle(call.argument<Map<String, String?>>("data")))
            "didOpen" -> result.success(OnePush.didOpen(call.argument<Map<String, String?>>("data")))
            "inbox" -> result.success(OnePush.inbox.take(call.argument<Int>("limit") ?: 50).map {
                mapOf("push_id" to it.pushId, "title" to it.title, "body" to it.body, "deep_link" to it.deepLink,
                    "received_at" to it.receivedAtMs, "read" to it.read)
            })
            "markInboxRead" -> { OnePush.markInboxRead(call.argument("pushId") ?: ""); result.success(null) }
            "requestPermission" -> {
                val act = activity ?: return result.success(false)
                if (android.os.Build.VERSION.SDK_INT < 33) { OnePush.refreshPermissionStatus(act); return result.success(true) }
                pendingPermission = result
                OnePush.requestPermission(act, REQ)
            }
            "refreshPermissionStatus" -> { OnePush.refreshPermissionStatus(context); result.success(null) }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        if (requestCode != REQ) return false
        OnePush.refreshPermissionStatus(context)
        pendingPermission?.success(grantResults.isNotEmpty() && grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
        return true
    }

    companion object { const val REQ = 4101 }
}
