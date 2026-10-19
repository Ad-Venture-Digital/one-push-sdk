import Foundation

public enum TransportError: Error, Equatable {
    case http(Int)
    case network(String)
}

/// Sunucu ucu: `POST <endpoint>/<path>`. Testler sahtesini enjekte eder.
public protocol OnePushTransport {
    func send(path: String, method: String, body: [String: Any], headers: [String: String],
              completion: @escaping (Result<[String: Any], TransportError>) -> Void)
}

/// URLSession ile JSON. Uygulama anahtarı ve paket adı BAŞLIKTA (sunucu eşler, K15).
final class URLSessionTransport: OnePushTransport {
    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func send(path: String, method: String, body: [String: Any], headers: [String: String],
              completion: @escaping (Result<[String: Any], TransportError>) -> Void) {
        var req = URLRequest(url: endpoint.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        session.dataTask(with: req) { data, resp, err in
            if let err = err { completion(.failure(.network(err.localizedDescription))); return }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(code) else { completion(.failure(.http(code))); return }
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
            completion(.success(json))
        }.resume()
    }
}
