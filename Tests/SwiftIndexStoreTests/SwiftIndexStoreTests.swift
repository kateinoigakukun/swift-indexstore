import XCTest
@testable import SwiftIndexStore

final class SwiftIndexStoreTests: XCTestCase {
    static var indexStore: IndexStore!
    static var space: IndexSpace!

    var indexStore: IndexStore { Self.indexStore }

    override class func setUp() {
        space = try! IndexSpace.create(with: .init())
        try! space.addSource(name: "ViewController.swift",
                             module: "TestModule",
                             sourceCode: """
        class ViewController {
          let viewModel: ViewModel = .init()
          func load() {
            print(viewModel.name)
          }

          func getName() -> String {
            return viewModel.name
          }
        }
        """
        )
        try! space.addSource(name: "ViewModel.swift",
                             module: "TestModule",
                             sourceCode: """
        class ViewModel {
          let name: String = ""
        }
        """)
        try! space.addSource(name: "TestSystemImport.swift",
                             module: "TestModule",
                             sourceCode: "import TestSystemModule")
        try! space.index()
        let lib = try! LibIndexStore.open()
        indexStore = try! IndexStore.open(store: space.indexStorePath, lib: lib)
    }

    override class func tearDown() {
        indexStore = nil
        space = nil
    }

    func testUnits() {
        let unitsWithSystem = indexStore.units(includeSystem: true)
        XCTAssertTrue(unitsWithSystem.contains(where: { $0.name?.contains("ViewController") ?? false }))
        XCTAssertTrue(unitsWithSystem.contains(where: { $0.name?.contains("ViewModel") ?? false }))
        #if compiler(>=5.4)
        XCTAssertTrue(unitsWithSystem.contains(where: { $0.name?.contains("TestSystemImport") ?? false }))
        #else
        XCTAssertTrue(unitsWithSystem.contains(where: { $0.name?.contains("TestSystemModule") ?? false }))
        #endif

        let unitsWithoutSystem = indexStore.units(includeSystem: false)
        XCTAssertFalse(unitsWithoutSystem.contains(where: { $0.name?.contains("TestSystemModule") ?? true }))
    }

    func testUnitMainFilePath() throws {
        let units = indexStore.units()
        let unit = try XCTUnwrap(units.first { $0.name?.contains("ViewController") ?? false })
        let path = try XCTUnwrap(indexStore.mainFilePath(for: unit))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testUnitModuleName() throws {
        let units = indexStore.units()
        let unit = try XCTUnwrap(units.first { $0.name?.contains("ViewController") ?? false })
        let moduleName = try XCTUnwrap(indexStore.moduleName(for: unit))
        XCTAssertEqual(moduleName, "TestModule")
    }

    func testUnitTarget() throws {
        let units = indexStore.units()
        let unit = try XCTUnwrap(units.first { $0.name?.contains("ViewController") ?? false })
        let moduleName = try XCTUnwrap(indexStore.target(for: unit))
        XCTAssertNotNil(moduleName)
    }

    func testDependency() throws {
        let unit = indexStore.units().first(where: { $0.name?.contains("ViewController") ?? false })!
        let dependencies = try indexStore.recordDependencies(for: unit)
        XCTAssertNotNil(dependencies
            .compactMap { $0.record }
            .first(where: { $0.filePath?.contains("ViewController.swift") ?? false })
        )
    }

    func testSymbols() throws {
        let unit = indexStore.units().first(where: { $0.name?.contains("ViewController") ?? false })!
        let dependencies = try indexStore.recordDependencies(for: unit)
        let record = try XCTUnwrap(dependencies
            .compactMap { $0.record }
            .first(where: { $0.filePath?.contains("ViewController.swift") ?? false })
        )
        let symbols = try indexStore.symbols(for: record)

        let expected: Set<String> = [
            "init()", "ViewController",
            "viewModel", "ViewModel",
            "load()", "print(_:separator:terminator:)",
            "name"
        ]
        XCTAssertEqual(expected.subtracting(symbols.compactMap(\.name)), [])
    }

    func testOccurrences() throws {
        let unit = indexStore.units().first(where: { $0.name?.contains("ViewController") ?? false })!
        let dependencies = try indexStore.recordDependencies(for: unit)
        let record = try XCTUnwrap(dependencies
            .compactMap { $0.record }
            .first(where: { $0.filePath?.contains("ViewController.swift") ?? false })
        )
        let occs = try indexStore.occurrences(for: record)
        let actual = occs.map { (line: $0.location.line, column: $0.location.column, symbol: $0.symbol.name) }
        let expectedSet: [(line: Int64, column: Int64, symbol: String)] = [
            (line: 1, column: 7, symbol: "init()"),
            (line: 1, column: 7, symbol: "ViewController"),
            (line: 2, column: 7, symbol: "getter:viewModel"),
            (line: 2, column: 7, symbol: "setter:viewModel"),
            (line: 2, column: 7, symbol: "viewModel"),
            (line: 2, column: 18, symbol: "ViewModel"),
            (line: 2, column: 31, symbol: "init()"),
            (line: 3, column: 8, symbol: "load()"),
            (line: 4, column: 5, symbol: "print(_:separator:terminator:)"),
            (line: 4, column: 11, symbol: "getter:viewModel"),
            (line: 4, column: 11, symbol: "viewModel"),
            (line: 4, column: 21, symbol: "getter:name"),
            (line: 4, column: 21, symbol: "name")
        ]
        for expected in expectedSet {
            let found = occs.contains(where: {
                $0.location.line == expected.line &&
                    $0.location.column == expected.column &&
                    $0.symbol.name == expected.symbol
            })

            XCTAssertTrue(found, "\(expected) not found in \(actual)")
        }
    }

    func testOccurrencesForSymbol() throws {
        let unit = indexStore.units().first(where: { $0.name!.contains("ViewController") })!
        let dependencies = try indexStore.recordDependencies(for: unit)
        let record = try XCTUnwrap(dependencies
            .compactMap { $0.record }
            .first(where: { $0.filePath!.contains("ViewController.swift") })
        )

        let expected = [
            "viewModel": [
                (line: 2, column: 7),
                (line: 4, column: 11),
                (line: 8, column: 12)
            ],
            "name": [
                (line: 4, column: 21),
                (line: 8, column: 22)
            ]
        ]

        try indexStore.forEachSymbols(for: record) { symbol in
            guard let expectedSet = expected[symbol.name!] else { return true }
            let occs = try indexStore.occurrences(for: record, symbols: [symbol], relatedSymbols: [])
            for expected in expectedSet {
                let found = occs.contains(where: {
                    $0.location.line == expected.line &&
                        $0.location.column == expected.column
                })

                XCTAssertTrue(found, "\(expected) not found")
            }
            return true
        }
    }

    func testRelations() throws {
        let unit = indexStore.units().first(where: { $0.name!.contains("ViewController") })!
        let dependencies = try indexStore.recordDependencies(for: unit)
        let record = try XCTUnwrap(dependencies
            .compactMap { $0.record }
            .first(where: { $0.filePath!.contains("ViewController.swift") })
        )

        typealias Expected = (
            name: String, line: Int, column: Int,
            relations: [
                (roles: IndexStoreOccurrence.Role, symbol: String)
            ]
        )

        let expectedSet: [Expected] = [
            (name: "viewModel", line: 2, column: 7, relations: [
                (roles: [.childOf], symbol: "ViewController")
            ]),
            (name: "viewModel", line: 4, column: 14, relations: [
                (roles: [.containedBy], symbol: "load()")
            ])
        ]

        try indexStore.forEachOccurrences(for: record) { occ -> Bool in
            guard let expected = expectedSet.first(where: {
                $0.name == occ.symbol.name &&
                    $0.line == occ.location.line &&
                    $0.column == occ.location.column
            }) else { return true }

            let relations = indexStore.relations(for: occ)
            let found = expected.relations.allSatisfy { rel in
                relations.contains(where: { $0.roles == rel.roles })
            }
            XCTAssertTrue(found, "\(expected) not found in \(relations)")
            return true
        }
    }
}
