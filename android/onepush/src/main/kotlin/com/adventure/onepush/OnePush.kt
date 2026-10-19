package com.adventure.onepush

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import java.util.Locale
import java.util.TimeZone

/**
 * Ad Venture One Push — uygulamanın gördüğü yüzey (docs/ONE_PUSH_PLANI.md bölüm 4).
 * `start` öncesi çağrılar sessizce yok sayılır; bir pazarlama SDK'sı uygulamayı çökertmez.
 *
 * Misafir modu (varsayılan): kendi FirebaseMessagingService'imiz YOK. Uygulamanın
 * mevcut servisi iki satır ekler:
 *
 *     override fun onNewToken(token: String) { OnePush.setPushToken(token); /* öteki sağlayıcı */ }
 *     override fun onMessageReceived(m: RemoteMessage) {
 *         if (OnePush.handle(m.data)) return          // bizimse: alındı kaydı + kutu; bildirimi uygulama gösterir
 *         /* öteki sağlayıcıya devret */
 *     }
 *
 * Açılış: bildirime dokunulunca açılan Activity `onCreate`/`onNewIntent` içinde
 * `OnePush.handleIntent(intent)` çağırır (FCM, data alanlarını Intent extras'a koyar).
 */
object OnePush {
    @Volatile private var shared: OnePushClient? = null
    val client: OnePushClient? get() = shared

    fun start(context: Context, config: OnePushConfig): OnePushClient {
        val app = context.applicationContext
        val env = if (config.environment == OnePushEnvironment.AUTO) detectEnvironment(app) else config.environment
        val c = OnePushClient(
            config = config, transport = HttpTransport(config.endpoint),
            storageDir = File(app.filesDir, "onepush"), device = deviceInfo(app),
            environment = env, bundleId = app.packageName,
        )
        shared = c
        c.setPermission(permissionStatus(app))
        c.flush()
        return c
    }

    /** Testler ve adaptörler için: hazır istemciyi paylaşılan yap. */
    fun use(client: OnePushClient) { shared = client }

    fun setPushToken(token: String) { shared?.setPushToken(token) }
    fun setAppInstanceId(id: String) { shared?.setAppInstanceId(id) }
    fun setUserId(id: String) { shared?.setUserId(id) }
    fun clearUserId() { shared?.setUserId(null) }
    fun setUserAttribute(key: String, value: String?) { shared?.setUserAttribute(key, value) }
    fun addTag(tag: String) { shared?.addTag(tag) }
    fun removeTag(tag: String) { shared?.removeTag(tag) }
    fun setConsent(granted: Boolean) { shared?.setConsent(granted) }
    fun track(event: String, params: Map<String, String> = emptyMap()) { shared?.track(event, params) }
    fun flush() { shared?.flush() }

    /** Payload bizim mi? Misafir modunda uygulamanın yönlendirme kararı. */
    fun isOnePushMessage(data: Map<String, String?>?): Boolean = OnePushPayload.isOnePush(data)

    /** Bildirim ALINDI (RemoteMessage.data). Bizim değilse false. */
    fun handle(data: Map<String, String?>?): Boolean = shared?.handle(data, opened = false) ?: false

    /** Kullanıcı bildirime DOKUNDU. Bizim değilse false. */
    fun didOpen(data: Map<String, String?>?): Boolean = shared?.handle(data, opened = true) ?: false

    /** Açılış Intent'i: FCM data alanları extras'tadır. */
    fun handleIntent(intent: Intent?): Boolean {
        val extras = intent?.extras ?: return false
        val data = HashMap<String, String?>()
        for (k in extras.keySet()) data[k] = extras.get(k)?.toString()
        return didOpen(data)
    }

    val inbox: List<InboxItem> get() = shared?.inboxItems() ?: emptyList()
    fun markInboxRead(pushId: String) { shared?.markInboxRead(pushId) }

    /**
     * Android 13+ bildirim izni (POST_NOTIFICATIONS). Sonuç Activity'nin
     * onRequestPermissionsResult'ına düşer; oradan `refreshPermissionStatus` çağrılır.
     * Ön ekran (K16) uygulamanın kendi UI'sıdır: önce onu göster, "evet"te bunu çağır.
     */
    fun requestPermission(activity: Activity, requestCode: Int = 4101) {
        if (Build.VERSION.SDK_INT >= 33) {
            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), requestCode)
        } else {
            refreshPermissionStatus(activity)
        }
    }

    fun refreshPermissionStatus(context: Context) { shared?.setPermission(permissionStatus(context)) }

    // ---- Android okumaları
    internal fun permissionStatus(context: Context): String {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return "unknown"
        return if (nm.areNotificationsEnabled()) "granted" else "denied"
    }

    internal fun detectEnvironment(context: Context): OnePushEnvironment {
        val debuggable = (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        val installer = runCatching {
            if (Build.VERSION.SDK_INT >= 30) context.packageManager.getInstallSourceInfo(context.packageName).installingPackageName
            else @Suppress("DEPRECATION") context.packageManager.getInstallerPackageName(context.packageName)
        }.getOrNull()
        return EnvironmentDetector.detect(debuggable, installer)
    }

    internal fun deviceInfo(context: Context): DeviceInfo {
        val pi = runCatching { context.packageManager.getPackageInfo(context.packageName, 0) }.getOrNull()
        val code = pi?.let { if (Build.VERSION.SDK_INT >= 28) it.longVersionCode else @Suppress("DEPRECATION") it.versionCode.toLong() } ?: 0L
        return DeviceInfo(
            appVersion = "${pi?.versionName ?: "0"} ($code)",
            osVersion = Build.VERSION.RELEASE ?: "0",
            deviceModel = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            locale = Locale.getDefault().toString(),
            timeZone = TimeZone.getDefault().id,
        )
    }
}
