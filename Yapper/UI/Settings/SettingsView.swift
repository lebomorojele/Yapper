import AppKit
import AVFoundation
import SwiftUI

enum PreferencesPane: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case keyboard = "Keyboard"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .audio: return "mic"
        case .keyboard: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var settings: Settings
    @Published var selectedPane: PreferencesPane = .general
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var inputLevel: Float = 0

    private let audioLevelMonitor = SettingsAudioLevelMonitor()

    init(settings: Settings = SettingsManager.shared.settings) {
        self.settings = settings
        refreshDevices()
        audioLevelMonitor.onLevelChange = { [weak self] level in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.10)) {
                self.inputLevel = level
            }
        }
        audioLevelMonitor.start(deviceID: settings.selectedAudioDeviceId)
    }

    func binding<Value>(
        for keyPath: WritableKeyPath<Settings, Value>,
        persist persistChanges: Bool = true
    ) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in
                self.settings[keyPath: keyPath] = newValue
                if persistChanges {
                    self.persist()
                }
            }
        )
    }

    func bindingForSelectedDevice() -> Binding<String> {
        Binding(
            get: { self.settings.selectedAudioDeviceId ?? "" },
            set: { newValue in
                self.settings.selectedAudioDeviceId = newValue.isEmpty ? nil : newValue
                self.persist()
                self.audioLevelMonitor.start(deviceID: self.settings.selectedAudioDeviceId)
            }
        )
    }

    func refreshDevices() {
        availableDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    private func persist() {
        SettingsManager.shared.settings = settings
    }
}

struct SettingsView: View {
    @StateObject private var model = PreferencesViewModel()

    var body: some View {
        NavigationSplitView {
            List(PreferencesPane.allCases, selection: $model.selectedPane) { pane in
                Label(pane.rawValue, systemImage: pane.icon)
                    .tag(pane)
                    .accessibilityIdentifier("settings.sidebar.\(pane.rawValue.lowercased())")
            }
            .listStyle(.sidebar)
            .accessibilityIdentifier("settings.sidebar")
            .navigationSplitViewColumnWidth(min: 150, ideal: 170, max: 200)
        } detail: {
            detailPane
                .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WindowTitleUpdater(title: model.selectedPane.rawValue))
        }
        .frame(minWidth: 680, minHeight: 440)
        .accessibilityIdentifier("settings.root")
    }

    @ViewBuilder
    private var detailPane: some View {
        switch model.selectedPane {
        case .general:
            GeneralPreferencesPane(model: model)
        case .audio:
            AudioPreferencesPane(model: model)
        case .keyboard:
            KeyboardPreferencesPane()
        case .about:
            AboutPreferencesPane()
        }
    }
}

private struct InsertionMethodSegmentedControl: NSViewRepresentable {
    @Binding var selection: InsertionMethod

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: ["Accessibility", "Clipboard"],
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
        control.segmentStyle = .rounded
        control.controlSize = .small
        control.setWidth(92, forSegment: 0)
        control.setWidth(78, forSegment: 1)
        return control
    }

    func updateNSView(_ nsView: NSSegmentedControl, context: Context) {
        nsView.selectedSegment = selection == .axuiElement ? 0 : 1
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    final class Coordinator: NSObject {
        @Binding private var selection: InsertionMethod

        init(selection: Binding<InsertionMethod>) {
            _selection = selection
        }

        @MainActor @objc func changed(_ sender: NSSegmentedControl) {
            selection = sender.selectedSegment == 0 ? .axuiElement : .clipboard
        }
    }
}

private struct GeneralPreferencesPane: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Insert Text Via") {
                    InsertionMethodSegmentedControl(selection: model.binding(for: \.insertionMethod))
                        .frame(width: 174, height: 22)
                }

                Toggle("Clean punctuation and casing", isOn: model.binding(for: \.cleanupEnabled))

                if model.settings.cleanupEnabled {
                    LabeledContent("Use local model after") {
                        Stepper(
                            value: model.binding(for: \.modelCleanupWordThreshold),
                            in: 0...40,
                            step: 1
                        ) {
                            Text(modelCleanupThresholdLabel)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 88, alignment: .trailing)
                        }
                        .frame(width: 180)
                    }
                }

                Toggle("Launch at Login", isOn: model.binding(for: \.launchAtLogin))
            } header: {
                Text("General")
            } footer: {
                Text("Accessibility inserts into the focused field. Clipboard is more compatible with stubborn apps, but briefly replaces the clipboard while pasting. Shorter snippets stay on the instant cleanup path; longer dictation can use the local model.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .accessibilityIdentifier("settings.pane.general")
    }

    private var modelCleanupThresholdLabel: String {
        let threshold = model.settings.modelCleanupWordThreshold
        if threshold == 0 {
            return "Always"
        }
        return threshold == 1 ? "1 word" : "\(threshold) words"
    }
}

private struct AudioPreferencesPane: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section {
                Picker("Input Device", selection: model.bindingForSelectedDevice()) {
                    Text("System Default").tag("")
                    ForEach(model.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }

                LabeledContent("Input Level") {
                    NativeInputLevelMeter(level: min(1, model.inputLevel * model.settings.inputGain))
                }

                Toggle("Auto-stop when quiet", isOn: model.binding(for: \.silenceDetectionEnabled))

                if model.settings.silenceDetectionEnabled {
                    LabeledContent("Quiet Delay") {
                        HStack(spacing: 10) {
                            Text("0.5s")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Slider(value: model.binding(for: \.silenceThreshold), in: 0.5...3.0, step: 0.1)
                            Text(String(format: "%.1fs", model.settings.silenceThreshold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }

                LabeledContent("Volume Boost") {
                    HStack(spacing: 10) {
                        Slider(
                            value: Binding(
                                get: { Double(model.settings.inputGain) },
                                set: {
                                    model.settings.inputGain = Float($0)
                                    SettingsManager.shared.settings = model.settings
                                }
                            ),
                            in: 1.0...5.0,
                            step: 0.1
                        )
                        Text(String(format: "%.1fx", model.settings.inputGain))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            } header: {
                Text("Microphone")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Audio")
        .accessibilityIdentifier("settings.pane.audio")
    }
}

private struct KeyboardPreferencesPane: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Recording Trigger") {
                    ShortcutBadge(title: "Fn / Globe")
                }

                LabeledContent("Single Tap") {
                    Text("Start / stop dictation")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Yapper uses one global tap-toggle shortcut in this build.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Keyboard")
        .accessibilityIdentifier("settings.pane.keyboard")
    }
}

private struct AboutPreferencesPane: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 4) {
                Text("Yapper")
                    .font(.title2.weight(.semibold))
                Text("Fast local voice dictation for the menu bar.")
                    .foregroundStyle(.secondary)
            }

            Text("Version 2.0")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
        .accessibilityIdentifier("settings.pane.about")
    }
}

private final class SettingsAudioLevelMonitor: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onLevelChange: ((Float) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.yapper.settings-audio-meter")

    func start(deviceID: String?) {
        sessionQueue.async { [weak self] in
            self?.configureAndStart(deviceID: deviceID)
        }
    }

    private func configureAndStart(deviceID: String?) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                guard granted else {
                    self?.publish(level: 0)
                    return
                }
                self?.start(deviceID: deviceID)
            }
            return
        case .denied, .restricted:
            publish(level: 0)
            return
        @unknown default:
            publish(level: 0)
            return
        }

        stopLocked()

        guard let device = selectedDevice(deviceID: deviceID),
              let input = try? AVCaptureDeviceInput(device: device) else {
            publish(level: 0)
            return
        }

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: sessionQueue)

        session.beginConfiguration()
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()

        session.startRunning()
    }

    private func stopLocked() {
        if session.isRunning {
            session.stopRunning()
        }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        session.commitConfiguration()
    }

    private func selectedDevice(deviceID: String?) -> AVCaptureDevice? {
        if let deviceID, !deviceID.isEmpty,
           let device = AVCaptureDevice(uniqueID: deviceID) {
            return device
        }
        return AVCaptureDevice.default(for: .audio)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &dataPointer
        ) == kCMBlockBufferNoErr,
        let dataPointer else { return }

        let sampleCount = length / MemoryLayout<Int16>.size
        let samples = dataPointer.withMemoryRebound(to: Int16.self, capacity: sampleCount) { pointer in
            UnsafeBufferPointer(start: pointer, count: sampleCount)
        }
        guard !samples.isEmpty else { return }

        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }
        let rms = sqrt(sum / Float(samples.count))
        publish(level: min(1, rms * 12))
    }

    private func publish(level: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.onLevelChange?(level)
        }
    }
}

private struct NativeInputLevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(6, proxy.size.width * CGFloat(level)))
            }
        }
        .frame(width: 180, height: 8)
    }
}

private struct ShortcutBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.title = title
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.title = title
        }
    }
}
