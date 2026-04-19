import SwiftUI
import AVFoundation

// MARK: - Models

struct TranscriptionMode: Identifiable, Codable {
    var id = UUID()
    var name: String
    var prompt: String
}

enum InsertionMethod: String, CaseIterable {
    case accessibility = "axuiElement"
    case clipboard = "clipboard"
    var label: String { self == .accessibility ? "Accessibility" : "Clipboard" }
}

enum AIProvider: String, CaseIterable {
    case openai, anthropic, ollama
    var label: String {
        switch self { case .openai: "OpenAI"; case .anthropic: "Anthropic"; case .ollama: "Local (Ollama)" }
    }
    var models: [String] {
        switch self {
        case .openai: ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "gpt-3.5-turbo"]
        case .anthropic: ["claude-sonnet-4-5", "claude-opus-4-5", "claude-haiku-4-5"]
        case .ollama: ["llama3", "mistral", "phi3", "gemma2"]
        }
    }
}

enum ConnectionStatus { case idle, checking, ok, failed }
enum SummaryMode: String, CaseIterable {
    case none, bullets, actions
    var label: String {
        switch self { case .none: "None"; case .bullets: "Bullet Points"; case .actions: "Action Items" }
    }
}

// MARK: - App State

class YapperSettings: ObservableObject {
    @AppStorage("insertionMethod")       var insertionMethod: String = "axuiElement"
    @AppStorage("launchAtLogin")         var launchAtLogin: Bool = false
    @AppStorage("silenceDetection")      var silenceDetection: Bool = true
    @AppStorage("silenceThreshold")      var silenceThreshold: Double = 1.5
    @AppStorage("inputGain")             var inputGain: Double = 1.0
    @AppStorage("aiProvider")            var aiProviderRaw: String = "openai"
    @AppStorage("apiKey")                var apiKey: String = ""
    @AppStorage("aiModel")              var aiModel: String = ""
    @AppStorage("autoRecordMeetings")    var autoRecordMeetings: Bool = true
    @AppStorage("saveTranscripts")       var saveTranscripts: Bool = false
    @AppStorage("saveLocation")          var saveLocation: String = ""
    @AppStorage("generateSummary")       var generateSummaryRaw: String = "none"
    @AppStorage("modesData")             private var modesData: Data = Data()

    var aiProvider: AIProvider {
        get { AIProvider(rawValue: aiProviderRaw) ?? .openai }
        set { aiProviderRaw = newValue.rawValue }
    }

    var summaryMode: SummaryMode {
        get { SummaryMode(rawValue: generateSummaryRaw) ?? .none }
        set { generateSummaryRaw = newValue.rawValue }
    }

    var modes: [TranscriptionMode] {
        get {
            (try? JSONDecoder().decode([TranscriptionMode].self, from: modesData)) ?? Self.defaultModes
        }
        set {
            modesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    static let defaultModes: [TranscriptionMode] = [
        .init(name: "Polish",  prompt: "Correct grammar and improve clarity while keeping the original meaning."),
        .init(name: "Email",   prompt: "Rewrite as a professional email with a clear subject and sign-off."),
        .init(name: "Casual",  prompt: "Make this sound relaxed, conversational, and friendly."),
        .init(name: "Prompt",  prompt: "Rewrite as a clear, detailed AI prompt for a language model.")
    ]
}

// MARK: - Root Preferences Window

enum PrefPane: String, CaseIterable, Identifiable {
    case general, audio, smart, meeting, about
    var id: String { rawValue }
    var label: String {
        switch self {
        case .general: "General"; case .audio: "Audio"
        case .smart: "Smart Transcribe"; case .meeting: "Meeting"; case .about: "About"
        }
    }
    var icon: String {
        switch self {
        case .general: "gearshape.fill"; case .audio: "mic.fill"
        case .smart: "sparkles"; case .meeting: "doc.text.fill"; case .about: "info.circle.fill"
        }
    }
    var iconColor: Color {
        switch self {
        case .general: .gray; case .audio: Color(red: 1, green: 0.42, blue: 0.21)
        case .smart: Color(red: 0.35, green: 0.34, blue: 0.84); case .meeting: .green; case .about: .blue
        }
    }
}

struct YapperPreferences: View {
    @StateObject private var settings = YapperSettings()
    @State private var selectedPane: PrefPane = .audio

    var body: some View {
        NavigationSplitView {
            List(PrefPane.allCases, selection: $selectedPane) { pane in
                Label {
                    Text(pane.label)
                } icon: {
                    Image(systemName: pane.icon)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(pane.iconColor)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .tag(pane)
            }
            .listStyle(.sidebar)
            .navigationTitle("Yapper")
        } detail: {
            Group {
                switch selectedPane {
                case .general: GeneralPane(settings: settings)
                case .audio:   AudioPane(settings: settings)
                case .smart:   SmartTranscribePane(settings: settings)
                case .meeting: MeetingPane(settings: settings)
                case .about:   AboutPane()
                }
            }
            .navigationTitle(selectedPane.label)
            .frame(minWidth: 480)
        }
        .frame(width: 720, height: 520)
    }
}

// MARK: - General Pane

struct GeneralPane: View {
    @ObservedObject var settings: YapperSettings

    var body: some View {
        Form {
            Section("General") {
                Picker("Insert Text Via", selection: $settings.insertionMethod) {
                    Text("Accessibility").tag("axuiElement")
                    Text("Clipboard").tag("clipboard")
                }
                .pickerStyle(.segmented)

                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

            Section("Keyboard Shortcuts") {
                LabeledContent("Recording Trigger") {
                    Text("🌐 Globe / Fn")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                }
                LabeledContent("Cancel Recording") {
                    Text("⎋ Escape")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Audio Pane

struct AudioPane: View {
    @ObservedObject var settings: YapperSettings
    @State private var inputDevices: [AVCaptureDevice] = []
    @State private var selectedDevice: AVCaptureDevice?
    @State private var level: Float = 0

    var body: some View {
        Form {
            Section("Input") {
                Picker("Input Device", selection: $selectedDevice) {
                    ForEach(inputDevices, id: \.uniqueID) { dev in
                        Text(dev.localizedName).tag(Optional(dev))
                    }
                }

                LabeledContent("Input Level") {
                    InputLevelView(level: level)
                }

                LabeledContent("Volume Boost") {
                    HStack {
                        Text("1×").foregroundStyle(.secondary).font(.caption)
                        Slider(value: $settings.inputGain, in: 1...5, step: 0.1)
                        Text("5×").foregroundStyle(.secondary).font(.caption)
                        Text(String(format: "%.1f×", settings.inputGain))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            }

            Section("Silence Detection") {
                Toggle("Auto-stop when quiet", isOn: $settings.silenceDetection)

                if settings.silenceDetection {
                    LabeledContent("Threshold") {
                        HStack {
                            Text("0.5s").foregroundStyle(.secondary).font(.caption)
                            Slider(value: $settings.silenceThreshold, in: 0.5...3.0, step: 0.1)
                            Text("3.0s").foregroundStyle(.secondary).font(.caption)
                            Text(String(format: "%.1fs", settings.silenceThreshold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 36, alignment: .trailing)
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: settings.silenceDetection)
        }
        .formStyle(.grouped)
        .onAppear { loadDevices() }
    }

    private func loadDevices() {
        inputDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio, position: .unspecified
        ).devices
        selectedDevice = inputDevices.first
    }
}

// Native-style segmented input level meter
struct InputLevelView: View {
    var level: Float
    private let segments = 24

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Float(i) / Float(segments) < level ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 14)
            }
        }
    }
}

// MARK: - Smart Transcribe Pane

struct SmartTranscribePane: View {
    @ObservedObject var settings: YapperSettings
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var selectedModeID: UUID?
    @State private var showAddSheet = false
    @State private var editingMode: TranscriptionMode?

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: $settings.aiProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { p in
                        Text(p.label).tag(p)
                    }
                }
                .onChange(of: settings.aiProvider) { connectionStatus = .idle }

                if settings.aiProvider != .ollama {
                    LabeledContent("API Key") {
                        SecureField("sk-...", text: $settings.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                            .onChange(of: settings.apiKey) { connectionStatus = .idle }
                    }
                }

                Picker("Model", selection: $settings.aiModel) {
                    ForEach(settings.aiProvider.models, id: \.self) { m in
                        Text(m).tag(m)
                    }
                }

                LabeledContent("Connection") {
                    HStack {
                        FlightCheckBadge(status: connectionStatus)
                        Button("Check Connection") { runFlightCheck() }
                            .disabled(connectionStatus == .checking)
                    }
                }
            }

            Section {
                ModesTable(
                    modes: Binding(
                        get: { settings.modes },
                        set: { settings.modes = $0 }
                    ),
                    selectedID: $selectedModeID,
                    onAdd: { showAddSheet = true },
                    onEdit: { editingMode = $0 }
                )
            } header: {
                Text("Transcription Modes")
            } footer: {
                Text("Modes appear in the recording overlay after dictation.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddSheet) {
            ModeEditorSheet(mode: nil) { newMode in
                var m = settings.modes; m.append(newMode); settings.modes = m
            }
        }
        .sheet(item: $editingMode) { mode in
            ModeEditorSheet(mode: mode) { updated in
                var m = settings.modes
                if let idx = m.firstIndex(where: { $0.id == updated.id }) { m[idx] = updated }
                settings.modes = m
            }
        }
    }

    private func runFlightCheck() {
        connectionStatus = .checking
        // Real implementation: call provider's endpoint with the stored key
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            let valid = settings.aiProvider == .ollama || settings.apiKey.count > 8
            connectionStatus = valid ? .ok : .failed
        }
    }
}

struct FlightCheckBadge: View {
    let status: ConnectionStatus
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }
    private var statusColor: Color {
        switch status {
        case .idle: .secondary; case .checking: .orange; case .ok: .green; case .failed: .red
        }
    }
    private var statusLabel: String {
        switch status {
        case .idle: "Not verified"; case .checking: "Checking..."; case .ok: "Connected"; case .failed: "Failed"
        }
    }
}

struct ModesTable: View {
    @Binding var modes: [TranscriptionMode]
    @Binding var selectedID: UUID?
    var onAdd: () -> Void
    var onEdit: (TranscriptionMode) -> Void

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(modes) { mode in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.name).fontWeight(.medium)
                            Text(mode.prompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button { onEdit(mode) } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .tag(mode.id)
                }
                .onMove { modes.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(height: min(CGFloat(modes.count) * 54 + 10, 220))

            Divider()
            HStack(spacing: 0) {
                Button { onAdd() } label: {
                    Image(systemName: "plus").frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                Divider().frame(height: 20)
                Button {
                    if let id = selectedID, let idx = modes.firstIndex(where: { $0.id == id }) {
                        modes.remove(at: idx); selectedID = nil
                    }
                } label: {
                    Image(systemName: "minus").frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)
                .disabled(selectedID == nil)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
    }
}

struct ModeEditorSheet: View {
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
                .frame(height: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(mode == nil ? "Add" : "Save") {
                    var m = mode ?? TranscriptionMode(name: "", prompt: "")
                    m.name = name; m.prompt = prompt
                    onSave(m); dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || prompt.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            name = mode?.name ?? ""; prompt = mode?.prompt ?? ""
        }
    }
}

// MARK: - Meeting Pane

struct MeetingPane: View {
    @ObservedObject var settings: YapperSettings

    var body: some View {
        Form {
            Section("Recording") {
                Toggle("Auto-record Meetings", isOn: $settings.autoRecordMeetings)
            }

            Section("Transcripts") {
                Toggle("Save Transcripts", isOn: $settings.saveTranscripts)

                if settings.saveTranscripts {
                    LabeledContent("Save Location") {
                        HStack {
                            Text(settings.saveLocation.isEmpty ? "~/Documents" : settings.saveLocation)
                                .foregroundStyle(.secondary)
                                .truncationMode(.middle)
                            Button("Choose…") { chooseSaveLocation() }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Picker("Generate Summary", selection: $settings.summaryMode) {
                    ForEach(SummaryMode.allCases, id: \.self) { m in
                        Text(m.label).tag(m)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: settings.saveTranscripts)
        }
        .formStyle(.grouped)
    }

    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveLocation = url.path
        }
    }
}

// MARK: - About Pane

struct AboutPane: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "waveform")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Yapper").font(.headline)
                        Text("Version 0.2 (42)").foregroundStyle(.secondary).font(.subheadline)
                        Text("Up to date").foregroundStyle(.green).font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Preview

#Preview {
    YapperPreferences()
}
