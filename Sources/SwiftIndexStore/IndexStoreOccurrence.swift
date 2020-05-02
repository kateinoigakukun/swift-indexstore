import _CIndexStore

public struct IndexStoreOccurrence {
    public struct Role: OptionSet, Hashable {

        public let rawValue: UInt64

        public static let declaration = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_DECLARATION)
        public static let definition = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_DEFINITION)
        public static let reference = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REFERENCE)
        public static let read = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_READ)
        public static let write = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_WRITE)
        public static let call = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_CALL)
        public static let `dynamic` = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_DYNAMIC)
        public static let addressOf = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_ADDRESSOF)
        public static let implicit = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_IMPLICIT)

        public static let childOf = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_CHILDOF)
        public static let baseOf = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_BASEOF)
        public static let overrideOf = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_OVERRIDEOF)
        public static let receivedBy = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_RECEIVEDBY)
        public static let calledBy = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_CALLEDBY)
        public static let extendedBy = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_EXTENDEDBY)
        public static let accessorOf = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_ACCESSOROF)
        public static let containedBy = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_CONTAINEDBY)
        public static let ibTypeOf = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_IBTYPEOF)
        public static let specializationOf = Role(rawValue: INDEXSTORE_SYMBOL_ROLE_REL_SPECIALIZATIONOF)

        public static let canonical = Role(rawValue: 1 << 63)

        public static let all = Role(rawValue: ~0)

        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        init(rawValue: indexstore_symbol_role_t) {
            self.rawValue = UInt64(rawValue.rawValue)
        }
    }

    public struct Location: Equatable {
        public var path: String
        public var isSystem: Bool
        public var line: Int64
        public var column: Int64
    }

    public let roles: Role
    public let symbol: IndexStoreSymbol
    public let location: Location

    let anchor: indexstore_occurrence_t?
}
