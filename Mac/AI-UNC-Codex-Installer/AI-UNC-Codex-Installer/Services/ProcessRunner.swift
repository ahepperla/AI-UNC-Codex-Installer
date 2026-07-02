import Foundation

struct ProcessResult: Sendable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String

    var succeeded: Bool {
        terminationStatus == 0
    }

    var combinedOutput: String {
        [standardOutput, standardError]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

enum ProcessRunnerError: LocalizedError {
    case executableMissing(String)

    var errorDescription: String? {
        switch self {
        case .executableMissing(let path):
            return "The executable could not be found at \(path)."
        }
    }
}

final class ProcessRunner: @unchecked Sendable {
    func run(
        executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> ProcessResult {
        try await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: executable) else {
                throw ProcessRunnerError.executableMissing(executable)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let environment {
                process.environment = environment
            }

            let output = PipeCollector()
            let error = PipeCollector()
            process.standardOutput = output.pipe
            process.standardError = error.pipe
            output.start()
            error.start()

            try process.run()
            process.waitUntilExit()

            output.stop()
            error.stop()

            return ProcessResult(
                terminationStatus: process.terminationStatus,
                standardOutput: output.stringValue,
                standardError: error.stringValue
            )
        }.value
    }
}

private final class PipeCollector: @unchecked Sendable {
    let pipe = Pipe()

    private let lock = NSLock()
    private var data = Data()

    var stringValue: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }

    func start() {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.append(chunk)
        }
    }

    func stop() {
        pipe.fileHandleForReading.readabilityHandler = nil
        let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
        if !remaining.isEmpty {
            append(remaining)
        }
    }

    private func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }
}
