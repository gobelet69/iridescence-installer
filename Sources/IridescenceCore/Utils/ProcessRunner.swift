import Foundation

public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public var isSuccess: Bool {
        return exitCode == 0
    }
}

public enum ProcessRunner {
    /// Runs an executable directly with arguments (avoiding shell string interpolation)
    public static func run(
        executableURL: URL,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60
    ) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        if let env = environment {
            process.environment = env
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()

        // Wait with watchdog timeout
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            throw NSError(
                domain: "org.111iridescence.installer.process",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Process timed out after \(timeout) seconds: \(executableURL.path)"]
            )
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: outData, encoding: .utf8) ?? ""
        let stderr = String(data: errData, encoding: .utf8) ?? ""

        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
