package com.adventure.onepush.firebase

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import com.adventure.onepush.OnePush
import com.adventure.onepush.OnePushPayload
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Çekirdeği Firebase'e bağlar. Misafir modunda `connect()` yalnız OKUR: token'ı
 * `FirebaseMessaging.token` ile alır, uygulama örneği kimliğini FirebaseAnalytics'ten
 * okur, GA4 köprüsünü bağlar; kendi servisini bildirmez — token yenilemesi ve
 * mesajlar uygulamanın mevcut servisinden `OnePush.setPushToken` / `OnePush.handle`
 * ile gelir. Tek sağlayıcı modunda `OnePushMessagingService` manifeste eklenir.
 */
object OnePushFirebase {
    const val CHANNEL_ID = "one_push"

    fun connect(context: Context) {
        val client = OnePush.client ?: return
        val app = context.applicationContext
        val fa = FirebaseAnalytics.getInstance(app)
        client.analyticsLogger = { name, params -> fa.logEvent(name, bundleOf(params)) }
        fa.appInstanceId.addOnSuccessListener { id -> if (id != null) client.setAppInstanceId(id) }
        FirebaseMessaging.getInstance().token.addOnSuccessListener { t -> if (t != null) client.setPushToken(t) }
    }

    /**
     * Bizim push'umuzu sistem tepsisinde gösterir (data mesajı ya da ön plan).
     * Dokunuş uygulamanın başlatıcı Activity'sini data alanlarıyla açar; orada
     * `OnePush.handleIntent(intent)` açılışı kaydeder.
     */
    fun showNotification(context: Context, payload: OnePushPayload, smallIcon: Int) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL_ID, "Bildirimler", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        launch.putExtra(OnePushPayload.ID, payload.pushId)
        payload.pushType?.let { launch.putExtra(OnePushPayload.TYPE, it) }
        payload.campaignId?.let { launch.putExtra(OnePushPayload.CAMPAIGN, it) }
        payload.deepLink?.let { launch.putExtra(OnePushPayload.DEEP_LINK, it) }
        val pi = PendingIntent.getActivity(context, payload.pushId.hashCode(), launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val n = android.app.Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(smallIcon)
            .setContentTitle(payload.title ?: "")
            .setContentText(payload.body ?: "")
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()
        nm.notify(payload.pushId.hashCode(), n)
    }

    internal fun bundleOf(params: Map<String, String>): Bundle = Bundle().apply { params.forEach { (k, v) -> putString(k, v) } }
}

/**
 * Tek sağlayıcı modu servisi. Misafir modunda KULLANILMAZ (manifeste girmez).
 * Gösterim için uygulama `smallIcon`u `OnePushMessagingService.smallIcon` ile verir.
 */
open class OnePushMessagingService : FirebaseMessagingService() {
    companion object { @JvmStatic var smallIcon: Int = android.R.drawable.ic_dialog_info }

    override fun onNewToken(token: String) { OnePush.setPushToken(token) }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (!OnePush.handle(data)) return
        // Bildirim gövdesi FCM "notification" alanıyla geldiyse sistem gösterir; data-only ise biz.
        if (message.notification == null) {
            OnePushPayload.from(data)?.let { OnePushFirebase.showNotification(applicationContext, it, smallIcon) }
        }
    }
}
