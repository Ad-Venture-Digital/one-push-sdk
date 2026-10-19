import Foundation
import MiniXCTest   // Xcode gelince: import XCTest
@testable import OnePush

/// Sahte taşıma: çağrıları kaydeder, istenen cevabı verir (gerçeğin yüzeyi: path, method, body, headers).
final class FakeTransport: OnePushTransport {
    struct Call { let path: String; let method: String; let body: [String: Any]; let headers: [String: String] }
    var calls: [Call] = []
    var failNext = 0
    func send(path: String, method: String, body: [String: Any], headers: [String: String],
              completion: @escaping (Result<[String: Any], TransportError>) -> Void) {
        calls.append(Call(path: path, method: method, body: body, headers: headers))
        if failNext > 0 { failNext -= 1; completion(.failure(.http(503))); return }
        completion(.success(["ok": true]))
    }
    func paths() -> [String] { calls.map { "\($0.method) \($0.path)" } }
}

final class OnePushTests: XCTestCase {
    var dir: URL!
    var transport: FakeTransport!
    var clock = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("onepush-test-\(UUID().uuidString)")
        transport = FakeTransport()
    }

    func makeClient(consent: Bool = true, env: OnePushEnvironment = .testFlight) -> OnePushClient {
        let cfg = OnePushConfig(appKey: "app_abc", environment: env, attributionWindow: 3600)
        let info = DeviceInfo(appVersion: "1.2 (34)", osVersion: "17.1.0", deviceModel: "iPhone15,2",
                              locale: "tr_TR", timeZone: "Europe/Istanbul")
        let c = OnePushClient(config: cfg, transport: transport, storageDirectory: dir, deviceInfo: info,
                              environment: env, bundleId: "com.lumvio.app", now: { self.clock })
        if !consent { c.setConsent(false) }
        return c
    }

    // MARK: payload
    func test_payload_isareti_ve_aps_alert_yedegi() {
        let info: [AnyHashable: Any] = ["one_push_id": "p1", "one_push_turu": "promosyon",
                                        "aps": ["alert": ["title": "Başlık", "body": "Metin"]]]
        let p = OnePushPayload(userInfo: info)!
        XCTAssertEqual(p.pushId, "p1"); XCTAssertEqual(p.pushType, "promosyon")
        XCTAssertEqual(p.title, "Başlık"); XCTAssertEqual(p.body, "Metin")
        XCTAssertTrue(OnePushPayload.isOnePush(info))
        XCTAssertFalse(OnePushPayload.isOnePush(["custom": ["i": "onesignal-id"]]))   // öteki sağlayıcı
        XCTAssertNil(OnePushPayload(userInfo: ["one_push_id": ""]))
    }

    // MARK: ortam
    func test_ortam_tespiti_debug_testflight_store() {
        XCTAssertEqual(EnvironmentDetector.detect(debugBuild: true, receiptName: "receipt", hasEmbeddedProvision: false), .debug)
        XCTAssertEqual(EnvironmentDetector.detect(debugBuild: false, receiptName: "sandboxReceipt", hasEmbeddedProvision: false), .testFlight)
        XCTAssertEqual(EnvironmentDetector.detect(debugBuild: false, receiptName: "receipt", hasEmbeddedProvision: true), .testFlight)
        XCTAssertEqual(EnvironmentDetector.detect(debugBuild: false, receiptName: "receipt", hasEmbeddedProvision: false), .store)
        XCTAssertEqual(OnePushEnvironment.store.rawValue, "production")
    }

    // MARK: kuyruk
    func test_kuyruk_diske_yazar_ve_yeniden_acilinca_okur() {
        let q = EventQueue(directory: dir)
        q.append(PushEvent(kind: .delivered, pushId: "a", eventName: nil, params: nil, ts: clock, environment: .store))
        q.append(PushEvent(kind: .track, pushId: nil, eventName: "purchase", params: ["v": "9"], ts: clock, environment: .store))
        let q2 = EventQueue(directory: dir)
        XCTAssertEqual(q2.count, 2)
        XCTAssertEqual(q2.peek(1).first?.pushId, "a")
        q2.commit(1)
        XCTAssertEqual(EventQueue(directory: dir).count, 1)
    }

    // MARK: kayıt
    func test_token_gelmeden_kayit_gitmez_gelince_basliklarla_gider() {
        let c = makeClient()
        c.setUserId("u1")
        XCTAssertTrue(transport.calls.isEmpty)
        c.setPushToken("tok1")
        XCTAssertEqual(transport.paths(), ["POST register"])
        let call = transport.calls[0]
        XCTAssertEqual(call.headers["X-One-App-Key"], "app_abc")
        XCTAssertEqual(call.headers["X-One-Bundle-Id"], "com.lumvio.app")
        XCTAssertEqual(call.body["token"] as? String, "tok1")
        XCTAssertEqual(call.body["user_id"] as? String, "u1")
        XCTAssertEqual(call.body["environment"] as? String, "test")
        XCTAssertEqual(call.body["consent"] as? Bool, true)
        XCTAssertEqual(call.body["sdk_version"] as? String, onePushSDKVersion)
        XCTAssertFalse(c.snapshot.registrationPending)
    }

    func test_ozellik_ve_etiket_degisince_yeniden_kayit_ayni_deger_gondermez() {
        let c = makeClient(); c.setPushToken("tok1")
        c.setUserAttribute("plan", "pro"); c.addTag("vip"); c.addTag("vip")
        XCTAssertEqual(transport.paths().filter { $0 == "POST register" }.count, 3)
        let son = transport.calls.last!
        XCTAssertEqual((son.body["attributes"] as? [String: String])?["plan"], "pro")
        XCTAssertEqual(son.body["tags"] as? [String], ["vip"])
        c.removeTag("vip"); c.setUserAttribute("plan", nil)
        XCTAssertEqual(transport.calls.last?.body["tags"] as? [String], [])
        XCTAssertEqual((transport.calls.last?.body["attributes"] as? [String: String])?.count, 0)
    }

    func test_kayit_dusunce_bekler_sonraki_flush_yeniden_dener() {
        transport.failNext = 1
        let c = makeClient(); c.setPushToken("tok1")
        XCTAssertTrue(c.snapshot.registrationPending)
        c.flush()
        XCTAssertFalse(c.snapshot.registrationPending)
        XCTAssertEqual(transport.paths(), ["POST register", "POST register"])
    }

    // MARK: olaylar
    func test_bizim_olmayan_payload_DOKUNULMAZ_false_doner() {
        let c = makeClient(); c.setPushToken("t")
        let n = transport.calls.count
        XCTAssertFalse(c.handle(["custom": ["i": "x"], "aps": ["alert": "y"]], opened: false))
        XCTAssertEqual(transport.calls.count, n)
        XCTAssertTrue(c.inboxItems().isEmpty)
    }

    func test_alindi_olayi_kutuya_ve_sunucuya_gider() {
        let c = makeClient(); c.setPushToken("t")
        XCTAssertTrue(c.handle(["one_push_id": "p9", "one_baslik": "Kampanya", "one_metin": "Bugün"], opened: false))
        XCTAssertEqual(transport.paths().last, "POST event")
        XCTAssertEqual(transport.calls.last!.headers["X-One-Device-Token"], "t")
        let events = transport.calls.last!.body["events"] as! [[String: Any]]
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0]["type"] as? String, "delivered")
        XCTAssertEqual(events[0]["push_id"] as? String, "p9")
        XCTAssertEqual(events[0]["environment"] as? String, "test")
        XCTAssertEqual(c.inboxItems().first?.title, "Kampanya")
        XCTAssertEqual(c.inboxItems().first?.read, false)
        XCTAssertEqual(c.queue.count, 0)
    }

    func test_acilis_GA4_koprusunu_cagirir_ve_kutuyu_okundu_yapar() {
        let c = makeClient(); c.setPushToken("t")
        var logged: (String, [String: String])?
        c.analyticsLogger = { logged = ($0, $1) }
        c.handle(["one_push_id": "p1", "one_push_turu": "geri_kazanim", "one_kampanya_id": "k7"], opened: false)
        c.handle(["one_push_id": "p1", "one_push_turu": "geri_kazanim", "one_kampanya_id": "k7"], opened: true)
        XCTAssertEqual(logged?.0, "one_push_open")
        XCTAssertEqual(logged?.1, ["push_id": "p1", "push_turu": "geri_kazanim", "kampanya_id": "k7"])
        XCTAssertEqual(c.inboxItems().count, 1)
        XCTAssertEqual(c.inboxItems().first?.read, true)
        let turler = transport.calls.filter { $0.path == "event" }
            .flatMap { ($0.body["events"] as! [[String: Any]]).map { $0["type"] as! String } }
        XCTAssertEqual(turler, ["delivered", "opened"])
    }

    func test_track_pencere_icinde_push_a_baglanir_disinda_baglanmaz() {
        let c = makeClient(); c.setPushToken("t")
        c.handle(["one_push_id": "p1"], opened: true)
        c.track("purchase", params: ["value": "199"])
        var e = (transport.calls.last!.body["events"] as! [[String: Any]])[0]
        XCTAssertEqual(e["type"] as? String, "track"); XCTAssertEqual(e["push_id"] as? String, "p1")
        XCTAssertEqual((e["params"] as? [String: String])?["value"], "199")
        clock = clock.addingTimeInterval(3601)                       // pencere 3600 sn
        c.track("purchase")
        e = (transport.calls.last!.body["events"] as! [[String: Any]])[0]
        XCTAssertNil(e["push_id"])
    }

    func test_onay_kapaninca_kayit_SILINIR_olay_gitmez_acilinca_yeniden_kayit() {
        let c = makeClient(); c.setPushToken("t")
        c.setConsent(false)
        XCTAssertEqual(transport.paths().last, "DELETE register")
        XCTAssertEqual(transport.calls.last?.body["token"] as? String, "t")
        let n = transport.calls.count
        XCTAssertTrue(c.handle(["one_push_id": "p1"], opened: true))   // bizim, ama kayıt YOK
        c.track("purchase")
        XCTAssertEqual(transport.calls.count, n)
        XCTAssertEqual(c.queue.count, 0)
        c.setConsent(true)
        XCTAssertEqual(transport.paths().last, "POST register")
        XCTAssertEqual(transport.calls.last?.body["consent"] as? Bool, true)
    }

    func test_gonderim_dusunce_olaylar_kuyrukta_KALIR_sonra_bosalir() {
        let c = makeClient(); c.setPushToken("t")
        transport.failNext = 1
        c.handle(["one_push_id": "p1"], opened: false)
        XCTAssertEqual(c.queue.count, 1)
        c.handle(["one_push_id": "p2"], opened: false)                // başarılı: ikisi tek partide
        XCTAssertEqual(c.queue.count, 0)
        let son = transport.calls.last!.body["events"] as! [[String: Any]]
        XCTAssertEqual(son.map { $0["push_id"] as! String }, ["p1", "p2"])
    }

    func test_durum_diske_yazilir_yeniden_acilinca_token_ve_kullanici_durur() {
        let c = makeClient(); c.setPushToken("t"); c.setUserId("u")
        let c2 = makeClient()
        XCTAssertEqual(c2.snapshot.token, "t"); XCTAssertEqual(c2.snapshot.userId, "u")
    }

    func test_facade_start_olmadan_cokmez() {
        OnePush.use(makeClient())
        XCTAssertFalse(OnePush.isOnePushMessage(["x": 1]))
        OnePush.setPushToken("tok")
        XCTAssertEqual(transport.paths(), ["POST register"])
    }

    static let all: [(String, (OnePushTests) -> () -> Void)] = [
        ("test_payload_isareti_ve_aps_alert_yedegi", OnePushTests.test_payload_isareti_ve_aps_alert_yedegi),
        ("test_ortam_tespiti_debug_testflight_store", OnePushTests.test_ortam_tespiti_debug_testflight_store),
        ("test_kuyruk_diske_yazar_ve_yeniden_acilinca_okur", OnePushTests.test_kuyruk_diske_yazar_ve_yeniden_acilinca_okur),
        ("test_token_gelmeden_kayit_gitmez_gelince_basliklarla_gider", OnePushTests.test_token_gelmeden_kayit_gitmez_gelince_basliklarla_gider),
        ("test_ozellik_ve_etiket_degisince_yeniden_kayit_ayni_deger_gondermez", OnePushTests.test_ozellik_ve_etiket_degisince_yeniden_kayit_ayni_deger_gondermez),
        ("test_kayit_dusunce_bekler_sonraki_flush_yeniden_dener", OnePushTests.test_kayit_dusunce_bekler_sonraki_flush_yeniden_dener),
        ("test_bizim_olmayan_payload_DOKUNULMAZ_false_doner", OnePushTests.test_bizim_olmayan_payload_DOKUNULMAZ_false_doner),
        ("test_alindi_olayi_kutuya_ve_sunucuya_gider", OnePushTests.test_alindi_olayi_kutuya_ve_sunucuya_gider),
        ("test_acilis_GA4_koprusunu_cagirir_ve_kutuyu_okundu_yapar", OnePushTests.test_acilis_GA4_koprusunu_cagirir_ve_kutuyu_okundu_yapar),
        ("test_track_pencere_icinde_push_a_baglanir_disinda_baglanmaz", OnePushTests.test_track_pencere_icinde_push_a_baglanir_disinda_baglanmaz),
        ("test_onay_kapaninca_kayit_SILINIR_olay_gitmez_acilinca_yeniden_kayit", OnePushTests.test_onay_kapaninca_kayit_SILINIR_olay_gitmez_acilinca_yeniden_kayit),
        ("test_gonderim_dusunce_olaylar_kuyrukta_KALIR_sonra_bosalir", OnePushTests.test_gonderim_dusunce_olaylar_kuyrukta_KALIR_sonra_bosalir),
        ("test_durum_diske_yazilir_yeniden_acilinca_token_ve_kullanici_durur", OnePushTests.test_durum_diske_yazilir_yeniden_acilinca_token_ve_kullanici_durur),
        ("test_facade_start_olmadan_cokmez", OnePushTests.test_facade_start_olmadan_cokmez),
    ]
}
