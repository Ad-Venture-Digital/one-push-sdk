import Flutter
import UIKit
import OnePush

/// Flutter köprüsü (iOS). Kanal adı Dart tarafıyla birebir.
public class OnePushFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.adventure.onepush/flutter", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(OnePushFlutterPlugin(), channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let a = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "start":
            guard let key = a["appKey"] as? String else { result(FlutterError(code: "arg", message: "appKey gerekli", details: nil)); return }
            var cfg = OnePushConfig(appKey: key)
            if let e = a["endpoint"] as? String, let u = URL(string: e) { cfg.endpoint = u }
            if let env = a["environment"] as? String, let v = OnePushEnvironment(rawValue: env) { cfg.environment = v }
            if let g = a["guestMode"] as? Bool { cfg.guestMode = g }
            OnePush.start(cfg); result(nil)
        case "setPushToken": OnePush.setPushToken(a["token"] as? String ?? ""); result(nil)
        case "setAppInstanceId": OnePush.setAppInstanceId(a["id"] as? String ?? ""); result(nil)
        case "setUserId": OnePush.setUserId(a["id"] as? String ?? ""); result(nil)
        case "clearUserId": OnePush.clearUserId(); result(nil)
        case "setUserAttribute": OnePush.setUserAttribute(a["key"] as? String ?? "", a["value"] as? String); result(nil)
        case "addTag": OnePush.addTag(a["tag"] as? String ?? ""); result(nil)
        case "removeTag": OnePush.removeTag(a["tag"] as? String ?? ""); result(nil)
        case "setConsent": OnePush.setConsent(a["granted"] as? Bool ?? true); result(nil)
        case "track": OnePush.track(a["event"] as? String ?? "", a["params"] as? [String: String] ?? [:]); result(nil)
        case "flush": OnePush.flush(); result(nil)
        case "handle": result(OnePush.handle(a["data"] as? [String: Any] ?? [:]))
        case "didOpen": result(OnePush.didOpen(a["data"] as? [String: Any] ?? [:]))
        case "inbox":
            result(OnePush.inbox.prefix(a["limit"] as? Int ?? 50).map { i -> [String: Any?] in
                ["push_id": i.pushId, "title": i.title, "body": i.body, "deep_link": i.deepLink?.absoluteString,
                 "received_at": Int(i.receivedAt.timeIntervalSince1970 * 1000), "read": i.read] })
        case "markInboxRead": OnePush.markInboxRead(a["pushId"] as? String ?? ""); result(nil)
        case "requestPermission": OnePush.requestPermission { granted in result(granted) }
        case "refreshPermissionStatus": OnePush.refreshPermissionStatus(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
    }
}
