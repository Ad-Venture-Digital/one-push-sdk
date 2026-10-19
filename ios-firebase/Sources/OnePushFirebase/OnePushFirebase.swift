import Foundation
import OnePush
import FirebaseMessaging
import FirebaseAnalytics
import UserNotifications

/// Çekirdeği Firebase'e bağlar: FCM token'ı, uygulama örneği kimliği (GA4 kitle
/// eşlemesi) ve GA4 olay köprüsü. İki kip:
///
/// **Misafir modu (varsayılan):** `connect()` yalnız OKUR ve DİNLER — token'ı
/// `Messaging.messaging().token` ile alır, yenilemeyi Firebase'in bildirimi
/// (`messagingRegistrationTokenRefreshed`) üzerinden izler, `Messaging.delegate`'e
/// ve `UNUserNotificationCenter.delegate`'e DOKUNMAZ. Öteki sağlayıcı yerinde kalır;
/// uygulama bildirim işleyicisinden `OnePush.handle` / `OnePush.didOpen` çağırır.
///
/// **Tek sağlayıcı modu:** `installNotificationDelegate()` bildirim delegesini
/// kurar; ön planda gösterir, dokunuşu çekirdeğe iletir. Yalnız öteki sağlayıcı
/// kaldırıldıktan sonra çağrılır.
public enum OnePushFirebase {
    private static var observer: NSObjectProtocol?
    private static let delegate = NotificationDelegate()

    /// `FirebaseApp.configure()` ve `OnePush.start(...)` sonrası bir kez.
    public static func connect() {
        guard let client = OnePush.client else { return }
        client.analyticsLogger = { name, params in Analytics.logEvent(name, parameters: params) }
        if let id = Analytics.appInstanceID() { client.setAppInstanceId(id) }
        Messaging.messaging().token { token, _ in if let t = token { client.setPushToken(t) } }
        observer = NotificationCenter.default.addObserver(
            forName: Notification.Name.MessagingRegistrationTokenRefreshed, object: nil, queue: .main) { _ in
            Messaging.messaging().token { token, _ in if let t = token { OnePush.setPushToken(t) } }
        }
    }

    /// Tek sağlayıcı modu: One Push bildirim delegesi olur.
    public static func installNotificationDelegate(presentInForeground: UNNotificationPresentationOptions = [.banner, .list, .sound, .badge]) {
        delegate.foreground = presentInForeground
        UNUserNotificationCenter.current().delegate = delegate
    }

    final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
        var foreground: UNNotificationPresentationOptions = [.banner, .list, .sound, .badge]

        func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
            OnePush.handle(notification.request.content.userInfo)
            completionHandler(foreground)
        }

        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                    withCompletionHandler completionHandler: @escaping () -> Void) {
            OnePush.didOpen(response)
            completionHandler()
        }
    }
}
