import SwiftIndexStore
import Foundation
import ArgumentParser

struct IndexDumpTool: ParsableCommand {

    struct Options: ParsableArguments {
        @Option(transform: URL.init(fileURLWithPath: ))
        var indexStorePath: URL

        @Argument(transform: URL.init(fileURLWithPath: ))
        var filePath: URL?

        func getIndexStore() throws -> IndexStore {
            try IndexStore.open(store: indexStorePath, lib: .open())
        }
    }

    static var configuration = CommandConfiguration(subcommands: [
        PrintUnit.self, PrintRecord.self
    ])
}

struct PrintUnit: ParsableCommand {

    @OptionGroup()
    var options: IndexDumpTool.Options

    func run() throws {
        let indexStore = try options.getIndexStore()
        try indexStore.forEachUnits { unit -> Bool in
            print("""
------------------------------
Unit: \"\(unit.name ?? "")\"
Dependencies:
""")
            try indexStore.forEachRecordDependencies(for: unit) { dependency -> Bool in
                let typeName: String = {
                    switch dependency {
                    case .record: return "Record"
                    case .unit: return "Unit"
                    case .file: return "File"
                    }
                }()
                print("- \(typeName) |")
                print("""
  name = \(dependency.name ?? "")
  filePath = \(dependency.filePath ?? "")
  isSystem = \(dependency.isSystem)
""")
                return true
            }
            return true
        }
    }
}

struct PrintRecord: ParsableCommand {

    @OptionGroup()
    var options: IndexDumpTool.Options

    func run() throws {
        let indexStore = try options.getIndexStore()
        try indexStore.forEachUnits { unit -> Bool in
            print("""
=============================
Unit: \"\(unit.name ?? "")\"
""")
            try indexStore.forEachRecordDependencies(for: unit) { dependency -> Bool in
                print("""
------------------------------
Record: \"\(dependency.filePath ?? "")\"
""")
                guard case let .record(record) = dependency else { return true }
                try dumpRecord(record, indexStore: indexStore)
                return true
            }
            return true
        }
    }
}

func dumpRecord(_ record: IndexStoreUnit.Dependency.Record, indexStore: IndexStore) throws {
    print("----------Symbols----------")
    try indexStore.forEachSymbols(for: record) { symbol -> Bool in
        print("| usr = \(symbol.usr ?? "") | name = \(symbol.name ?? "") | kind = \(symbol.kind) | subKind = \(symbol.subKind) | language = \(symbol.language) |")
        return true
    }
    print("----------Occurrences----------")
    try indexStore.forEachOccurrences(for: record) { (occ) -> Bool in
        print("| roles = \(occ.roles) | usr = \(occ.symbol.usr ?? "") | location = \(occ.location.path ?? ""):\(occ.location.line):\(occ.location.column) |")
        return true
    }
}
