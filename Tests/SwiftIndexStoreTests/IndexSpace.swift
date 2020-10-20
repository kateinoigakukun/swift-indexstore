import Foundation
@testable import SwiftIndexStore

class IndexSpace {

    let directoryPath: URL
    let toolchain: Toolchain

    var sources: [URL] = []

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
        var (dir, _) = try Process.exec(bin: "/usr/bin/mktemp", arguments: ["-d"])
        dir = dir.trimmingCharacters(in: .whitespacesAndNewlines)
        let space = IndexSpace(directoryPath: URL(fileURLWithPath: dir), toolchain: toolchain)
        try FileManager.default.createDirectory(at: space.indexStorePath, withIntermediateDirectories: false)
        return space
    }

    func addSource(name: String, sourceCode: String) throws {
        let filePath = directoryPath.appendingPathComponent(name)
        try sourceCode.write(toFile: filePath.path, atomically: true, encoding: .utf8)
        sources.append(filePath)
    }

    func index() throws {
        for source in sources {
            try index(at: source)
        }
    }
    private func index(at path: URL, file: String = #file) throws {
        let fileURL = URL(fileURLWithPath: file)
        let testsIndex = fileURL.pathComponents.firstIndex(of: "Tests") ?? 0
        let testSystemModulePath = (fileURL.pathComponents[0...testsIndex] + ["TestSystemModule", "include"]).joined(separator: "/").dropFirst()

        try Process.exec(
            bin: toolchain.swiftc.path,
            arguments: [
                "-frontend", "-c", "-primary-file", path.path]
                + sources.filter({ $0 != path }).map { $0.path }
                + [
                    "-index-store-path", indexStorePath.path,
                    "-sdk", toolchain.sdkPath.path,
                    "-Xcc", "-I\(testSystemModulePath)"
            ],
            cwd: directoryPath.path
        )
    }

    deinit {
        try! FileManager.default.removeItem(at: directoryPath)
    }
}
