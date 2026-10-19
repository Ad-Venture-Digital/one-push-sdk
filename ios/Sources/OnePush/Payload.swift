import Foundation

/// Bizim push'umuzun `data` alanları. Yönlendirme işareti `one_push_id`:
/// payload bunu taşıyorsa One'ındır, taşımıyorsa öteki sağlayıcınındır (K12).
public struct OnePushPayload: Equatable {
    public static let idKey = "one_push_id"
    public static let typeKey = "one_push_turu"
    public static let campaignKey = "one_kampanya_id"
    public static let deepLinkKey = "one_deeplink"
    public static let imageKey = "one_image"
    public static let inboxTitleKey = "one_baslik"
    public static let inboxBodyKey = "one_metin"

    public let pushId: String
    public let pushType: String?
    public let campaignId: String?
    public let deepLink: URL?
    public let imageURL: URL?
    public let title: String?
    public let body: String?

    /// `userInfo` (APNs) ya da FCM `data` sözlüğünden; işaret yoksa nil.
    public init?(userInfo: [AnyHashable: Any]) {
        guard let id = OnePushPayload.string(userInfo[OnePushPayload.idKey]), !id.isEmpty else { return nil }
        pushId = id
        pushType = OnePushPayload.string(userInfo[OnePushPayload.typeKey])
        campaignId = OnePushPayload.string(userInfo[OnePushPayload.campaignKey])
        deepLink = OnePushPayload.string(userInfo[OnePushPayload.deepLinkKey]).flatMap(URL.init(string:))
        imageURL = OnePushPayload.string(userInfo[OnePushPayload.imageKey]).flatMap(URL.init(string:))
        // Başlık/metin: önce bizim alanlarımız, yoksa APNs `aps.alert`.
        var t = OnePushPayload.string(userInfo[OnePushPayload.inboxTitleKey])
        var b = OnePushPayload.string(userInfo[OnePushPayload.inboxBodyKey])
        if let aps = userInfo["aps"] as? [AnyHashable: Any], let alert = aps["alert"] as? [AnyHashable: Any] {
            t = t ?? OnePushPayload.string(alert["title"])
            b = b ?? OnePushPayload.string(alert["body"])
        }
        title = t
        body = b
    }

    public static func isOnePush(_ userInfo: [AnyHashable: Any]) -> Bool {
        OnePushPayload(userInfo: userInfo) != nil
    }

    private static func string(_ v: Any?) -> String? {
        if let s = v as? String { return s }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }
}
