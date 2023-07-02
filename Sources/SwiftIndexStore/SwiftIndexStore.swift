import _CIndexStore
import Foundation

public final class IndexStore {

    let store: indexstore_t
    let lib: LibIndexStore

    private var unitReacherCache = [IndexStoreUnit: indexstore_unit_reader_t]()
    private let unitReacherCacheLock = UnfairLock()

    deinit {
        unitReacherCache.values.forEach { lib.unit_reader_dispose($0) }
        lib.store_dispose(store)
    }

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

    public func units(includeSystem: Bool = true) -> [IndexStoreUnit] {
        collect(forEachFn: { forEachUnits(includeSystem: includeSystem, $0) })
    }

    public func recordDependencies(for unit: IndexStoreUnit) throws -> [IndexStoreUnit.Dependency] {
        try collect(forEachFn: { try forEachRecordDependencies(for: unit, $0) })
    }

    public func symbols(for record: IndexStoreUnit.Dependency.Record) throws -> [IndexStoreSymbol] {
        try collect(forEachFn: { try forEachSymbols(for: record, $0) })
    }

    public func occurrences(for record: IndexStoreUnit.Dependency.Record) throws -> [IndexStoreOccurrence] {
        try collect(forEachFn: { try forEachOccurrences(for: record, $0) })
    }

    public func occurrences(for record: IndexStoreUnit.Dependency.Record,
                            symbols: [IndexStoreSymbol],
                            relatedSymbols: [IndexStoreSymbol]) throws -> [IndexStoreOccurrence] {
        try collect(forEachFn: { try forEachOccurrences(for: record, symbols: symbols, relatedSymbols: relatedSymbols, $0) })
    }

    public func relations(for occ: IndexStoreOccurrence) -> [IndexStoreRelation] {
        collect(forEachFn: { forEachRelations(for: occ, $0) })
    }

    public func mainFilePath(for unit: IndexStoreUnit) throws -> String? {
        let reader = try createUnitReader(for: unit)
        return lib.unit_reader_get_main_file(reader).toSwiftString()
    }

    public func moduleName(for unit: IndexStoreUnit) throws -> String? {
        let reader = try createUnitReader(for: unit)
        return lib.unit_reader_get_module_name(reader).toSwiftString()
    }

    public func target(for unit: IndexStoreUnit) throws -> String? {
        let reader = try createUnitReader(for: unit)
        return lib.unit_reader_get_target(reader).toSwiftString()
    }

    // - MARK: ForEach Functions

    public func forEachUnits(includeSystem: Bool = true, _ next: (IndexStoreUnit) throws -> Bool) rethrows {
        if includeSystem {
            try _forEachUnits(next)
        } else {
            try _forEachUnits { unit in
                let reader = try createUnitReader(for: unit)
                let isSystem = lib.unit_reader_is_system_unit(reader)

                if !isSystem {
                    return try next(unit)
                }

                return true
            }
        }
    }

    public func forEachRecordDependencies(for unit: IndexStoreUnit, _ next: (IndexStoreUnit.Dependency) throws -> Bool) throws {
        let reader = try createUnitReader(for: unit)
        typealias Ctx = Context<((IndexStoreUnit.Dependency) throws -> Bool)>
        try withoutActuallyEscaping(next) { next in
            let handler = Ctx(next, lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            _ = lib.unit_reader_dependencies_apply_f(reader, ctx) { ctx, dependency -> Bool in
                let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                let dependency = IndexStore.createUnitDependency(from: dependency, lib: ctx.lib)
                do { return try ctx.content(dependency) } catch {
                    ctx.error = error
                    return false
                }
            }
            if let error = handler.error {
                throw error
            }
        }
    }

    public func forEachSymbols(for record: IndexStoreUnit.Dependency.Record, _ next: (IndexStoreSymbol) throws -> Bool) throws {
        guard let reader = try lib.throwsfy({ lib.record_reader_create(store, record.name, &$0) }) else {
            throw IndexStoreError.unableCreateRecordReader(record.name)
        }
        defer { lib.record_reader_dispose(reader) }
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

    public func forEachOccurrences(for record: IndexStoreUnit.Dependency.Record,
                                   symbols: [IndexStoreSymbol],
                                   relatedSymbols: [IndexStoreSymbol],
                                   _ next: (IndexStoreOccurrence) throws -> Bool) throws {

        guard let reader = try lib.throwsfy({ lib.record_reader_create(store, record.name, &$0) }) else {
            throw IndexStoreError.unableCreateRecordReader(record.name)
        }
        defer { lib.record_reader_dispose(reader) }

        typealias Ctx = Context<(
            next: (IndexStoreOccurrence) throws -> Bool,
            recordPath: String?,
            isSystem: Bool
        )>

        try withoutActuallyEscaping(next) { next in
            let handler = Ctx((next, record.filePath, record.isSystem), lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            var symbols = symbols.map { $0.anchor }
            var relatedSymbols = relatedSymbols.map { $0.anchor }
            _ = try symbols.withContiguousMutableStorageIfAvailable { syms in
                _ = try relatedSymbols.withContiguousMutableStorageIfAvailable { relatedSyms in
                    _ = lib.record_reader_occurrences_of_symbols_apply_f(
                        reader, syms.baseAddress!, syms.count,
                        relatedSyms.baseAddress!, relatedSyms.count,
                        ctx
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
    }

    public func forEachOccurrences(for record: IndexStoreUnit.Dependency.Record, _ next: (IndexStoreOccurrence) throws -> Bool) throws {
        guard let reader = try lib.throwsfy({ lib.record_reader_create(store, record.name, &$0) }) else {
            throw IndexStoreError.unableCreateRecordReader(record.name)
        }
        defer { lib.record_reader_dispose(reader) }
        typealias Ctx = Context<(
            next: (IndexStoreOccurrence) throws -> Bool,
            recordPath: String?,
            isSystem: Bool
        )>

        try withoutActuallyEscaping(next) { next in
            let handler = Ctx((next, record.filePath, record.isSystem), lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            _ = lib.record_reader_occurrences_apply_f(reader, ctx) { ctx, occurrence -> Bool in
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

    public func forEachRelations(for occ: IndexStoreOccurrence, _ next: (IndexStoreRelation) throws -> Bool) rethrows {
        typealias Ctx = Context<((IndexStoreRelation) throws -> Bool)>
        try withoutActuallyEscaping(next) { next in
            let handler = Ctx(next, lib: lib)
            let ctx = Unmanaged.passUnretained(handler).toOpaque()
            _ = lib.occurrence_relations_apply_f(occ.anchor, ctx) { ctx, relation -> Bool in
                let ctx = Unmanaged<Ctx>.fromOpaque(ctx!).takeUnretainedValue()
                let roles = IndexStoreOccurrence.Role(rawValue: ctx.lib.symbol_relation_get_roles(relation))
                let symbol = IndexStore.createSymbol(
                    from: ctx.lib.symbol_relation_get_symbol(relation),
                    lib: ctx.lib
                )
                let rel = IndexStoreRelation(roles: roles, symbol: symbol)
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

    // - MARK: Private

    private func createUnitReader(for unit: IndexStoreUnit) throws -> indexstore_unit_reader_t {
        let reader = unitReacherCacheLock.perform {
            unitReacherCache[unit]
        }

        if let reader {
            return reader
        }

        guard let reader = try lib.throwsfy({ lib.unit_reader_create(store, unit.name, &$0) }) else {
            throw IndexStoreError.unableCreateUnitReader(unit.name)
        }

        unitReacherCacheLock.perform {
            unitReacherCache[unit] = reader
        }

        return reader
    }

    private func _forEachUnits(_ next: (IndexStoreUnit) throws -> Bool) rethrows {
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

    private static func createUnitDependency(from dependency: indexstore_unit_dependency_t?, lib: LibIndexStore) -> IndexStoreUnit.Dependency {
        let name = lib.unit_dependency_get_name(dependency).toSwiftString()
        let filePath = lib.unit_dependency_get_filepath(dependency).toSwiftString()
        let isSystem = lib.unit_dependency_is_system(dependency)
        func create<T>() -> IndexStoreUnit.Dependency.Content<T> {
            IndexStoreUnit.Dependency.Content(
                name: name,
                filePath: filePath,
                isSystem: isSystem,
                anchor: dependency
            )
        }
        switch lib.unit_dependency_get_kind(dependency) {
        case INDEXSTORE_UNIT_DEPENDENCY_RECORD: return .record(create())
        case INDEXSTORE_UNIT_DEPENDENCY_UNIT: return .unit(create())
        case INDEXSTORE_UNIT_DEPENDENCY_FILE: return .file(create())
        default: fatalError("unreachable")
        }
    }

    private static func createSymbol(from symbol: indexstore_symbol_t?, lib: LibIndexStore) -> IndexStoreSymbol {
        let symbolKind = IndexStoreSymbol.Kind(rawValue: lib.symbol_get_kind(symbol).rawValue)!
        let symbolSubKind = IndexStoreSymbol.SubKind(rawValue: lib.symbol_get_subkind(symbol).rawValue)!
        let symbolUsr = lib.symbol_get_usr(symbol).toSwiftString()
        let symbolName = lib.symbol_get_name(symbol).toSwiftString()
        let symbolLanguage = IndexStoreSymbol.Language(rawValue: lib.symbol_get_language(symbol).rawValue)!
        return IndexStoreSymbol(
            usr: symbolUsr, name: symbolName,
            kind: symbolKind, subKind: symbolSubKind,
            language: symbolLanguage,
            anchor: symbol
        )
    }

    private static func createOccurrence(
        from occurrence: indexstore_occurrence_t?,
        recordPath: String?,
        isSystem: Bool,
        lib: LibIndexStore
    ) -> IndexStoreOccurrence {
        let symbolRoles = IndexStoreOccurrence.Role(rawValue: lib.occurrence_get_roles(occurrence))
        let sym = IndexStore.createSymbol(
            from: lib.occurrence_get_symbol(occurrence),
            lib: lib
        )
        var line: UInt32 = 0
        var column: UInt32 = 0
        lib.occurrence_get_line_col(occurrence, &line, &column)
        let location = IndexStoreOccurrence.Location(
            path: recordPath, isSystem: isSystem,
            line: Int64(line), column: Int64(column)
        )
        return IndexStoreOccurrence(roles: symbolRoles, symbol: sym, location: location, anchor: occurrence)
    }

    private func collect<T>(forEachFn: ((T) -> Bool) throws -> Void) rethrows -> [T] {
        var values: [T] = []
        try forEachFn { value in
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
    fileprivate func toSwiftString() -> String? {
        guard data != nil else { return nil }
        return String(
            data: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: data), count: length, deallocator: .none),
            encoding: .utf8)
    }
}
