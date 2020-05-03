import _CIndexStore

public struct IndexStoreSymbol {

    public enum Kind: UInt32 {
        case unknown = 0
        case module = 1
        case namespace = 2
        case namespaceAlias = 3
        case macro = 4
        case `enum` = 5
        case `struct` = 6
        case `class` = 7
        case `protocol` = 8
        case `extension` = 9
        case union = 10
        case `typealias` = 11
        case function = 12
        case variable = 13
        case field = 14
        case enumConstant = 15
        case instanceMethod = 16
        case classMethod = 17
        case staticMethod = 18
        case instanceProperty = 19
        case classProperty = 20
        case staticProperty = 21
        case constructor = 22
        case destructor = 23
        case conversionDunction = 24
        case parameter = 25
        case using = 26
        case commentTag = 1000
    }

    public enum SubKind: UInt32 {
        case none = 0
        case cxxCopyConstructor = 1
        case cxxMoveConstructor = 2
        case accessorGetter = 3
        case accessorSetter = 4
        case usingTypeName = 5
        case usingValue = 6

        case swiftAccessorWillSet = 1000
        case swiftAccessorDidSet = 1001
        case swiftAccessorAddressor = 1002
        case swiftAccessorMutableAddressor = 1003
        case swiftExtensionOfStruct = 1004
        case swiftExtensionOfClass = 1005
        case swiftExtensionOfEnum = 1006
        case swiftExtensionOfProtocol = 1007
        case swiftPrefixOperator = 1008
        case swiftPostfixOperator = 1009
        case swiftInfixOperator = 1010
        case swiftSubscript = 1011
        case swiftAssociatedtype = 1012
        case swiftGenericTypeParam = 1013
        case swiftAccessorRead = 1014
        case swiftAccessorModify = 1015
    }

    public struct Property: OptionSet, Hashable {
        public let rawValue: UInt32

        public static let generic = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_GENERIC)
        public static let templatePartialSpecialization = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_TEMPLATE_PARTIAL_SPECIALIZATION)
        public static let templateSpecialization = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_TEMPLATE_SPECIALIZATION)
        public static let unittest = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_UNITTEST)
        public static let ibAnnotated = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_IBANNOTATED)
        public static let ibOutletCollection = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_IBOUTLETCOLLECTION)
        public static let gkinspectable = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_GKINSPECTABLE)
        public static let local = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_LOCAL)
        public static let protocolInterface = Property(rawValue: INDEXSTORE_SYMBOL_PROPERTY_PROTOCOL_INTERFACE)

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        init(rawValue: indexstore_symbol_property_t) {
            self.rawValue = rawValue.rawValue
        }
    }

    public enum Language: UInt32 {
        case c = 0
        case objc = 1
        case cxx = 2
        case swift = 100
    }

    @Lazy public var usr: String
    @Lazy public var name: String
    @Lazy public var kind: Kind
    @Lazy public var subKind: SubKind
    @Lazy public var language: Language

    let anchor: indexstore_symbol_t?

    init(
        _usr: Lazy<String>,
        _name: Lazy<String>,
        _kind: Lazy<Kind>,
        _subKind: Lazy<SubKind>,
        _language: Lazy<Language>,
        anchor: indexstore_symbol_t?
    ) {
        self._usr = _usr
        self._name = _name
        self._kind = _kind
        self._subKind = _subKind
        self._language = _language
        self.anchor = anchor
    }
}
