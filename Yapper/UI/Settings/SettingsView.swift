import SwiftUI

struct SettingsView: View {
    @State private var insertionMethod: InsertionMethod = SettingsManager.shared.settings.insertionMethod
    @State private var silenceDetectionEnabled: Bool = SettingsManager.shared.settings.silenceDetectionEnabled
    @State private var silenceThreshold: TimeInterval = SettingsManager.shared.settings.silenceThreshold
    @State private var inputGain: Float = SettingsManager.shared.settings.inputGain

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Picker("Insert Text Via", selection: $insertionMethod) {
                    Text("Accessibility (Simulates typing)").tag(InsertionMethod.axuiElement)
                    Text("Clipboard (Faster)").tag(InsertionMethod.clipboard)
                }
                .onChange(of: insertionMethod) { _, newValue in
                    SettingsManager.shared.update { $0.insertionMethod = newValue }
                }
            }
            
            Section(header: Text("Audio & Silence Detection")) {
                Toggle("Auto-stop on Silence", isOn: $silenceDetectionEnabled)
                    .onChange(of: silenceDetectionEnabled) { _, newValue in
                        SettingsManager.shared.update { $0.silenceDetectionEnabled = newValue }
                    }
                
                if silenceDetectionEnabled {
                    HStack {
                        Text("Silence Threshold:")
                        Slider(value: $silenceThreshold, in: 0.5...3.0, step: 0.1)
                        Text(String(format: "%.1fs", silenceThreshold))
                            .frame(width: 40, alignment: .trailing)
                    }
                    .onChange(of: silenceThreshold) { _, newValue in
                        SettingsManager.shared.update { $0.silenceThreshold = newValue }
                    }
                }
                
                HStack {
                    Text("Input Volume Boost:")
                    Slider(value: $inputGain, in: 1.0...5.0, step: 0.5)
                    Text(String(format: "%.1fx", inputGain))
                        .frame(width: 40, alignment: .trailing)
                }
                .onChange(of: inputGain) { _, newValue in
                    SettingsManager.shared.update { $0.inputGain = newValue }
                }
            }
        }
        .padding(20)
        .frame(width: 400, height: 250)
    }
}
