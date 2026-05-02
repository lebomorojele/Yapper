import Foundation

enum TextCleanupError: Error, LocalizedError, Sendable {
    case missingLocalInferenceResources
    case timedOut
    case emptyOutput

    var errorDescription: String? {
        switch self {
        case .missingLocalInferenceResources:
            return "Local cleanup resources are not bundled"
        case .timedOut:
            return "Local cleanup timed out"
        case .emptyOutput:
            return "Local cleanup returned empty text"
        }
    }
}

struct HeuristicTextCleanupProcessor: TextCleanupProcessing {
    func clean(text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        var output = trimmed.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )

        if let first = output.first {
            output.replaceSubrange(output.startIndex...output.startIndex, with: String(first).uppercased())
        }

        if let last = output.last, !".!?".contains(last) {
            output.append(".")
        }

        return output
    }
}

final class LlamaCppTextCleanupProcessor: TextCleanupProcessing, @unchecked Sendable {
    private let executableURL: URL?
    private let modelURL: URL?
    private let timeout: TimeInterval

    init(
        executableURL: URL? = Bundle.module.url(
            forResource: "llama-completion",
            withExtension: nil,
            subdirectory: "LocalInference"
        ) ?? Bundle.module.url(
            forResource: "llama-cli",
            withExtension: nil,
            subdirectory: "LocalInference"
        ),
        modelURL: URL? = Bundle.module.url(
            forResource: "cleanup-model",
            withExtension: "gguf",
            subdirectory: "LocalInference"
        ),
        timeout: TimeInterval = 10.0
    ) {
        self.executableURL = executableURL
        self.modelURL = modelURL
        self.timeout = timeout
    }

    func clean(text: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        guard let executableURL, let modelURL else {
            throw TextCleanupError.missingLocalInferenceResources
        }

        let prompt = """
        You clean speech-to-text transcripts.
        Fix grammar, punctuation, and casing.
        Preserve meaning exactly.
        Do not add or remove information.
        Return JSON only with one key: "text".

        Example:
        Input: i think this is working now
        Output: {"text":"I think this is working now."}

        Input: \(trimmed)
        Output:
        """

        return try await runLlama(prompt: prompt, executableURL: executableURL, modelURL: modelURL)
    }

    private func runLlama(prompt: String, executableURL: URL, modelURL: URL) async throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL = executableURL
        process.arguments = [
            "-m", modelURL.path,
            "-p", prompt,
            "--device", "none",
            "-ngl", "0",
            "--fit", "off",
            "--ctx-size", "512",
            "--batch-size", "128",
            "--ubatch-size", "128",
            "--temp", "0",
            "--top-p", "0.9",
            "--repeat-penalty", "1.1",
            "-n", "256",
            "--no-display-prompt",
            "--no-warmup",
            "-no-cnv",
            "--simple-io",
            "--verbosity", "0"
        ]
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                process.terminate()
                process.waitUntilExit()
                throw TextCleanupError.timedOut
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let rawOutput = String(data: data, encoding: .utf8) ?? ""
        let output = try Self.extractCleanedText(from: rawOutput)
        guard !output.isEmpty else {
            throw TextCleanupError.emptyOutput
        }
        return output
    }

    static func extractCleanedText(from rawOutput: String) throws -> String {
        let sanitized = rawOutput
            .replacingOccurrences(of: "[end of text]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else {
            throw TextCleanupError.emptyOutput
        }

        let jsonPayload: String
        if sanitized.first == "{", sanitized.last == "}" {
            jsonPayload = sanitized
        } else if let start = sanitized.firstIndex(of: "{"),
                  let end = sanitized.lastIndex(of: "}") {
            jsonPayload = String(sanitized[start...end])
        } else {
            throw TextCleanupError.emptyOutput
        }

        guard let data = jsonPayload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = object["text"] as? String else {
            throw TextCleanupError.emptyOutput
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

final class FallbackTextCleanupProcessor: TextCleanupProcessing, @unchecked Sendable {
    private let primary: TextCleanupProcessing
    private let fallback: TextCleanupProcessing

    init(
        primary: TextCleanupProcessing = LlamaCppTextCleanupProcessor(),
        fallback: TextCleanupProcessing = HeuristicTextCleanupProcessor()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func clean(text: String) async throws -> String {
        do {
            return try await primary.clean(text: text)
        } catch {
            return try await fallback.clean(text: text)
        }
    }
}
