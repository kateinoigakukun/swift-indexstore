import Foundation
@testable import SwiftIndexStore

class IndexSpace {

    let directoryPath: URL
    let toolchain: Toolchain

    var indexStorePath: URL {
        directoryPath.appendingPathComponent("IndexStore")
    }

    init(directoryPath: URL, toolchain: Toolchain) {
        self.directoryPath = directoryPath
        self.toolchain = toolchain
    }

    enum Error: Swift.Error {
        case failedToCreateTmpDir
    }

    static func create(with toolchain: Toolchain) throws -> IndexSpace {
        let template = "\(arc4random()).XXXXXX"
        let dir = try template.withCString { ptr -> String in
            let ptr = UnsafeMutablePointer(mutating: ptr)
            guard let dir = mkdtemp(ptr) else {
                throw Error.failedToCreateTmpDir
            }
            return String(cString: dir)
        }
        let space = IndexSpace(directoryPath: URL(fileURLWithPath: dir), toolchain: toolchain)
        try FileManager.default.createDirectory(at: space.indexStorePath, withIntermediateDirectories: false)
        return space
    }

    func index(name: String, sourceCode: String) throws {
        let filePath = directoryPath.appendingPathComponent(name)
        try sourceCode.write(toFile: filePath.path, atomically: true, encoding: .utf8)
        try index(at: filePath)
    }

    func index(at path: URL) throws {
        try Process.exec(
            bin: "/usr/bin/xcrun",
            arguments: [toolchain.swiftc.path, "-c", path.path, "-index-store-path", indexStorePath.path],
            cwd: directoryPath.path
        )
    }

    deinit {
        try! FileManager.default.removeItem(at: directoryPath)
    }
}
