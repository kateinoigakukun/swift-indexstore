import Foundation

enum IndexStoreError: LocalizedError {
    case internalError(String)
    case unableOpen(URL)
    case unableCreateUnitReader(String?)
    case unableCreateRecordReader(String?)
    case missingSymbol(String)
    case unableGetErrorDescription
    case unableGetToolchainDirectory

    var errorDescription: String? {
        switch self {
        case .internalError(let message):
            return "Internal Error: \(message)"
        case .unableOpen(let path):
            return "Unable to open store at \(path.path)"
        case .unableCreateUnitReader(let name):
            return "Unable to create unit reader for \(name ?? "nil")"
        case .unableCreateRecordReader(let name):
            return "Unable to create record reader for \(name ?? "nil")"
        case .missingSymbol(let symbol):
            return "Missing required symbol: \(symbol)"
        case .unableGetErrorDescription:
            return "Unable to get description for error"
        case .unableGetToolchainDirectory:
            return "Unable to get toolchain directory"
        }
    }
}
