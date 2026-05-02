import CryptoKit
import Foundation

enum LocalModelInstallStatus: Equatable {
    case notInstalled
    case downloading(Double)
    case verifying
    case ready
    case failed(String)

    var isDownloading: Bool {
        if case .downloading = self {
            return true
        }
        return false
    }
}

@MainActor
final class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()

    nonisolated static let modelRepositoryURL = URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF")!
    nonisolated static let modelDownloadURL = URL(string: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf")!
    nonisolated static let modelDisplayName = "Qwen2.5 1.5B Instruct Q4_K_M"
    nonisolated static let modelDisplaySize = "1.12 GB"
    nonisolated static let expectedSHA256 = "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"

    @Published private(set) var status: LocalModelInstallStatus

    private var downloadTask: URLSessionDownloadTask?
    private var progressTimer: Timer?

    private init() {
        status = FileManager.default.fileExists(atPath: Self.installedModelURL.path) ? .ready : .notInstalled
    }

    func availableModelURL() -> URL? {
        let settings = SettingsManager.shared.settings
        guard settings.enhancedCleanupPreference == .enabled,
              FileManager.default.fileExists(atPath: Self.installedModelURL.path) else {
            return nil
        }
        return Self.installedModelURL
    }

    func markDeclined() {
        SettingsManager.shared.update {
            $0.enhancedCleanupPreference = .declined
        }
    }

    func downloadModel() {
        guard !status.isDownloading else { return }

        SettingsManager.shared.update {
            $0.enhancedCleanupPreference = .enabled
        }

        if FileManager.default.fileExists(atPath: Self.installedModelURL.path) {
            status = .ready
            return
        }

        do {
            try Self.prepareModelDirectory()
        } catch {
            status = .failed(error.localizedDescription)
            return
        }

        cleanupStagedDownload()
        status = .downloading(0)

        let task = URLSession.shared.downloadTask(with: Self.modelDownloadURL) { tempURL, _, error in
            let stagedURL: URL?
            if let tempURL {
                do {
                    try Self.prepareModelDirectory()
                    let destination = Self.stagedDownloadURL
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: tempURL, to: destination)
                    stagedURL = destination
                } catch {
                    Task { @MainActor in
                        self.finishDownloadWithFailure(error.localizedDescription)
                    }
                    return
                }
            } else {
                stagedURL = nil
            }

            Task { @MainActor in
                self.handleDownloadCompletion(stagedURL: stagedURL, error: error)
            }
        }

        downloadTask = task
        startProgressTimer(for: task)
        task.resume()
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        stopProgressTimer()
        cleanupStagedDownload()
        refreshStatus()
    }

    func removeModel() {
        cancelDownload()
        do {
            if FileManager.default.fileExists(atPath: Self.installedModelURL.path) {
                try FileManager.default.removeItem(at: Self.installedModelURL)
            }
            SettingsManager.shared.update {
                $0.enhancedCleanupPreference = .declined
            }
            status = .notInstalled
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func refreshStatus() {
        if FileManager.default.fileExists(atPath: Self.installedModelURL.path) {
            status = .ready
        } else {
            status = .notInstalled
        }
    }

    private func handleDownloadCompletion(stagedURL: URL?, error: Error?) {
        downloadTask = nil
        stopProgressTimer()

        if let error = error as NSError? {
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                cleanupStagedDownload()
                refreshStatus()
            } else {
                finishDownloadWithFailure(error.localizedDescription)
            }
            return
        }

        guard let stagedURL else {
            finishDownloadWithFailure("The model download did not complete.")
            return
        }

        status = .verifying
        Task.detached(priority: .utility) {
            do {
                try Self.installVerifiedModel(from: stagedURL)
                await MainActor.run {
                    self.status = .ready
                }
            } catch {
                await MainActor.run {
                    self.finishDownloadWithFailure(error.localizedDescription)
                }
            }
        }
    }

    private func finishDownloadWithFailure(_ message: String) {
        cleanupStagedDownload()
        status = .failed(message)
    }

    private func startProgressTimer(for task: URLSessionDownloadTask) {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.20, repeats: true) { [weak self, weak task] _ in
            guard let self, let task else { return }
            Task { @MainActor in
                let progress = max(0, min(1, task.progress.fractionCompleted))
                self.status = .downloading(progress.isFinite ? progress : 0)
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func cleanupStagedDownload() {
        if FileManager.default.fileExists(atPath: Self.stagedDownloadURL.path) {
            try? FileManager.default.removeItem(at: Self.stagedDownloadURL)
        }
    }

    nonisolated private static var applicationSupportURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Yapper", isDirectory: true)
    }

    nonisolated private static var modelDirectoryURL: URL {
        applicationSupportURL.appendingPathComponent("LocalInference", isDirectory: true)
    }

    nonisolated static var installedModelURL: URL {
        modelDirectoryURL.appendingPathComponent("cleanup-model.gguf")
    }

    nonisolated private static var stagedDownloadURL: URL {
        modelDirectoryURL.appendingPathComponent("cleanup-model.download")
    }

    nonisolated private static func prepareModelDirectory() throws {
        try FileManager.default.createDirectory(
            at: modelDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    nonisolated private static func installVerifiedModel(from stagedURL: URL) throws {
        let digest = try sha256Hex(for: stagedURL)
        guard digest == expectedSHA256 else {
            throw NSError(
                domain: "Yapper.LocalModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The downloaded model did not pass verification."]
            )
        }

        try prepareModelDirectory()
        if FileManager.default.fileExists(atPath: installedModelURL.path) {
            try FileManager.default.removeItem(at: installedModelURL)
        }
        try FileManager.default.moveItem(at: stagedURL, to: installedModelURL)
    }

    nonisolated private static func sha256Hex(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if data.isEmpty {
                break
            }
            hasher.update(data: data)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
