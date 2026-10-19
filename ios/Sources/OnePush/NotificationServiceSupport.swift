import Foundation
#if canImport(UserNotifications)
import UserNotifications

/// Notification Service Extension desteği (iOS teslim ölçümü + zengin görsel).
/// Uygulamada TEK NSE olur; misafir modunda zincir şöyle kurulur:
///
///     override func didReceive(_ request: UNNotificationRequest,
///                              withContentHandler handler: @escaping (UNNotificationContent) -> Void) {
///         if OnePushNotificationService.process(request, appKey: "…", contentHandler: handler) { return }
///         // bizim değil → öteki sağlayıcının NSE sınıfına devret
///     }
///
/// Uzantı ana uygulamanın durumunu görmez; teslim olayı doğrudan sunucuya gider.
public enum OnePushNotificationService {
    /// Bizim push'umuzsa işler ve `true` döner (handler ÇAĞRILIR); değilse `false`
    /// döner ve handler'a DOKUNMAZ.
    @discardableResult
    public static func process(_ request: UNNotificationRequest,
                               appKey: String,
                               endpoint: URL = URL(string: "https://one.adventuredigital.com/push/v1")!,
                               bundleId: String? = nil,
                               contentHandler: @escaping (UNNotificationContent) -> Void) -> Bool {
        let info = request.content.userInfo
        guard let p = OnePushPayload(userInfo: info) else { return false }
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let transport = URLSessionTransport(endpoint: endpoint)
        let headers = ["X-One-App-Key": appKey,
                       "X-One-Bundle-Id": bundleId ?? (Bundle.main.bundleIdentifier ?? "unknown"),
                       "X-One-SDK": "ios-nse/\(onePushSDKVersion)"]
        let event: [String: Any] = ["events": [["type": "delivered", "push_id": p.pushId,
                                                 "ts": ISO8601DateFormatter().string(from: Date()),
                                                 "environment": EnvironmentDetector.current().rawValue]]]
        let group = DispatchGroup()
        group.enter()
        transport.send(path: "event", method: "POST", body: event, headers: headers) { _ in group.leave() }
        if let url = p.imageURL {
            group.enter()
            URLSession.shared.downloadTask(with: url) { tmp, _, _ in
                defer { group.leave() }
                guard let tmp = tmp else { return }
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("onepush-\(p.pushId)-\(url.lastPathComponent)")
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.moveItem(at: tmp, to: dest)
                if let att = try? UNNotificationAttachment(identifier: "one_image", url: dest) {
                    content.attachments = [att]
                }
            }.resume()
        }
        // Uzantı süresi sınırlı (~30 sn): en geç 20 sn'de içeriği teslim et.
        group.notify(queue: .main) { contentHandler(content) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { contentHandler(content) }
        return true
    }
}
#endif
