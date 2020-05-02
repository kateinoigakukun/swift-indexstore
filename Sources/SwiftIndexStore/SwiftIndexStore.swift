import _CIndexStore
import Foundation

public struct IndexStoreUnit {
    public let name: String
}


public struct IndexStoreSymbolRef {
    fileprivate let anchor: indexstore_symbol_t?
}

public struct IndexStoreRelation {
    public let roles: IndexStoreOccurrence.Role
    public let symbolRef: IndexStoreSymbolRef
}

public final class IndexStore {

    let store: indexstore_t
    let lib: LibIndexStore

    private init(store: indexstore_t, lib: LibIndexStore) {
        self.store = store
        self.lib = lib
    }

    public static func open(store path: URL, lib: LibIndexStore) throws -> IndexStore {
        guard let store = try lib.throwsfy({ lib.store_create(path.path, &$0) }) else {
            throw IndexStoreError.unableOpen(path)
        }
        return IndexStore(store: store, lib: lib)
    }

    public func forEachUnits(_ next: (IndexStoreUnit) -> Bool) {
        switch forEachUnits({ unit in Result<Bool, Never>.success(next(unit)) }) {
        case .success: break
        }
    }

    public func forEachUnits(_ next: (IndexStoreUnit) throws -> Bool) throws {
        try forEachUnits({ unit in Result(catching: { try next(unit) }) }).get()
    }

    public func forEachUnits<E>(_ next: (IndexStoreUnit) -> Result<Bool, E>) -> Result<Void, E> {
        let fn = { self.lib.store_units_apply_f(self.store, false.bit, $0, $1) }
        let result = wrapCapturingCFunction(fn) { unitName -> IndexStoreResult<Bool, E> in
            let unit = IndexStoreUnit(name: unitName.toSwiftString())
            return IndexStoreResult(result: next(unit), whenError: false)
        }
        return result.map { _ in }
    }

    public func forEachRecordDependencies(for unit: IndexStoreUnit, _ next: (indexstore_unit_dependency_t) throws -> Bool) throws {
        guard let reader = try lib.throwsfy({ lib.unit_reader_create(store, unit.name, &$0) }) else {
            throw IndexStoreError.unableCreateUnintReader(unit.name)
        }
        let fn = { self.lib.unit_reader_dependencies_apply_f(reader, $0, $1) }
        let result = wrapCapturingCFunction(fn) { dependency -> IndexStoreResult<Bool, Error> in
            switch lib.unit_dependency_get_kind(dependency) {
            case INDEXSTORE_UNIT_DEPENDENCY_RECORD:
                return IndexStoreResult.init(whenError: false) { try next(dependency!) }
            case INDEXSTORE_UNIT_DEPENDENCY_UNIT: break
            case INDEXSTORE_UNIT_DEPENDENCY_FILE: break
            default: fatalError("unreachable")
            }
            return .success(true)
        }
        _ = try result.get()
    }

    private static func createSymbol(from symbol: indexstore_symbol_t?, lib: LibIndexStore) -> IndexStoreSymbol {
        let symbolKind = Lazy(wrappedValue: IndexStoreSymbol.Kind(rawValue: lib.symbol_get_kind(symbol).rawValue)!)
        let symbolSubKind = Lazy(wrappedValue: IndexStoreSymbol.SubKind(rawValue: lib.symbol_get_subkind(symbol).rawValue)!)
        let symbolUsr = Lazy(wrappedValue: lib.symbol_get_usr(symbol).toSwiftString())
        let symbolName = Lazy(wrappedValue: lib.symbol_get_name(symbol).toSwiftString())
        let symbolLanguage = Lazy(wrappedValue: IndexStoreSymbol.Language(rawValue: lib.symbol_get_language(symbol).rawValue)!)
        return IndexStoreSymbol(
            _usr: symbolUsr, _name: symbolName,
            _kind: symbolKind, _subKind: symbolSubKind,
            _language: symbolLanguage,
            anchor: symbol
        )
    }

    private static func createOccurrence(
        from occurrence: indexstore_occurrence_t?,
        recordPath: String,
        isSystem: Bool,
        lib: LibIndexStore
    ) -> IndexStoreOccurrence {
        let symbolRoles = Lazy(wrappedValue: IndexStoreOccurrence.Role(rawValue: lib.occurrence_get_roles(occurrence)))
        let sym = Lazy(wrappedValue: IndexStore.createSymbol(
            from: lib.occurrence_get_symbol(occurrence),
            lib: lib
        ))
        let location = Lazy<IndexStoreOccurrence.Location>(wrappedValue: {
            var line: UInt32 = 0
            var column: UInt32 = 0
            lib.occurrence_get_line_col(occurrence, &line, &column)
            return IndexStoreOccurrence.Location(
                path: recordPath, isSystem: isSystem,
                line: Int64(line), column: Int64(column)
            )
        }())
        return IndexStoreOccurrence(_roles: symbolRoles, _symbol: sym, _location: location, anchor: occurrence)
    }

    public func forEachSymbols(for record: indexstore_unit_dependency_t, _ next: (IndexStoreSymbol) throws -> Bool) throws {
        let recordName = lib.unit_dependency_get_name(record).toSwiftString()
        guard let reader = try lib.throwsfy({ lib.record_reader_create(store, recordName, &$0) }) else {
            throw IndexStoreError.unableCreateRecordReader(recordName)
        }
        let fn = { self.lib.record_reader_symbols_apply_f(reader, true, $0, $1) }
        let result = wrapCapturingCFunction(fn) { symbol -> IndexStoreResult<Bool, Error> in
            let sym = IndexStore.createSymbol(from: symbol, lib: self.lib)
            return IndexStoreResult(whenError: false) { try next(sym) }
        }
        _ = try result.get()
    }

    public func forEachOccurrences(for record: indexstore_unit_dependency_t, symbol: IndexStoreSymbolRef,
                            _ next: (IndexStoreOccurrence) throws -> Bool) throws {
        let recordName = lib.unit_dependency_get_name(record).toSwiftString()
        let recordPath = lib.unit_dependency_get_filepath(record).toSwiftString()
        let isSystem = lib.unit_dependency_is_system(record)

        guard let reader = try lib.throwsfy({ lib.record_reader_create(store, recordName, &$0) }) else {
            throw IndexStoreError.unableCreateRecordReader(recordName)
        }

        var symbols = [symbol.anchor]
        _ = try symbols.withContiguousMutableStorageIfAvailable { syms -> Bool in
            let fn = { self.lib.record_reader_occurrences_of_symbols_apply_f(reader, syms.baseAddress!, syms.count, nil, 0, $0, $1) }
            let result = wrapCapturingCFunction(fn) { occurrence -> IndexStoreResult<Bool, Error> in
                let occ = Self.createOccurrence(
                    from: occurrence,
                    recordPath: recordPath, isSystem: isSystem,
                    lib: lib
                )
                return IndexStoreResult(whenError: false) { try next(occ) }
            }
            return try result.get()
        }
    }

    public func forEachOccurrences(for unit: IndexStoreUnit, _ next: (IndexStoreOccurrence) throws -> Bool) throws {
        try forEachRecordDependencies(for: unit) { (record) -> Bool in
            let recordName = lib.unit_dependency_get_name(record).toSwiftString()
            let recordPath = lib.unit_dependency_get_filepath(record).toSwiftString()
            let isSystem = lib.unit_dependency_is_system(record)
            guard let reader = try lib.throwsfy({ lib.record_reader_create(store, recordName, &$0) }) else {
                throw IndexStoreError.unableCreateRecordReader(recordName)
            }
            
            let fn = { self.lib.record_reader_occurrences_apply_f(reader, $0, $1) }
            let result = wrapCapturingCFunction(fn) { occurrence -> IndexStoreResult<Bool, Error> in
                let occ = Self.createOccurrence(
                    from: occurrence,
                    recordPath: recordPath, isSystem: isSystem,
                    lib: lib
                )
                return IndexStoreResult(whenError: false) { try next(occ) }
            }
            _ = try result.get()
            return true
        }
    }

    public func forEachRelations(for occ: IndexStoreOccurrence, _ next: (IndexStoreRelation) -> Bool) {
        switch forEachRelations(for: occ, { Result<Bool, Never>.success(next($0)) }) {
        case .success: break
        }
    }

    public func forEachRelations(for occ: IndexStoreOccurrence, _ next: (IndexStoreRelation) throws -> Bool) throws {
        try forEachRelations(for: occ) { occ in Result(catching: { try next(occ) }) }.get()
    }

    public func forEachRelations<E>(for occ: IndexStoreOccurrence, _ next: (IndexStoreRelation) -> Result<Bool, E>) -> Result<Void, E> {
        let fn = { self.lib.occurrence_relations_apply_f(occ.anchor, $0, $1) }
        let result = wrapCapturingCFunction(fn) { relation -> IndexStoreResult<Bool, E> in
            let roles = IndexStoreOccurrence.Role(rawValue: lib.symbol_relation_get_roles(relation))
            let symbol = IndexStoreSymbolRef(anchor: lib.symbol_relation_get_symbol(relation))
            let rel = IndexStoreRelation(roles: roles, symbolRef: symbol)
            return IndexStoreResult(result: next(rel), whenError: false)
        }
        return result.map { _ in }
    }

    public func getSymbol(for symRef: IndexStoreSymbolRef) -> IndexStoreSymbol {
        return Self.createSymbol(from: symRef.anchor, lib: lib)
    }
}

extension LibIndexStore {

    fileprivate func throwsfy<T>(_ fn: (inout indexstore_error_t?) -> T) throws -> T {
        var error: indexstore_error_t?
        let ret = fn(&error)

        if let error = error {
            guard let desc = self.error_get_description(error) else {
                throw IndexStoreError.unableGetErrorDescription
            }
            throw IndexStoreError.internalError(String(cString: desc))
        }
        return ret
    }
}

extension Bool {
    fileprivate var bit: UInt32 {
        self ? 1 : 0
    }
}

extension indexstore_string_ref_t {
    fileprivate func toSwiftString() -> String {
        String(
            bytesNoCopy: UnsafeMutableRawPointer(mutating: data),
            length: length,
            encoding: .utf8,
            freeWhenDone: false
        )!
    }
}
