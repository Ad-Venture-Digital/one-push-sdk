import Foundation

/// Kayıt gövdesi (sunucu API `POST /push/v1/register`). Saf: cihaz bilgisi
/// dışarıdan verilir ki test deterministik olsun.
struct RegistrationPayload: Equatable {
    var token: String
    var platform: String = "ios"
    var appInstanceId: String?
    var userId: String?
    var attributes: [String: String]
    var tags: [String]
    var locale: String
    var timeZone: String
    var appVersion: String
    var osVersion: String
    var deviceModel: String
    var environment: OnePushEnvironment
    var consent: Bool
    var permission: String   // granted | denied | not_determined | unknown

    func json() -> [String: Any] {
        var d: [String: Any] = [
            "token": token, "platform": platform, "attributes": attributes, "tags": tags.sorted(),
            "locale": locale, "tz": timeZone, "app_version": appVersion, "os_version": osVersion,
            "device_model": deviceModel, "environment": environment.rawValue, "consent": consent,
            "permission": permission, "sdk_version": onePushSDKVersion,
        ]
        if let a = appInstanceId { d["app_instance_id"] = a }
        if let u = userId { d["user_id"] = u }
        return d
    }
}

/// Uygulama ve cihaz bilgisi okuyucusu; iOS dışı derlemede makul değerler.
struct DeviceInfo {
    var appVersion: String
    var osVersion: String
    var deviceModel: String
    var locale: String
    var timeZone: String

    static func current() -> DeviceInfo {
        let v = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
        let b = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var model = "unknown"
        var sys = utsname(); uname(&sys)
        let mirror = Mirror(reflecting: sys.machine)
        let id = mirror.children.reduce(into: "") { acc, c in
            if let v = c.value as? Int8, v != 0 { acc.append(Character(UnicodeScalar(UInt8(v)))) }
        }
        if !id.isEmpty { model = id }
        return DeviceInfo(appVersion: "\(v) (\(b))",
                          osVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
                          deviceModel: model,
                          locale: Locale.current.identifier,
                          timeZone: TimeZone.current.identifier)
    }
}
