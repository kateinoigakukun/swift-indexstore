import XCTest
@testable import SwiftIndexStore

final class SwiftIndexStoreTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(SwiftIndexStore().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
