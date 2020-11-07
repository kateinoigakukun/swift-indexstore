import Foundation
@testable import SwiftIndexStore

class Toolchain {
    let swiftc: URL
    var sdkPath: URL?

    init() {
        #if os(Linux)
        self.swiftc = URL(fileURLWithPath: "/usr/bin/swiftc")
        #else
        self.swiftc = findTool(name: "swiftc")!
        var (sdkPath, _) = try! Process.exec(bin: "/usr/bin/xcrun", arguments: ["--show-sdk-path"])
        sdkPath = sdkPath.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sdkPath = URL(fileURLWithPath: sdkPath)
        #endif
    }
}

func findTool(name: String) -> URL? {
    guard var (path, _) = try? Process.exec(bin: "/usr/bin/xcrun", arguments: ["--find", name]) else {
        return nil
    }
    path = path.trimmingCharacters(in: .whitespacesAndNewlines)
    return URL(fileURLWithPath: path)
}
