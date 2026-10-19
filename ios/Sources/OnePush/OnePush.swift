import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Ad Venture One Push — uygulamanın gördüğü yüzey (docs/ONE_PUSH_PLANI.md bölüm 4).
/// Bütün çağrılar `start` sonrası geçerlidir; öncesinde sessizce yok sayılır ve
/// `logger` yazar (çökertmek bir pazarlama SDK'sına yakışmaz).
public enum OnePush {
    private static let lock = NSLock()
    private static var shared: OnePushClient?

    public static var client: OnePushClient? { lock.withLock { shared } }

    @discardableResult
    public static func start(_ config: OnePushConfig) -> OnePushClient {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OnePush", isDirectory: true)
        let c = OnePushClient(config: config, transport: URLSessionTransport(endpoint: config.endpoint),
                              storageDirectory: dir)
        lock.withLock { shared = c }
        c.flush()
        return c
    }

    /// Testler ve adaptörler için: hazır bir istemciyi paylaşılan yap.
    public static func use(_ client: OnePushClient) { lock.withLock { shared = client } }

    public static func setPushToken(_ token: String) { client?.setPushToken(token) }
    public static func setAppInstanceId(_ id: String) { client?.setAppInstanceId(id) }
    public static func setUserId(_ id: String) { client?.setUserId(id) }
    public static func clearUserId() { client?.setUserId(nil) }
    public static func setUserAttribute(_ key: String, _ value: String?) { client?.setUserAttribute(key, value) }
    public static func addTag(_ tag: String) { client?.addTag(tag) }
    public static func removeTag(_ tag: String) { client?.removeTag(tag) }
    public static func setConsent(_ granted: Bool) { client?.setConsent(granted) }
    public static func track(_ event: String, _ params: [String: String] = [:]) { client?.track(event, params: params) }
    public static func flush() { client?.flush() }

    /// Payload bizim mi? Misafir modunda uygulamanın yönlendirme kararı.
    public static func isOnePushMessage(_ userInfo: [AnyHashable: Any]) -> Bool { OnePushPayload.isOnePush(userInfo) }

    /// Bildirim ALINDI (arka planda ya da ön planda). Bizim değilse `false`.
    @discardableResult
    public static func handle(_ userInfo: [AnyHashable: Any]) -> Bool { client?.handle(userInfo, opened: false) ?? false }

    /// Kullanıcı bildirime DOKUNDU. Bizim değilse `false`.
    @discardableResult
    public static func didOpen(_ userInfo: [AnyHashable: Any]) -> Bool { client?.handle(userInfo, opened: true) ?? false }

    public static var inbox: [InboxItem] { client?.inboxItems() ?? [] }
    public static func markInboxRead(_ pushId: String) { client?.markInboxRead(pushId) }

    #if canImport(UserNotifications)
    /// `userNotificationCenter(_:didReceive:)` içinden tek satır.
    @discardableResult
    public static func didOpen(_ response: UNNotificationResponse) -> Bool {
        didOpen(response.notification.request.content.userInfo)
    }

    /// İzin isteği. `softPrompt` verilirse önce o çalışır ve `true` dönerse sistem
    /// izni sorulur (K16: ön ekran isteğe bağlı; sistem iznini bir kez sorabilirsin).
    public static func requestPermission(softPrompt: ((@escaping (Bool) -> Void) -> Void)? = nil,
                                         options: UNAuthorizationOptions = [.alert, .badge, .sound],
                                         completion: ((Bool) -> Void)? = nil) {
        let ask: () -> Void = {
            UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
                client?.setPermission(granted ? "granted" : "denied")
                completion?(granted)
            }
        }
        if let soft = softPrompt {
            soft { proceed in if proceed { ask() } else { client?.setPermission("deferred"); completion?(false) } }
        } else {
            ask()
        }
    }

    /// Mevcut izin durumunu sunucuya bildirir (başlangıçta ve ön plana dönüşte çağır).
    public static func refreshPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let v: String
            switch s.authorizationStatus {
            case .authorized, .provisional, .ephemeral: v = "granted"
            case .denied: v = "denied"
            case .notDetermined: v = "not_determined"
            @unknown default: v = "unknown"
            }
            client?.setPermission(v)
        }
    }
    #endif
}
