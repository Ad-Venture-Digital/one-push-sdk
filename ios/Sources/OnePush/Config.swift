import Foundation

/// SDK sürümü — sunucuya `sdk_version` olarak gider.
public let onePushSDKVersion = "0.1.0"

/// Gönderimde seçilebilen hedef ortam (docs/ONE_PUSH_PLANI.md K16/K26).
/// SDK ortamı KENDİSİ bildirir; `auto` dışında bir değer yalnız test amaçlı ezmedir.
public enum OnePushEnvironment: String, Codable {
    case auto
    case debug
    case testFlight = "test"
    case store = "production"
}

/// Başlatma ayarları. `appKey` gizli değildir (uygulama paketinden okunabilir);
/// güvenlik sunucudaki paket adı eşlemesi ve hız sınırındadır (K15).
public struct OnePushConfig {
    public var appKey: String
    public var endpoint: URL
    public var environment: OnePushEnvironment
    /// Misafir modu (K12): SDK bildirim delegesini ve token akışını ELE GEÇİRMEZ;
    /// uygulama mevcut işleyicisinden `OnePush.setPushToken` ve `OnePush.handle` çağırır.
    public var guestMode: Bool
    /// `track()` çağrısının hangi push'a bağlanacağı: son açılıştan bu yana geçen süre.
    public var attributionWindow: TimeInterval
    /// Kuyruk boşaltma partisi.
    public var batchSize: Int
    public var logger: ((String) -> Void)?

    public init(appKey: String,
                endpoint: URL = URL(string: "https://one.adventuredigital.com/push/v1")!,
                environment: OnePushEnvironment = .auto,
                guestMode: Bool = true,
                attributionWindow: TimeInterval = 72 * 3600,
                batchSize: Int = 50,
                logger: ((String) -> Void)? = nil) {
        self.appKey = appKey
        self.endpoint = endpoint
        self.environment = environment
        self.guestMode = guestMode
        self.attributionWindow = attributionWindow
        self.batchSize = batchSize
        self.logger = logger
    }
}
