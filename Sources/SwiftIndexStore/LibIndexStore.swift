import Foundation
import _CIndexStore

@dynamicMemberLookup
public class LibIndexStore {

    private let url: URL
    private let api: indexstore_functions_t

    init(url: URL, api: indexstore_functions_t) {
        self.url = url
        self.api = api
    }

    func getPath() -> String { url.path }

    subscript<T>(dynamicMember keyPath: KeyPath<indexstore_functions_t, T>) -> T {
        api[keyPath: keyPath]
    }

    public static func open(url: URL) throws -> LibIndexStore {
        typealias Dylib = UnsafeMutableRawPointer

        var flags = RTLD_LAZY | RTLD_LOCAL

        #if os(macOS)
            flags |= RTLD_FIRST
        #endif

        let dylib = dlopen(url.path, flags)!
        var api = indexstore_functions_t()
        func requireSym<T>(_ dylib: Dylib, _ symbol: String) throws -> T {
            guard let sym = dlsym(dylib, symbol) else {
                throw IndexStoreError.missingSymbol(symbol)
            }
            return unsafeBitCast(sym, to: T.self)
        }

        api.store_create = try requireSym(dylib, "indexstore_store_create")
        api.store_dispose = try requireSym(dylib, "indexstore_store_dispose")
        api.store_units_apply_f = try requireSym(dylib, "indexstore_store_units_apply_f")
        api.unit_reader_dependencies_apply_f = try requireSym(dylib, "indexstore_unit_reader_dependencies_apply_f")
        api.unit_reader_is_system_unit = try requireSym(dylib, "indexstore_unit_reader_is_system_unit")
        api.unit_dependency_get_kind = try requireSym(dylib, "indexstore_unit_dependency_get_kind")
        api.unit_reader_create = try requireSym(dylib, "indexstore_unit_reader_create")
        api.unit_reader_dispose = try requireSym(dylib, "indexstore_unit_reader_dispose")
        api.unit_reader_get_main_file = try requireSym(dylib, "indexstore_unit_reader_get_main_file")
        api.unit_reader_get_module_name = try requireSym(dylib, "indexstore_unit_reader_get_module_name")
        api.unit_reader_get_target = try requireSym(dylib, "indexstore_unit_reader_get_target")
        api.unit_dependency_get_name = try requireSym(dylib, "indexstore_unit_dependency_get_name")
        api.unit_dependency_get_filepath = try requireSym(dylib, "indexstore_unit_dependency_get_filepath")
        api.unit_dependency_get_modulename = try requireSym(dylib, "indexstore_unit_dependency_get_modulename")
        api.unit_dependency_is_system = try requireSym(dylib, "indexstore_unit_dependency_is_system")
        api.record_reader_create = try requireSym(dylib, "indexstore_record_reader_create")
        api.record_reader_dispose = try requireSym(dylib, "indexstore_record_reader_dispose")
        api.record_reader_occurrences_apply_f = try requireSym(dylib, "indexstore_record_reader_occurrences_apply_f")
        api.record_reader_occurrences_of_symbols_apply_f = try requireSym(dylib, "indexstore_record_reader_occurrences_of_symbols_apply_f")
        api.record_reader_symbols_apply_f = try requireSym(dylib, "indexstore_record_reader_symbols_apply_f")
        api.occurrence_get_roles = try requireSym(dylib, "indexstore_occurrence_get_roles")
        api.occurrence_get_symbol = try requireSym(dylib, "indexstore_occurrence_get_symbol")
        api.symbol_get_kind = try requireSym(dylib, "indexstore_symbol_get_kind")
        api.symbol_get_subkind = try requireSym(dylib, "indexstore_symbol_get_subkind")
        api.symbol_get_usr = try requireSym(dylib, "indexstore_symbol_get_usr")
        api.symbol_get_name = try requireSym(dylib, "indexstore_symbol_get_name")
        api.occurrence_get_line_col = try requireSym(dylib, "indexstore_occurrence_get_line_col")
        api.error_get_description = try requireSym(dylib, "indexstore_error_get_description")
        api.occurrence_relations_apply_f = try requireSym(dylib, "indexstore_occurrence_relations_apply_f")
        api.symbol_relation_get_roles = try requireSym(dylib, "indexstore_symbol_relation_get_roles")
        api.symbol_relation_get_symbol = try requireSym(dylib, "indexstore_symbol_relation_get_symbol")
        api.symbol_get_language = try requireSym(dylib, "indexstore_symbol_get_language")

        return LibIndexStore(url: url, api: api)

    }

    public static func open() throws -> LibIndexStore {
        #if os(Linux)
        let url = try linuxSwiftDir().appendingPathComponent("lib/libIndexStore.so")
        #else
        let url = try macOSDeveloperDir()
            .appendingPathComponent("Toolchains")
            .appendingPathComponent("XcodeDefault.xctoolchain")
            .appendingPathComponent("usr")
            .appendingPathComponent("lib")
            .appendingPathComponent("libIndexStore.dylib")
        #endif
        return try open(url: url)
    }

    public static func linuxSwiftDir() throws -> URL {
        let (binPath, _) = try Process.exec(bin: "/usr/bin/which", arguments: ["swift"])
        return URL(
            fileURLWithPath: binPath
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                .replacingOccurrences(of: "bin/swift", with: "")
        )
    }

    private static func macOSDeveloperDir() throws -> URL {
        var (stdoutContent, _) = try Process.exec(
            bin: "/usr/bin/xcode-select",
            arguments: ["--print-path"]
        )
        stdoutContent.removeLast()
        return URL(fileURLWithPath: stdoutContent)
    }
}
