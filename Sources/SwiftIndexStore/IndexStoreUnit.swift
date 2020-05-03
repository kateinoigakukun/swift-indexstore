public struct IndexStoreUnit {
    public let name: String

    public enum Dependency {
        case record(IndexStoreRecord)
        case unit
        case file
    }
}
