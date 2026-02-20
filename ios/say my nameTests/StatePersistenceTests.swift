import XCTest
@testable import say_my_name

final class StatePersistenceTests: XCTestCase {
    func testStoreAndRestore() {
        let p = StatePersistence()
        let entries = [NameEntry(displayName: "Alice", items: [LangItem(bcp47: "en-US", text: "Alice")])]
        p.store(entries)
        let restored = p.restore()
        XCTAssertEqual(restored?.count, 1)
        XCTAssertEqual(restored?.first?.displayName, "Alice")
    }
}


