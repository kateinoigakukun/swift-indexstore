import Foundation

extension Process {
    enum ProcessError: Error {
        case nonZeroExit(TerminationReason, Int32, command: String)
        case invalidUTF8Output(Data, command: String)
    }

    @discardableResult
    static func exec(bin: String, arguments: [String]) throws -> (stdout: String, stderr: String) {
        let process = Process()
        process.launchPath = bin
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.launch()
        process.waitUntilExit()

        if process.terminationReason != .exit || process.terminationStatus != 0 {
            throw ProcessError.nonZeroExit(
                process.terminationReason, process.terminationStatus,
                command: ([bin] + arguments).joined(separator: " ")
            )
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        guard let stdoutContent = String(data: stdoutData, encoding: .utf8) else {
            throw ProcessError.invalidUTF8Output(stdoutData,
                                                 command: ([bin] + arguments).joined(separator: " "))
        }
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        guard let stderrContent = String(data: stderrData, encoding: .utf8) else {
            throw ProcessError.invalidUTF8Output(stderrData,
                                                 command: ([bin] + arguments).joined(separator: " "))
        }

        return (stdoutContent, stderrContent)
    }
}
