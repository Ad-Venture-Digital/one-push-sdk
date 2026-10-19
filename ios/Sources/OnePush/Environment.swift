import Foundation

/// Çalışma ortamı tespiti. Saf fonksiyon ayrı tutuldu ki macOS'ta test edilsin.
enum EnvironmentDetector {
    /// - debugBuild: derleme bayrağı (#if DEBUG)
    /// - receiptName: `Bundle.main.appStoreReceiptURL?.lastPathComponent`
    ///   TestFlight ve geliştirici dağıtımında "sandboxReceipt", mağazada "receipt".
    /// - hasEmbeddedProvision: pakette `embedded.mobileprovision` var mı (Ad Hoc / geliştirme)
    static func detect(debugBuild: Bool, receiptName: String?, hasEmbeddedProvision: Bool) -> OnePushEnvironment {
        if debugBuild { return .debug }
        if receiptName == "sandboxReceipt" || hasEmbeddedProvision { return .testFlight }
        return .store
    }

    static func current() -> OnePushEnvironment {
        #if DEBUG
        let debug = true
        #else
        let debug = false
        #endif
        let receipt = Bundle.main.appStoreReceiptURL?.lastPathComponent
        let provision = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") != nil
        return detect(debugBuild: debug, receiptName: receipt, hasEmbeddedProvision: provision)
    }
}
