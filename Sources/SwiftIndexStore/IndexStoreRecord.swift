import _CIndexStore

public struct IndexStoreRecord {
    @Lazy var name: String
    @Lazy var filePath: String
    @Lazy var moduleName: String
    @Lazy var isSystem: Bool

    let anchor: indexstore_unit_dependency_t?

    init(
        _name: Lazy<String>,
        _filePath: Lazy<String>,
        _isSystem: Lazy<Bool>,
        _moduleName: Lazy<String>,
        anchor: indexstore_unit_dependency_t?
    ) {
        self._name = _name
        self._filePath = _filePath
        self._moduleName = _moduleName
        self._isSystem = _isSystem
        self.anchor = anchor
    }
}
