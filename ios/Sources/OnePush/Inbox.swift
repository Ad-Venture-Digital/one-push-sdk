import Foundation

/// Bildirim kutusu kaydı (K16). İlk sürümde YEREL: cihaz, aldığı One push'larını
/// saklar; sunucu kutusu (`GET /push/v1/inbox`) sonraki sürüm.
public struct InboxItem: Codable, Equatable {
    public let pushId: String
    public let title: String?
    public let body: String?
    public let deepLink: URL?
    public let receivedAt: Date
    public var read: Bool
}

final class InboxStore {
    static let capacity = 200
    private let fileURL: URL
    private let lock = NSLock()
    private var items: [InboxItem] = []

    init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("inbox.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder.onePush.decode([InboxItem].self, from: data) {
            items = saved
        }
    }

    func upsert(_ payload: OnePushPayload, at date: Date, read: Bool) {
        lock.lock(); defer { lock.unlock() }
        if let i = items.firstIndex(where: { $0.pushId == payload.pushId }) {
            if read { items[i].read = true }
        } else {
            items.insert(InboxItem(pushId: payload.pushId, title: payload.title, body: payload.body,
                                   deepLink: payload.deepLink, receivedAt: date, read: read), at: 0)
            if items.count > InboxStore.capacity { items.removeLast(items.count - InboxStore.capacity) }
        }
        persistLocked()
    }

    func markRead(_ pushId: String) {
        lock.lock(); defer { lock.unlock() }
        if let i = items.firstIndex(where: { $0.pushId == pushId }) { items[i].read = true; persistLocked() }
    }

    func list(limit: Int = 50) -> [InboxItem] {
        lock.lock(); defer { lock.unlock() }
        return Array(items.prefix(limit))
    }

    func removeAll() { lock.lock(); items.removeAll(); persistLocked(); lock.unlock() }

    private func persistLocked() {
        if let d = try? JSONEncoder.onePush.encode(items) { try? d.write(to: fileURL, options: .atomic) }
    }
}
