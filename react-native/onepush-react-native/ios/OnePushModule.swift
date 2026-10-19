import Foundation
import OnePush

/// React Native köprüsü (iOS). Metot adları src/index.ts ile birebir.
@objc(OnePushModule)
final class OnePushModule: NSObject {
    @objc func start(_ cfg: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let key = cfg["appKey"] as? String else { reject("arg", "appKey gerekli", nil); return }
        var c = OnePushConfig(appKey: key)
        if let e = cfg["endpoint"] as? String, let u = URL(string: e) { c.endpoint = u }
        if let env = cfg["environment"] as? String, let v = OnePushEnvironment(rawValue: env) { c.environment = v }
        if let g = cfg["guestMode"] as? Bool { c.guestMode = g }
        OnePush.start(c); resolve(nil)
    }
    @objc func setPushToken(_ t: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.setPushToken(t); resolve(nil) }
    @objc func setAppInstanceId(_ id: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.setAppInstanceId(id); resolve(nil) }
    @objc func setUserId(_ id: String?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        if let id = id { OnePush.setUserId(id) } else { OnePush.clearUserId() }; resolve(nil)
    }
    @objc func setUserAttribute(_ key: String, value: String?, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.setUserAttribute(key, value); resolve(nil) }
    @objc func addTag(_ t: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.addTag(t); resolve(nil) }
    @objc func removeTag(_ t: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.removeTag(t); resolve(nil) }
    @objc func setConsent(_ g: Bool, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.setConsent(g); resolve(nil) }
    @objc func track(_ e: String, params: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        OnePush.track(e, params as? [String: String] ?? [:]); resolve(nil)
    }
    @objc func flush(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.flush(); resolve(nil) }
    @objc func handle(_ data: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(OnePush.handle(data as? [AnyHashable: Any] ?? [:])) }
    @objc func didOpen(_ data: NSDictionary, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { resolve(OnePush.didOpen(data as? [AnyHashable: Any] ?? [:])) }
    @objc func inbox(_ limit: NSNumber, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        resolve(OnePush.inbox.prefix(limit.intValue).map { i -> [String: Any?] in
            ["pushId": i.pushId, "title": i.title, "body": i.body, "deepLink": i.deepLink?.absoluteString,
             "receivedAt": Int(i.receivedAt.timeIntervalSince1970 * 1000), "read": i.read] })
    }
    @objc func markInboxRead(_ id: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.markInboxRead(id); resolve(nil) }
    @objc func requestPermission(_ resolve: @escaping RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.requestPermission { resolve($0) } }
    @objc func refreshPermissionStatus(_ resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) { OnePush.refreshPermissionStatus(); resolve(nil) }
}
