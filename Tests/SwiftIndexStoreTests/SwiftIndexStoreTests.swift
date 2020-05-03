import XCTest
@testable import SwiftIndexStore

final class SwiftIndexStoreTests: XCTestCase {
    func testExample() throws {
        let space = try IndexSpace.create(with: .init())
        try space.index(
            name: "ViewController.swift",
            sourceCode: """
class ViewController {
  let name: String = ""
}
"""
        )
        let lib = try LibIndexStore.open()
        let indexStore = try IndexStore.open(store: space.indexStorePath, lib: lib)
        let units = indexStore.units()
        XCTAssertTrue(units.contains(where: { $0.name.contains("ViewController") }))
    }
}
