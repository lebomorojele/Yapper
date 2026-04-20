import SwiftUI

enum DesignState: String, CaseIterable, Identifiable {
    case idle = "1. Idle"
    case normal = "2. Normal Recording"
    case smart = "3. Smart Recording"
    case meeting = "4. Meeting Mode"
    case processing = "5. Processing / Loading"
    case options = "6. Smart Options Menu"
    
    var id: String { rawValue }
}

#Preview("Design Catalog") {
    DesignCatalogView()
}

struct DesignCatalogView: View {
    @State private var selectedState: DesignState? = .idle
    
    var body: some View {
        NavigationSplitView {
            List(DesignState.allCases, selection: $selectedState) { state in
                Text(state.rawValue).tag(state)
            }
            .navigationTitle("Catalog")
            .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 250)
        } detail: {
            ZStack {
                Color.gray.opacity(0.15).ignoresSafeArea()
                
                switch selectedState {
                case .idle:
                    PillContentView(state: .idle, partialTranscript: "", showOptions: false, audioMeter: .empty)
                case .normal:
                    PillContentView(
                        state: .recording(isSmartMode: false),
                        partialTranscript: "I am dictating a message",
                        showOptions: false,
                        audioMeter: AudioMeter(level: 0.6, peak: 0.7, bars: [0.2, 0.5, 0.7, 0.4, 0.3, 0.1]),
                        recordingStartTime: Date().addingTimeInterval(-6)
                    )
                case .smart:
                    PillContentView(
                        state: .recording(isSmartMode: true),
                        partialTranscript: "Convert this to an email",
                        showOptions: false,
                        audioMeter: AudioMeter(level: 0.8, peak: 0.9, bars: [0.3, 0.6, 0.9, 0.7, 0.5, 0.2]),
                        recordingStartTime: Date().addingTimeInterval(-15)
                    )
                case .meeting:
                    PillContentView(
                        state: .recordingMeeting,
                        partialTranscript: "",
                        showOptions: false,
                        audioMeter: AudioMeter(level: 0.8, peak: 0.9, bars: [0.3, 0.6, 0.9, 0.7, 0.5, 0.2]),
                        recordingStartTime: Date().addingTimeInterval(-120)
                    )
                case .processing:
                    PillContentView(
                        state: .processing,
                        partialTranscript: "",
                        showOptions: false,
                        audioMeter: .empty
                    )
                case .options:
                    PillContentView(
                        state: .idle,
                        partialTranscript: "Convert this to an email",
                        showOptions: true,
                        audioMeter: .empty
                    )
                case .none:
                    Text("Select a state")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 800, height: 600)
    }
}
