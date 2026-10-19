// MiniXCTest — Xcode'suz makinede (yalnız Command Line Tools) XCTest ve swift-testing
// yok; `swift test` çalışmaz. Bu kabuk XCTest'in kullandığımız alt kümesini aynı
// adlarla verir ki test dosyası XCTest biçiminde kalsın ve Xcode geldiğinde
// `import MiniXCTest` → `import XCTest` ile birebir taşınsın. Bir test çerçevesi
// değil, geçici bir köprüdür.
import Foundation

public struct TestFailure { public let message: String; public let file: String; public let line: UInt }

public enum MiniXCTest {
    public static var failures: [TestFailure] = []
    public static var assertions = 0
    static func fail(_ message: String, _ file: StaticString, _ line: UInt) {
        failures.append(TestFailure(message: message, file: "\(file)", line: line))
    }
}

open class XCTestCase {
    public init() {}
    open func setUp() {}
    open func tearDown() {}
}

public func XCTAssertEqual<T: Equatable>(_ a: @autoclosure () -> T, _ b: @autoclosure () -> T, _ message: String = "",
                                          file: StaticString = #filePath, line: UInt = #line) {
    MiniXCTest.assertions += 1
    let x = a(), y = b()
    if x != y { MiniXCTest.fail("XCTAssertEqual failed: (\(x)) != (\(y)) \(message)", file, line) }
}

public func XCTAssertTrue(_ v: @autoclosure () -> Bool, _ message: String = "",
                          file: StaticString = #filePath, line: UInt = #line) {
    MiniXCTest.assertions += 1
    if !v() { MiniXCTest.fail("XCTAssertTrue failed \(message)", file, line) }
}

public func XCTAssertFalse(_ v: @autoclosure () -> Bool, _ message: String = "",
                           file: StaticString = #filePath, line: UInt = #line) {
    MiniXCTest.assertions += 1
    if v() { MiniXCTest.fail("XCTAssertFalse failed \(message)", file, line) }
}

public func XCTAssertNil(_ v: @autoclosure () -> Any?, _ message: String = "",
                         file: StaticString = #filePath, line: UInt = #line) {
    MiniXCTest.assertions += 1
    if let x = v() { MiniXCTest.fail("XCTAssertNil failed: \(x) \(message)", file, line) }
}

public func XCTAssertNotNil(_ v: @autoclosure () -> Any?, _ message: String = "",
                            file: StaticString = #filePath, line: UInt = #line) {
    MiniXCTest.assertions += 1
    if v() == nil { MiniXCTest.fail("XCTAssertNotNil failed \(message)", file, line) }
}

/// Koşucu: her test için yeni örnek, setUp → test → tearDown; başarısızlıkları basar.
public func runTests<C: XCTestCase>(_ make: @escaping () -> C, _ tests: [(String, (C) -> () -> Void)]) -> Int32 {
    var failed = 0
    for (name, t) in tests {
        let before = MiniXCTest.failures.count
        let c = make()
        c.setUp(); t(c)(); c.tearDown()
        let new = MiniXCTest.failures[before...]
        if new.isEmpty { print("✓ \(name)") } else {
            failed += 1
            print("✗ \(name)")
            for f in new { print("    \(f.file):\(f.line): \(f.message)") }
        }
    }
    print("\(tests.count) test, \(tests.count - failed) geçti, \(failed) kırmızı, \(MiniXCTest.assertions) assert")
    return failed == 0 ? 0 : 1
}
