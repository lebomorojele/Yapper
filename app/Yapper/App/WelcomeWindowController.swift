import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSWindowController {
    static let shared = WelcomeWindowController()
    static let completedKey = "com.yapper.welcomeCompleted"
    private let model = WelcomeModel()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 610),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "Welcome to Yapper"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = NSHostingView(rootView: WelcomeView(model: model, finish: { [weak self] in
            UserDefaults.standard.set(true, forKey: Self.completedKey)
            self?.close()
            SparkleUpdateController.shared.start()
        }))
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ state: AppRuntimeState) { model.state = state }

    func show(retry: @escaping () -> Void) {
        model.retry = retry
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
private final class WelcomeModel: ObservableObject {
    @Published var state = AppRuntimeState()
    var retry: () -> Void = {}
}

private struct WelcomeView: View {
    @ObservedObject var model: WelcomeModel
    var finish: () -> Void
    private let accent = Color(red: 0.84, green: 0.25, blue: 0.16)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Image(nsImage: BrandAssets.appIconImage(size: 52) ?? NSApp.applicationIconImage)
                    .resizable().frame(width: 52, height: 52)
                Spacer()
                Text("YOUR VOICE. YOUR MAC.").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("A little less typing.").font(.system(size: 36, weight: .regular, design: .serif))
                Text("Let's give your thoughts a way out. A few permissions, then you're ready to talk.")
                    .font(.system(size: 13)).foregroundStyle(.secondary).lineSpacing(4)
            }
            VStack(spacing: 0) {
                permissionRow(.microphone, icon: "mic", detail: "Hear your voice, only while recording.", authorized: model.state.permissions.microphone == .authorized)
                Divider().padding(.leading, 45)
                permissionRow(.accessibility, icon: "text.cursor", detail: "Put your words in the app you're using.", authorized: model.state.permissions.accessibility == .authorized)
                Divider().padding(.leading, 45)
                permissionRow(.inputMonitoring, icon: "keyboard", detail: "Use the Globe / Fn key from any app.", authorized: model.state.permissions.inputMonitoring == .authorized)
            }
            .padding(.horizontal, 16).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 12) {
                if model.state.modelReady {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Speech model ready. Your voice stays on this Mac.")
                } else if case .failed(let message) = model.state.recordingPhase {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(accent)
                    Text(message ?? "The speech model could not load.").lineLimit(3)
                    Button("Retry", action: model.retry)
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        ProgressView(value: model.state.modelDownloadProgress)
                        Text("Preparing the speech model · \(Int(model.state.modelDownloadProgress * 100))%. First launch needs internet.")
                    }
                }
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 18) {
                Text("Tap Globe to start. Tap again to finish.\nSet Globe to ‘Do Nothing’ in Keyboard settings.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineSpacing(4)
                Spacer()
                Button("Let's yap", action: finish).buttonStyle(.borderedProminent).tint(accent)
                    .controlSize(.large)
                    .disabled(!model.state.modelReady || model.state.permissions.microphone != .authorized || !model.state.permissions.hasHotkeyPermissions)
            }
        }
        .padding(32).frame(width: 560, height: 610)
        .accessibilityIdentifier("welcome.root")
    }

    private func permissionRow(_ permission: PermissionKind, icon: String, detail: String, authorized: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(accent).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(permission.rawValue).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer()
            if authorized {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Allowed")
            } else {
                Button("Allow") {
                    if permission == .microphone && model.state.permissions.microphone == .notDetermined {
                        Task { _ = await PermissionManager.shared.requestMicrophonePermission() }
                    } else {
                        PermissionManager.shared.openSystemSettings(for: permission)
                    }
                }.controlSize(.small)
            }
        }.padding(.vertical, 15)
    }
}
