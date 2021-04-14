import Foundation
@testable import SwiftIndexStore

class IndexSpace {

    let directoryPath: URL
    let toolchain: Toolchain

    typealias SourceLocation = (module: String, url: URL)

    var sources: [SourceLocation] = []

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
        var (dir, _) = try Process.exec(bin: mktempPath, arguments: ["-d"])
        dir = dir.trimmingCharacters(in: .whitespacesAndNewlines)
        let space = IndexSpace(directoryPath: URL(fileURLWithPath: dir), toolchain: toolchain)
        try FileManager.default.createDirectory(at: space.indexStorePath, withIntermediateDirectories: false)
        return space
    }

    func addSource(name: String, module: String, sourceCode: String) throws {
        let filePath = directoryPath.appendingPathComponent(name)
        try sourceCode.write(toFile: filePath.path, atomically: true, encoding: .utf8)
        sources.append((module, filePath))
    }

    func index() throws {
        for source in sources {
            try index(at: source)
        }
    }

    private func index(at location: SourceLocation, file: String = #file) throws {
        let fileURL = URL(fileURLWithPath: file)
        let testsIndex = fileURL.pathComponents.firstIndex(of: "Tests") ?? 0
        let testSystemModulePath = (fileURL.pathComponents[0...testsIndex] + ["TestSystemModule", "include"]).joined(separator: "/").dropFirst()

        var args = [
            "-frontend", "-c", "-primary-file", location.url.path]
            + sources.filter({ $0.url != location.url }).map { $0.url.path }
            + [
                "-index-store-path", indexStorePath.path,
                "-Xcc", "-I\(testSystemModulePath)",
                "-module-name", location.module
            ]

        if let sdkPath = toolchain.sdkPath {
            args += ["-sdk", sdkPath.path]
        }

        try Process.exec(
            bin: toolchain.swiftc.path,
            arguments: args,
            cwd: directoryPath.path
        )
    }

    deinit {
        try! FileManager.default.removeItem(at: directoryPath)
    }

    private static var mktempPath: String {
        #if os(Linux)
        return "/bin/mktemp"
        #else
        return "/usr/bin/mktemp"
        #endif
    }
}
