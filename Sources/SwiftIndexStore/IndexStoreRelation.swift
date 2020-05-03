public struct IndexStoreRelation {
    @Lazy public var roles: IndexStoreOccurrence.Role
    @Lazy public var symbol: IndexStoreSymbol

    init(
        _roles: Lazy<IndexStoreOccurrence.Role>,
        _symbol: Lazy<IndexStoreSymbol>
    ) {
        self._roles = _roles
        self._symbol = _symbol
    }
}
