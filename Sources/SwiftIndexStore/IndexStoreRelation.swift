public struct IndexStoreRelation {
    @Lazy public var roles: IndexStoreOccurrence.Role
    @Lazy public var symbolRef: IndexStoreSymbolRef

    init(
        _roles: Lazy<IndexStoreOccurrence.Role>,
        _symbolRef: Lazy<IndexStoreSymbolRef>
    ) {
        self._roles = _roles
        self._symbolRef = _symbolRef
    }
}
