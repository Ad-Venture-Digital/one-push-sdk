// swift-tools-version:5.9
// OnePushFirebase — çekirdeği Firebase'e bağlayan adaptör. AYRI paket, çünkü
// firebase-ios-sdk ağır bir bağımlılıktır ve çekirdeğin Xcode'suz, hızlı
// derlenip sınanması korunmalı. Uygulama ikisini birden ekler.
import PackageDescription

let package = Package(
    name: "OnePushFirebase",
    platforms: [.iOS(.v15), .macOS(.v12)],   // macOS: Xcode'suz makinede derleme kontrolü için; Firebase macOS'u destekler
    products: [
        .library(name: "OnePushFirebase", targets: ["OnePushFirebase"]),
    ],
    dependencies: [
        .package(path: "../ios"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "OnePushFirebase",
            dependencies: [
                .product(name: "OnePush", package: "ios"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
            ],
            path: "Sources/OnePushFirebase"),
    ],
    swiftLanguageVersions: [.v5]
)
