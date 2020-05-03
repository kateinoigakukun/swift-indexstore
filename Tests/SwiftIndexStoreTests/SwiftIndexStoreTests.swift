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
        var units: [IndexStoreUnit] = []
        indexStore.forEachUnits { unit -> Bool in
            units.append(unit)
            return true
        }
        XCTAssertTrue(units.contains(where: { $0.name.contains("ViewController") }))
    }
}
