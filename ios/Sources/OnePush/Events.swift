import Foundation

/// Sunucuya giden olay (docs/ONE_PUSH_PLANI.md bölüm 6).
public struct PushEvent: Codable, Equatable {
    public enum Kind: String, Codable { case delivered, opened, dismissed, track }
    public let kind: Kind
    public let pushId: String?
    public let eventName: String?
    public let params: [String: String]?
    public let ts: Date
    public let environment: OnePushEnvironment

    enum CodingKeys: String, CodingKey {
        case kind = "type", pushId = "push_id", eventName = "event_name", params, ts, environment
    }
}

/// Dosya destekli, ekleme-yalnız olay kuyruğu. Çevrimdışı birikir, parti parti
/// boşalır; gönderim düşerse olaylar kuyrukta KALIR (sessiz kayıp yok).
final class EventQueue {
    private let fileURL: URL
    private let lock = NSLock()
    private var items: [PushEvent] = []

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("events.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder.onePush.decode([PushEvent].self, from: data) {
            items = saved
        }
    }

    var count: Int { lock.lock(); defer { lock.unlock() }; return items.count }

    func append(_ e: PushEvent) {
        lock.lock(); items.append(e); persistLocked(); lock.unlock()
    }

    /// İlk `n` olayı verir; `commit` çağrılmadıkça kuyruktan düşmez.
    func peek(_ n: Int) -> [PushEvent] {
        lock.lock(); defer { lock.unlock() }
        return Array(items.prefix(n))
    }

    func commit(_ n: Int) {
        lock.lock(); items.removeFirst(min(n, items.count)); persistLocked(); lock.unlock()
    }

    func removeAll() {
        lock.lock(); items.removeAll(); persistLocked(); lock.unlock()
    }

    private func persistLocked() {
        if let data = try? JSONEncoder.onePush.encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}

extension JSONEncoder {
    static var onePush: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }
}

extension JSONDecoder {
    static var onePush: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
