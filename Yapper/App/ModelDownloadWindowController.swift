import AppKit
import SwiftUI

@MainActor
final class ModelDownloadWindowController: NSWindowController {
    static let shared = ModelDownloadWindowController()

    private init() {
        let hostingView = NSHostingView(rootView: ModelDownloadProgressView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Enhanced Local Cleanup"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ModelDownloadProgressView: View {
    @ObservedObject private var manager = LocalModelManager.shared

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: BrandAssets.appIconImage(size: 64) ?? NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 320)
            }

            progressContent
                .frame(height: 54)

            HStack {
                Spacer()
                switch manager.status {
                case .notInstalled:
                    Button("Not Now") {
                        manager.markDeclined()
                        ModelDownloadWindowController.shared.close()
                    }
                    Button("Download Recommended") {
                        manager.downloadModel()
                    }
                    .keyboardShortcut(.defaultAction)
                case .downloading:
                    Button("Cancel") {
                        manager.cancelDownload()
                    }
                case .failed:
                    Button("Try Again") {
                        manager.downloadModel()
                    }
                    Button("Not Now") {
                        manager.markDeclined()
                        ModelDownloadWindowController.shared.close()
                    }
                case .ready:
                    Button("Done") {
                        ModelDownloadWindowController.shared.close()
                    }
                    .keyboardShortcut(.defaultAction)
                case .verifying:
                    EmptyView()
                }
            }
        }
        .padding(24)
        .frame(width: 460, height: 340)
    }

    @ViewBuilder
    private var progressContent: some View {
        switch manager.status {
        case .downloading(let progress):
            VStack(spacing: 6) {
                ProgressView(value: progress)
                    .frame(width: 260)
                Text("\(Int(progress * 100))% of \(LocalModelManager.modelDisplaySize)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        case .verifying:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Verifying download")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .ready:
            Label("Ready for enhanced cleanup", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label("Download did not finish", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .notInstalled:
            VStack(spacing: 6) {
                Label("Recommended for longer dictations", systemImage: "sparkles")
                    .foregroundStyle(.blue)
                Text("\(LocalModelManager.modelDisplaySize) • Runs locally • Removable anytime")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var title: String {
        switch manager.status {
        case .downloading:
            return "Downloading Enhanced Cleanup"
        case .verifying:
            return "Almost There"
        case .ready:
            return "Enhanced Cleanup Is Ready"
        case .failed:
            return "Download Interrupted"
        case .notInstalled:
            return "Recommended: Enhanced Local Cleanup"
        }
    }

    private var message: String {
        switch manager.status {
        case .downloading:
            return "Yapper is downloading the recommended local model from Hugging Face. You can keep using dictation while this finishes."
        case .verifying:
            return "Yapper is checking the model before enabling it."
        case .ready:
            return "Longer dictations can now use the local model for smoother punctuation and casing."
        case .failed(let message):
            return message
        case .notInstalled:
            return "Yapper works right away with fast cleanup. Download the recommended local model for smoother punctuation and casing on longer dictations."
        }
    }
}
