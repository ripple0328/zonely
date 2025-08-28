import XCTest
@testable import say_my_name

final class DeepLinkBuilderTests: XCTestCase {
    func testDeepLinkBuildsURL() {
        let entries = [
            NameEntry(displayName: "张三", items: [LangItem(bcp47: "zh-CN", text: "张三"), LangItem(bcp47: "en-US", text: "San Zhang")])
        ]
        let url = DeepLinkBuilder.url(for: entries)
        XCTAssertTrue(url.absoluteString.contains("?s="))
    }
}


