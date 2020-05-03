import _CIndexStore
import Foundation

public struct IndexStoreUnit {
    public let name: String
}

public struct IndexStoreSymbolRef {
    fileprivate let anchor: indexstore_symbol_t?
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

    fileprivate class Context<T> {
        let lib: LibIndexStore
        var content: T
        var error: Error?
        init(_ content: T, lib: LibIndexStore) {
            self.content = content
            self.lib = lib
        }
    }

    public func units() -> [IndexStoreUnit] { collect(forEachFn: { forEachUnits($0) }) }

    // - MARK: ForEach Functions

    public func forEachUnits(_ next: (IndexStoreUnit) throws -> Bool) rethrows {
        typealias Ctx = Context<(IndexStoreUnit) throws -> Bool>
        try withoutActuallyEscaping(next) { next in
            let handler = Ctx(next, lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            _ = lib.store_units_apply_f(store, false.bit, ctx) { ctx, unitName -> Bool in
                let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                let unit = IndexStoreUnit(name: unitName.toSwiftString())
                do { return try ctx.content(unit) } catch {
                    ctx.error = error
                    return false
                }
            }
            if let error = handler.error {
                throw error
            }
        }
    }

    public func forEachRecordDependencies(for unit: IndexStoreUnit, _ next: (indexstore_unit_dependency_t) throws -> Bool) throws {
        guard let reader = try lib.throwsfy({ lib.unit_reader_create(store, unit.name, &$0) }) else {
            throw IndexStoreError.unableCreateUnintReader(unit.name)
        }
        typealias Ctx = Context<((indexstore_unit_dependency_t) throws -> Bool)>
        try withoutActuallyEscaping(next) { next in
            let handler = Ctx(next, lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            _ = lib.unit_reader_dependencies_apply_f(reader, ctx) { ctx, dependency -> Bool in
                let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                switch ctx.lib.unit_dependency_get_kind(dependency) {
                case INDEXSTORE_UNIT_DEPENDENCY_RECORD:
                    do { return try ctx.content(dependency!) } catch {
                        ctx.error = error
                        return false
                    }
                case INDEXSTORE_UNIT_DEPENDENCY_UNIT: break
                case INDEXSTORE_UNIT_DEPENDENCY_FILE: break
                default: fatalError("unreachable")
                }
                return true
            }
            if let error = handler.error {
                throw error
            }
        }
    }

    public func forEachSymbols(for record: indexstore_unit_dependency_t, _ next: (IndexStoreSymbol) throws -> Bool) throws {
        let recordName = lib.unit_dependency_get_name(record).toSwiftString()
        guard let reader = try lib.throwsfy({ lib.record_reader_create(store, recordName, &$0) }) else {
            throw IndexStoreError.unableCreateRecordReader(recordName)
        }
        typealias Ctx = Context<(IndexStoreSymbol) throws -> Bool>
        try withoutActuallyEscaping(next) { next in
            let handler = Ctx(next, lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            _ = lib.record_reader_symbols_apply_f(reader, true, ctx) { ctx, symbol -> Bool in
                let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                let sym = IndexStore.createSymbol(from: symbol, lib: ctx.lib)
                do { return try ctx.content(sym) } catch {
                    ctx.error = error
                    return false
                }
            }
            if let error = handler.error {
                throw error
            }
        }
    }

    public func forEachOccurrences(for record: indexstore_unit_dependency_t, symbol: IndexStoreSymbolRef,
                            _ next: (IndexStoreOccurrence) throws -> Bool) throws {
        let recordName = lib.unit_dependency_get_name(record).toSwiftString()
        let recordPath = lib.unit_dependency_get_filepath(record).toSwiftString()
        let isSystem = lib.unit_dependency_is_system(record)

        guard let reader = try lib.throwsfy({ lib.record_reader_create(store, recordName, &$0) }) else {
            throw IndexStoreError.unableCreateRecordReader(recordName)
        }

        typealias Ctx = Context<(
            next: (IndexStoreOccurrence) throws -> Bool,
            recordPath: String,
            isSystem: Bool
        )>

        try withoutActuallyEscaping(next) { next in
            let handler = Ctx((next, recordPath, isSystem), lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            var symbols = [symbol.anchor]
            _ = try symbols.withContiguousMutableStorageIfAvailable { syms in
                _ = lib.record_reader_occurrences_of_symbols_apply_f(
                    reader, syms.baseAddress!, syms.count, nil, 0, ctx
                ) { ctx, occurrence -> Bool in
                    let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                    let occ = IndexStore.createOccurrence(
                        from: occurrence,
                        recordPath: ctx.content.recordPath,
                        isSystem: ctx.content.isSystem,
                        lib: ctx.lib
                    )
                    do { return try ctx.content.next(occ) } catch {
                        ctx.error = error
                        return false
                    }
                }
                if let error = handler.error {
                    throw error
                }
            }
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
            typealias Ctx = Context<(
                next: (IndexStoreOccurrence) throws -> Bool,
                recordPath: String,
                isSystem: Bool
            )>

            try withoutActuallyEscaping(next) { next in
                let handler = Ctx((next, recordPath, isSystem), lib: lib)
                let ctx = Unmanaged.passUnretained(handler).toOpaque()
                _ = lib.record_reader_occurrences_apply_f(reader, ctx) { ctx, occurrence -> Bool in
                    let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                    let occ = IndexStore.createOccurrence(
                        from: occurrence,
                        recordPath: ctx.content.recordPath, isSystem: ctx.content.isSystem,
                        lib: ctx.lib
                    )
                    do { return try ctx.content.next(occ) } catch {
                        ctx.error = error
                        return false
                    }
                }
                if let error = handler.error {
                    throw error
                }
            }
            return true
        }
    }

    public func forEachRelations(for occ: IndexStoreOccurrence, _ next: (IndexStoreRelation) throws -> Bool) rethrows {
        typealias Ctx = Context<((IndexStoreRelation) throws -> Bool)>
        try withoutActuallyEscaping(next) { next in
            let handler = Ctx(next, lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            _ = lib.occurrence_relations_apply_f(occ.anchor, ctx) { ctx, relation -> Bool in
                let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                let roles = Lazy(wrappedValue: IndexStoreOccurrence.Role(rawValue: ctx.lib.symbol_relation_get_roles(relation)))
                let symbol = Lazy(wrappedValue: IndexStoreSymbolRef(anchor: ctx.lib.symbol_relation_get_symbol(relation)))
                let rel = IndexStoreRelation(_roles: roles, _symbolRef: symbol)
                do { return try ctx.content(rel) } catch {
                    ctx.error = error
                    return false
                }
            }
            if let error = handler.error {
                throw error
            }
        }
    }

    public func getSymbol(for symRef: IndexStoreSymbolRef) -> IndexStoreSymbol {
        return Self.createSymbol(from: symRef.anchor, lib: lib)
    }

    // - MARK: Private

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

    private func collect<T>(forEachFn: ((T) -> Bool) -> Void) -> [T] {
        var values: [T] = []
        forEachFn { value in
            values.append(value)
            return true
        }
        return values
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
