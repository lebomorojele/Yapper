import SwiftUI
import AVFoundation

enum PrefPane: String, CaseIterable, Identifiable {
    case general = "General"
    case audio = "Audio"
    case smart = "Smart Transcribe"
    case about = "About"
    
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "gear"
        case .audio: return "mic"
        case .smart: return "sparkles"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @State private var selection: PrefPane = .general

    var body: some View {
        NavigationSplitView {
            List(PrefPane.allCases, selection: $selection) { pane in
                Label(pane.rawValue, systemImage: pane.icon)
            }
            .navigationSplitViewColumnWidth(160)
        } detail: {
            switch selection {
            case .general: GeneralPane()
            case .audio: AudioPane()
            case .smart: SmartTranscribePane()
            case .about: AboutPane()
            }
        }
    }
}

// MARK: - Panes

struct GeneralPane: View {
    @AppStorage("insertionMethod") private var insertionMethod: InsertionMethod = .axuiElement
    @State private var micAuth = PermissionManager.shared.isMicrophoneAuthorized
    @State private var accAuth = PermissionManager.shared.isAccessibilityAuthorized
    
    var body: some View {
        Form {
            Section(header: Text("Insertion")) {
                Picker("Method", selection: $insertionMethod) {
                    Text("Accessibility (Simulate Typing)").tag(InsertionMethod.axuiElement)
                    Text("Clipboard").tag(InsertionMethod.clipboard)
                }
            }
            
            Section(header: Text("Permissions")) {
                LabeledContent("Microphone Access") {
                    if micAuth {
                        Text("Granted").foregroundColor(.green)
                    } else {
                        Button("Grant Access") { PermissionManager.shared.openSystemSettings(for: "Microphone") }
                    }
                }
                LabeledContent("Accessibility Access") {
                    if accAuth {
                        Text("Granted").foregroundColor(.green)
                    } else {
                        Button("Grant Access") { PermissionManager.shared.openSystemSettings(for: "Accessibility") }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            micAuth = PermissionManager.shared.isMicrophoneAuthorized
            accAuth = PermissionManager.shared.isAccessibilityAuthorized
        }
    }
}

struct AudioPane: View {
    @AppStorage("silenceDetectionEnabled") private var silenceEnabled = true
    @AppStorage("silenceThreshold") private var threshold = 1.5
    @AppStorage("inputGain") private var gain: Double = 1.0
    @State private var devices: [AVCaptureDevice] = []
    @State private var selectedDeviceId: String = ""

    var body: some View {
        Form {
            Section(header: Text("Input Source")) {
                Picker("Microphone", selection: $selectedDeviceId) {
                    ForEach(devices, id: \.uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID)
                    }
                }
            }
            
            Section(header: Text("Input Settings")) {
                Toggle("Auto-stop on Silence", isOn: $silenceEnabled)
                if silenceEnabled {
                    LabeledContent("Threshold") {
                        Slider(value: $threshold, in: 0.5...3.0)
                    }
                }
                LabeledContent("Volume Gain") {
                    Slider(value: $gain, in: 1.0...5.0)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInMicrophone, .externalUnknown],
                mediaType: .audio,
                position: .unspecified
            )
            self.devices = discovery.devices
            if selectedDeviceId.isEmpty, let first = devices.first {
                selectedDeviceId = first.uniqueID
            }
        }
    }
}

struct SmartTranscribePane: View {
    @State private var modes = SettingsManager.shared.settings.transcriptionModes
    
    var body: some View {
        List {
            Section("Transcription Modes") {
                ForEach($modes) { $mode in
                    TextField("Name", text: $mode.name)
                }
            }
        }
        .navigationTitle("Smart Transcribe")
    }
}

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Yapper v0.3").font(.headline)
            Text("Your personal voice dictation assistant.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
