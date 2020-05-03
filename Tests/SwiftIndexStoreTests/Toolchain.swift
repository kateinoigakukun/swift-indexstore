import Foundation
@testable import SwiftIndexStore

class Toolchain {
    let swiftc: URL
    init() {
        self.swiftc = findTool(name: "swiftc")!
    }
}

func findTool(name: String) -> URL? {
    guard var (path, _) = try? Process.exec(bin: "/usr/bin/xcrun", arguments: ["--find", name]) else {
        return nil
    }
    path = path.trimmingCharacters(in: .whitespacesAndNewlines)
    return URL(fileURLWithPath: path)
}
