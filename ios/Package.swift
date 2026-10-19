// swift-tools-version:5.9
// Ad Venture One Push — iOS çekirdeği.
// Firebase'e DOĞRUDAN bağımlı değil (misafir modu: token ve uygulama örneği kimliği
// dışarıdan verilir; OnePushFirebase adaptörü ayrı üründür). Böylece çekirdek
// macOS'ta Xcode'suz derlenir ve sınanır; iOS'a özgü parçalar `#if canImport`.
//
// Testler: `swift run OnePushChecks` (Command Line Tools yeter). XCTest/swift-testing
// yalnız Xcode'la gelir; Checks/MiniXCTest o alt kümeyi aynı adlarla verir, test
// dosyası XCTest biçimindedir ve Xcode'lu makinede test hedefine taşınır.
import PackageDescription

let package = Package(
    name: "OnePush",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "OnePush", targets: ["OnePush"]),
    ],
    targets: [
        .target(name: "OnePush", path: "Sources/OnePush"),
        .target(name: "MiniXCTest", path: "Checks/MiniXCTest"),
        .executableTarget(name: "OnePushChecks", dependencies: ["OnePush", "MiniXCTest"], path: "Checks/OnePushChecks"),
    ],
    swiftLanguageVersions: [.v5]
)
