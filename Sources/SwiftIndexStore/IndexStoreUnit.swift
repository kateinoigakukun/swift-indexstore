import _CIndexStore

public struct IndexStoreUnit: Hashable {
    public let name: String?

    public enum Dependency {
        public typealias Record = Content<RecordKind>
        public typealias Unit = Content<UnitKind>
        public typealias File = Content<FileKind>
        case record(Record)
        case unit(Unit)
        case file(File)

        public var record: Record? {
            switch self {
            case .record(let record): return record
            default: return nil
            }
        }

        public var unit: Unit? {
            switch self {
            case .unit(let unit): return unit
            default: return nil
            }
        }

        public var file: File? {
            switch self {
            case .file(let file): return file
            default: return nil
            }
        }

        public var name: String? {
            switch self {
            case .record(let record): return record.name
            case .unit(let unit): return unit.name
            case .file(let file): return file.name
            }
        }

        public var filePath: String? {
            switch self {
            case .record(let record): return record.filePath
            case .unit(let unit): return unit.filePath
            case .file(let file): return file.filePath
            }
        }

        public var moduleName: String? {
            switch self {
            case .record(let record): return record.moduleName
            case .unit(let unit): return unit.moduleName
            case .file(let file): return file.moduleName
            }
        }

        public var isSystem: Bool {
            switch self {
            case .record(let record): return record.isSystem
            case .unit(let unit): return unit.isSystem
            case .file(let file): return file.isSystem
            }
        }

        public struct Content<Kind> {
            public var name: String?
            public var filePath: String?
            public var moduleName: String?
            public var isSystem: Bool

            let anchor: indexstore_unit_dependency_t?
        }
    }
}

extension IndexStoreUnit.Dependency {
    public enum RecordKind {}
    public enum UnitKind {}
    public enum FileKind {}
}
