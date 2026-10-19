import Foundation

/// Çekirdek durum makinesi. `OnePush` yüzeyi bunun üstündeki ince kabuktur;
/// testler bunu sahte taşıma ve geçici dizinle kurar.
public final class OnePushClient {
    struct State: Codable, Equatable {
        var token: String?
        var appInstanceId: String?
        var userId: String?
        var attributes: [String: String] = [:]
        var tags: [String] = []
        var consent: Bool = true
        var permission: String = "unknown"
        var lastOpenedPushId: String?
        var lastOpenedAt: Date?
        var registrationPending: Bool = false
    }

    public let config: OnePushConfig
    let transport: OnePushTransport
    let queue: EventQueue
    let inbox: InboxStore
    private let stateURL: URL
    private let deviceInfo: DeviceInfo
    private let environment: OnePushEnvironment
    private let bundleId: String
    private let now: () -> Date
    private let lock = NSLock()
    private var state: State
    private var inFlight = false

    /// GA4 köprüsü: açılışta `one_push_open{push_id, push_turu, kampanya_id}` yazılır.
    /// Firebase adaptörü bunu `Analytics.logEvent` ile bağlar; çekirdek Firebase bilmez.
    public var analyticsLogger: ((String, [String: String]) -> Void)?

    init(config: OnePushConfig, transport: OnePushTransport, storageDirectory: URL,
         deviceInfo: DeviceInfo = .current(), environment: OnePushEnvironment? = nil,
         bundleId: String = Bundle.main.bundleIdentifier ?? "unknown",
         now: @escaping () -> Date = Date.init) {
        self.config = config
        self.transport = transport
        self.deviceInfo = deviceInfo
        self.bundleId = bundleId
        self.now = now
        self.environment = environment ?? (config.environment == .auto ? EnvironmentDetector.current() : config.environment)
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        stateURL = storageDirectory.appendingPathComponent("state.json")
        queue = EventQueue(directory: storageDirectory)
        inbox = InboxStore(directory: storageDirectory)
        if let d = try? Data(contentsOf: stateURL), let s = try? JSONDecoder.onePush.decode(State.self, from: d) {
            state = s
        } else {
            state = State()
        }
    }

    public var currentEnvironment: OnePushEnvironment { environment }

    // MARK: - kimlik ve özellikler

    /// FCM token'ı. Misafir modunda uygulamanın mevcut `didReceiveRegistrationToken`
    /// işleyicisinden gelir; token ortaktır, sağlayıcılar yarışmaz (K12).
    public func setPushToken(_ token: String) { mutate { $0.token = token } }
    public func setAppInstanceId(_ id: String) { mutate { $0.appInstanceId = id } }
    public func setUserId(_ id: String?) { mutate { $0.userId = id } }
    public func setUserAttribute(_ key: String, _ value: String?) {
        mutate { if let v = value { $0.attributes[key] = v } else { $0.attributes.removeValue(forKey: key) } }
    }
    public func addTag(_ tag: String) { mutate { if !$0.tags.contains(tag) { $0.tags.append(tag) } } }
    public func removeTag(_ tag: String) { mutate { $0.tags.removeAll { $0 == tag } } }
    public func setPermission(_ status: String) { mutate { $0.permission = status } }

    /// KVKK onayı. Kapatılınca kayıt sunucudan SİLİNİR, olay gönderilmez (K7).
    public func setConsent(_ granted: Bool) {
        let token = lock.withLock { state.token }
        if !granted, let t = token {
            lock.withLock { state.consent = false; state.registrationPending = false; persistLocked() }
            queue.removeAll()
            transport.send(path: "register", method: "DELETE", body: ["token": t], headers: headers()) { _ in }
            return
        }
        mutate { $0.consent = granted }
    }

    private func mutate(_ change: (inout State) -> Void) {
        lock.lock()
        let before = state
        change(&state)
        let changed = state != before
        if changed { state.registrationPending = true; persistLocked() }
        lock.unlock()
        if changed { flush() }
    }

    // MARK: - push olayları

    /// Gelen bildirim bizimse işler ve `true` döner; değilse DOKUNMAZ ve `false` döner —
    /// uygulama onu öteki sağlayıcıya verir (misafir modu).
    @discardableResult
    public func handle(_ userInfo: [AnyHashable: Any], opened: Bool) -> Bool {
        guard let p = OnePushPayload(userInfo: userInfo) else { return false }
        guard lock.withLock({ state.consent }) else { return true }
        let t = now()
        if opened {
            lock.withLock { state.lastOpenedPushId = p.pushId; state.lastOpenedAt = t; persistLocked() }
            inbox.upsert(p, at: t, read: true)
            queue.append(PushEvent(kind: .opened, pushId: p.pushId, eventName: nil, params: nil, ts: t, environment: environment))
            var params = ["push_id": p.pushId]
            if let k = p.pushType { params["push_turu"] = k }
            if let c = p.campaignId { params["kampanya_id"] = c }
            analyticsLogger?("one_push_open", params)
        } else {
            inbox.upsert(p, at: t, read: false)
            queue.append(PushEvent(kind: .delivered, pushId: p.pushId, eventName: nil, params: nil, ts: t, environment: environment))
        }
        flush()
        return true
    }

    /// Dönüşüm kancası: son açılıştan `attributionWindow` içindeyse o push'a bağlanır.
    public func track(_ event: String, params: [String: String] = [:]) {
        guard lock.withLock({ state.consent }) else { return }
        let t = now()
        let pid: String? = lock.withLock {
            guard let at = state.lastOpenedAt, t.timeIntervalSince(at) <= config.attributionWindow else { return nil }
            return state.lastOpenedPushId
        }
        queue.append(PushEvent(kind: .track, pushId: pid, eventName: event, params: params.isEmpty ? nil : params,
                               ts: t, environment: environment))
        flush()
    }

    public func inboxItems(limit: Int = 50) -> [InboxItem] { inbox.list(limit: limit) }
    public func markInboxRead(_ pushId: String) { inbox.markRead(pushId) }

    // MARK: - gönderim

    func headers() -> [String: String] {
        ["X-One-App-Key": config.appKey, "X-One-Bundle-Id": bundleId, "X-One-SDK": "ios/\(onePushSDKVersion)"]
    }

    func registrationPayload() -> RegistrationPayload? {
        lock.withLock {
            guard let t = state.token else { return nil }
            return RegistrationPayload(token: t, appInstanceId: state.appInstanceId, userId: state.userId,
                                       attributes: state.attributes, tags: state.tags,
                                       locale: deviceInfo.locale, timeZone: deviceInfo.timeZone,
                                       appVersion: deviceInfo.appVersion, osVersion: deviceInfo.osVersion,
                                       deviceModel: deviceInfo.deviceModel, environment: environment,
                                       consent: state.consent, permission: state.permission)
        }
    }

    /// Önce bekleyen kayıt, sonra olay partileri. Başarısız parti kuyrukta kalır.
    public func flush(completion: (() -> Void)? = nil) {
        let shouldRun: Bool = lock.withLock { if inFlight { return false }; inFlight = true; return true }
        guard shouldRun else { completion?(); return }
        let finish = { [weak self] in
            self?.lock.withLock { self?.inFlight = false }
            completion?()
        }
        let pending = lock.withLock { state.registrationPending }
        if pending, let payload = registrationPayload() {
            transport.send(path: "register", method: "POST", body: payload.json(), headers: headers()) { [weak self] r in
                guard let self = self else { return }
                if case .success = r { self.lock.withLock { self.state.registrationPending = false; self.persistLocked() } }
                else { self.config.logger?("One Push: kayıt gönderilemedi, yeniden denenecek") }
                self.drain(finish)
            }
        } else {
            drain(finish)
        }
    }

    private func drain(_ done: @escaping () -> Void) {
        let batch = queue.peek(config.batchSize)
        guard !batch.isEmpty else { done(); return }
        let body: [String: Any] = ["events": batch.map { e -> [String: Any] in
            var d: [String: Any] = ["type": e.kind.rawValue, "ts": ISO8601DateFormatter().string(from: e.ts),
                                    "environment": e.environment.rawValue]
            if let p = e.pushId { d["push_id"] = p }
            if let n = e.eventName { d["event_name"] = n }
            if let pr = e.params { d["params"] = pr }
            return d
        }]
        transport.send(path: "event", method: "POST", body: body, headers: headers()) { [weak self] r in
            guard let self = self else { return }
            switch r {
            case .success:
                self.queue.commit(batch.count)
                if self.queue.count > 0 { self.drain(done) } else { done() }
            case .failure:
                self.config.logger?("One Push: \(batch.count) olay gönderilemedi, kuyrukta")
                done()
            }
        }
    }

    private func persistLocked() {
        if let d = try? JSONEncoder.onePush.encode(state) { try? d.write(to: stateURL, options: .atomic) }
    }

    // test ve teşhis
    var snapshot: State { lock.withLock { state } }
}

extension NSLock {
    func withLock<T>(_ body: () -> T) -> T { lock(); defer { unlock() }; return body() }
}
