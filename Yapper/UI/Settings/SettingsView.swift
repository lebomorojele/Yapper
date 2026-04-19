import AppKit
import AVFoundation
import SwiftUI

enum PreferencesPane: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case aiKeys = "AI & Keys"
    case meeting = "Meeting"
    case keyboard = "Keyboard"
    case about = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .audio: return "mic"
        case .aiKeys: return "sparkles"
        case .meeting: return "person.2"
        case .keyboard: return "keyboard"
        case .about: return "info.circle"
        }
    }
}

enum SmartProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case ollama = "Ollama"

    var id: String { rawValue }

    var models: [String] {
        switch self {
        case .openAI:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini", "gpt-4.1"]
        case .anthropic:
            return ["claude-3-5-haiku-latest", "claude-3-7-sonnet-latest", "claude-sonnet-4-0"]
        case .ollama:
            return ["llama3.2", "mistral", "qwen2.5", "gemma3"]
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .openAI: return "sk-..."
        case .anthropic: return "sk-ant-..."
        case .ollama: return ""
        }
    }
}

enum SummaryPreset: String, CaseIterable, Identifiable {
    case none = "None"
    case bullets = "Bullet Points"
    case actions = "Action Items"

    var id: String { rawValue }
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var settings: Settings
    @Published var selectedPane: PreferencesPane = .general
    @Published var availableDevices: [AVCaptureDevice] = []
    @Published var simulatedInputLevel: Float = 0.18
    @Published var selectedModeID: UUID?
    @Published var modeBeingEdited: TranscriptionMode?
    @Published var showingNewModeSheet = false

    private var levelTimer: Timer?

    init(settings: Settings = SettingsManager.shared.settings) {
        self.settings = settings
        refreshDevices()
        normalizeModelSelection()
        startLevelSimulation()
    }

    var provider: SmartProvider {
        get { SmartProvider(rawValue: settings.aiProvider) ?? .openAI }
        set {
            settings.aiProvider = newValue.rawValue
            if !newValue.models.contains(settings.llmModel) {
                settings.llmModel = newValue.models.first ?? settings.llmModel
            }
            persist()
        }
    }

    var summaryPreset: SummaryPreset {
        get { SummaryPreset(rawValue: settings.meetingSummaryMode) ?? .bullets }
        set {
            settings.meetingSummaryMode = newValue.rawValue
            persist()
        }
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

    func bindingForSaveLocation() -> Binding<String> {
        Binding(
            get: { self.settings.saveLocation ?? "" },
            set: { newValue in
                self.settings.saveLocation = newValue.isEmpty ? nil : newValue
                self.persist()
            }
        )
    }

    func bindingForOpenAIKey() -> Binding<String> {
        Binding(
            get: { self.settings.openAIAPIKey ?? "" },
            set: { newValue in
                self.settings.openAIAPIKey = newValue.isEmpty ? nil : newValue
                self.persist()
            }
        )
    }

    func bindingForAnthropicKey() -> Binding<String> {
        Binding(
            get: { self.settings.anthropicAPIKey ?? "" },
            set: { newValue in
                self.settings.anthropicAPIKey = newValue.isEmpty ? nil : newValue
                self.persist()
            }
        )
    }

    func bindingForSelectedDevice() -> Binding<String> {
        Binding(
            get: { self.settings.selectedAudioDeviceId ?? "" },
            set: { newValue in
                self.settings.selectedAudioDeviceId = newValue.isEmpty ? nil : newValue
                self.persist()
            }
        )
    }

    func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        if panel.runModal() == .OK {
            settings.saveLocation = panel.url?.path
            persist()
        }
    }

    func refreshDevices() {
        availableDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    func addMode(_ mode: TranscriptionMode) {
        settings.transcriptionModes.append(mode)
        persist()
    }

    func updateMode(_ mode: TranscriptionMode) {
        guard let index = settings.transcriptionModes.firstIndex(where: { $0.id == mode.id }) else { return }
        settings.transcriptionModes[index] = mode
        persist()
    }

    func deleteSelectedMode() {
        guard let selectedModeID,
              let index = settings.transcriptionModes.firstIndex(where: { $0.id == selectedModeID }) else { return }
        settings.transcriptionModes.remove(at: index)
        self.selectedModeID = nil
        persist()
    }

    func moveModes(from source: IndexSet, to destination: Int) {
        settings.transcriptionModes.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func startLevelSimulation() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self else { return }
            let next = Float.random(in: 0.08...0.95)
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.10)) {
                    self.simulatedInputLevel = next
                }
            }
        }
    }

    private func normalizeModelSelection() {
        let provider = SmartProvider(rawValue: settings.aiProvider) ?? .openAI
        if !provider.models.contains(settings.llmModel) {
            settings.llmModel = provider.models.first ?? "gpt-4o-mini"
        }
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
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 190, max: 220)
        } detail: {
            detailPane
                .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(WindowTitleUpdater(title: model.selectedPane.rawValue))
        }
        .toolbar(removing: .sidebarToggle)
        .frame(minWidth: 760, minHeight: 560)
        .sheet(isPresented: $model.showingNewModeSheet) {
            ModeEditorSheet(mode: nil) { model.addMode($0) }
        }
        .sheet(item: $model.modeBeingEdited) { mode in
            ModeEditorSheet(mode: mode) { model.updateMode($0) }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch model.selectedPane {
        case .general:
            GeneralPreferencesPane(model: model)
        case .audio:
            AudioPreferencesPane(model: model)
        case .aiKeys:
            AIKeysPreferencesPane(model: model)
        case .meeting:
            MeetingPreferencesPane(model: model)
        case .keyboard:
            KeyboardPreferencesPane()
        case .about:
            AboutPreferencesPane()
        }
    }
}

private struct GeneralPreferencesPane: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section("General") {
                Picker("Insert Text Via", selection: model.binding(for: \.insertionMethod)) {
                    Text("Accessibility").tag(InsertionMethod.axuiElement)
                    Text("Clipboard").tag(InsertionMethod.clipboard)
                }
                .pickerStyle(.segmented)

                Toggle("Launch at Login", isOn: model.binding(for: \.launchAtLogin))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }
}

private struct AudioPreferencesPane: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section("Input") {
                Picker("Input Device", selection: model.bindingForSelectedDevice()) {
                    Text("System Default").tag("")
                    ForEach(model.availableDevices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }

                LabeledContent("Input Level") {
                    NativeInputLevelMeter(level: model.simulatedInputLevel)
                }

                Toggle("Auto-stop when quiet", isOn: model.binding(for: \.silenceDetectionEnabled))

                if model.settings.silenceDetectionEnabled {
                    LabeledContent("Threshold") {
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
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Audio")
    }
}

private struct AIKeysPreferencesPane: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: Binding(
                    get: { model.provider },
                    set: { model.provider = $0 }
                )) {
                    ForEach(SmartProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }

                Picker("Model", selection: model.binding(for: \.llmModel)) {
                    ForEach(model.provider.models, id: \.self) { item in
                        Text(item).tag(item)
                    }
                }

                if model.provider == .openAI {
                    LabeledContent("API Key") {
                        SecureField("sk-...", text: model.bindingForOpenAIKey())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }
                }

                if model.provider == .anthropic {
                    LabeledContent("API Key") {
                        SecureField("sk-ant-...", text: model.bindingForAnthropicKey())
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }
                }

                if model.provider == .ollama {
                    LabeledContent("Endpoint") {
                        TextField("http://localhost:11434", text: model.binding(for: \.ollamaEndpoint))
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 260)
                    }
                }
            }

            Section {
                ModesTable(
                    modes: Binding(
                        get: { model.settings.transcriptionModes },
                        set: {
                            model.settings.transcriptionModes = $0
                            SettingsManager.shared.settings = model.settings
                        }
                    ),
                    selectedID: $model.selectedModeID,
                    onAdd: { model.showingNewModeSheet = true },
                    onEdit: { model.modeBeingEdited = $0 },
                    onMove: { source, destination in model.moveModes(from: source, to: destination) },
                    onDelete: { model.deleteSelectedMode() }
                )
            } header: {
                Text("Smart Modes")
            } footer: {
                Text("These modes appear in the smart transcribe selection card after recording.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("AI & Keys")
    }
}

private struct MeetingPreferencesPane: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section("Meeting Notes") {
                Toggle("Save transcripts", isOn: model.binding(for: \.saveTranscripts))

                LabeledContent("Save Location") {
                    HStack(spacing: 8) {
                        Text((model.settings.saveLocation?.isEmpty == false ? model.settings.saveLocation! : "~/Documents"))
                            .foregroundStyle(model.settings.saveTranscripts ? .secondary : .tertiary)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button("Choose…") {
                            model.chooseSaveLocation()
                        }
                        .disabled(!model.settings.saveTranscripts)
                    }
                }

                Picker("Summary", selection: Binding(
                    get: { model.summaryPreset },
                    set: { model.summaryPreset = $0 }
                )) {
                    ForEach(SummaryPreset.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Meeting")
    }
}

private struct KeyboardPreferencesPane: View {
    var body: some View {
        Form {
            Section("Shortcuts") {
                LabeledContent("Recording Trigger") {
                    ShortcutBadge(title: "Fn / Globe")
                }

                LabeledContent("Single Tap") {
                    Text("Start / stop dictation")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Double Tap") {
                    Text("Open smart transcribe modes")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Long Press") {
                    Text("Start / stop meeting recording")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Keyboard")
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
                Text("Production voice dictation for the menu bar.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Version 0.3")
                Text("Built for fast dictation, smart rewriting, and lightweight meeting capture.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
    }
}

private struct NativeInputLevelMeter: View {
    let level: Float
    private let segmentCount = 28

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segmentCount, id: \.self) { index in
                Capsule()
                    .fill(fillColor(for: index))
                    .frame(width: 6, height: 14)
            }
        }
        .padding(.vertical, 4)
    }

    private func fillColor(for index: Int) -> Color {
        let threshold = Float(index + 1) / Float(segmentCount)
        guard level >= threshold else { return Color.secondary.opacity(0.18) }
        if index > 22 { return .red }
        if index > 16 { return .yellow }
        return .green
    }
}

private struct ShortcutBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
    }
}

private struct ModesTable: View {
    @Binding var modes: [TranscriptionMode]
    @Binding var selectedID: UUID?
    let onAdd: () -> Void
    let onEdit: (TranscriptionMode) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(modes) { mode in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.name)
                                .fontWeight(.medium)
                            Text(mode.prompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            onEdit(mode)
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .tag(mode.id)
                }
                .onMove(perform: onMove)
            }
            .frame(height: min(CGFloat(modes.count) * 54 + 14, 240))

            Divider()

            HStack(spacing: 0) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 18)

                Button(action: onDelete) {
                    Image(systemName: "minus")
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(selectedID == nil)

                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

private struct ModeEditorSheet: View {
    let mode: TranscriptionMode?
    let onSave: (TranscriptionMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var prompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode == nil ? "Add Mode" : "Edit Mode")
                .font(.headline)

            TextField("Mode name", text: $name)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $prompt)
                .font(.body)
                .frame(height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(mode == nil ? "Add" : "Save") {
                    var updated = mode ?? TranscriptionMode(name: "", prompt: "")
                    updated.name = name
                    updated.prompt = prompt
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            name = mode?.name ?? ""
            prompt = mode?.prompt ?? ""
        }
    }
}

private struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
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
