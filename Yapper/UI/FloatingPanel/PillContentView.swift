import SwiftUI

// MARK: - Models

private enum PillRecordingState: Equatable {
    case idle
    case recording(duration: TimeInterval, liveText: String)
    case processing
    case selecting
    case cancelled
    case complete(mode: PillTranscriptionMode, showCopied: Bool)
}

private enum PillVisualMode: Equatable {
    case idle
    case recording
    case processing
    case selecting
    case cancelled
    case complete(showCopied: Bool)
}

private struct PillTranscriptionMode: Identifiable, Equatable {
    let id: String
    let label: String
    let shortcut: String

    static let all: [PillTranscriptionMode] = [
        .init(id: "slack", label: "Slack", shortcut: "1"),
        .init(id: "chat", label: "Chat", shortcut: "2"),
        .init(id: "email", label: "Email", shortcut: "3"),
        .init(id: "prompt", label: "Prompt", shortcut: "4")
    ]
}

private enum PillContainerMetrics {
    static let compactWidth: CGFloat = 317
    static let compactHeight: CGFloat = 38
    static let optionsWidth: CGFloat = 372
    static let optionsHeight: CGFloat = 98
}

// MARK: - Entry View

struct PillContentView: View {
    var state: RecordingState = .idle
    var partialTranscript: String = ""
    var showOptions: Bool = false
    var audioMeter: AudioMeter = .empty
    var recordingStartTime: Date? = nil
    var onOptionSelected: (SmartModeOption) -> Void = { _ in }

    private var pillState: PillRecordingState {
        if showOptions {
            return .selecting
        }

        switch state {
        case .idle:
            return .idle
        case .ready:
            return .recording(
                duration: recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0,
                liveText: ""
            )
        case .recording, .recordingMeeting:
            return .recording(
                duration: recordingStartTime.map { Date().timeIntervalSince($0) } ?? 0,
                liveText: partialTranscript
            )
        case .processing:
            return .processing
        case .cancelled:
            return .cancelled
        case .complete:
            return .complete(mode: .init(id: "complete", label: "Complete", shortcut: ""), showCopied: false)
        case .completeClipboard:
            return .complete(mode: .init(id: "clipboard", label: "Copied to clipboard", shortcut: ""), showCopied: true)
        }
    }

    private var visualMode: PillVisualMode {
        switch pillState {
        case .idle:
            return .idle
        case .recording:
            return .recording
        case .processing:
            return .processing
        case .selecting:
            return .selecting
        case .cancelled:
            return .cancelled
        case .complete(_, let showCopied):
            return .complete(showCopied: showCopied)
        }
    }

    var body: some View {
        ZStack {
            DynamicIslandWidget(
                state: pillState,
                visualMode: visualMode,
                audioMeter: audioMeter,
                onOptionSelected: onOptionSelected
            )
        }
        .frame(
            width: showOptions ? PillContainerMetrics.optionsWidth : PillContainerMetrics.compactWidth,
            height: showOptions ? PillContainerMetrics.optionsHeight : PillContainerMetrics.compactHeight,
            alignment: .center
        )
        .background(Color.clear)
    }
}

// MARK: - Dynamic Island Widget

private struct DynamicIslandWidget: View {
    let state: PillRecordingState
    let visualMode: PillVisualMode
    let audioMeter: AudioMeter
    let onOptionSelected: (SmartModeOption) -> Void

    var body: some View {
        HStack(spacing: 0) {
            contentView
        }
        .frame(width: widgetWidth, height: widgetHeight)
        .background(Color(hex: "1a1a1a"))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: visualMode)
    }

    private var widgetWidth: CGFloat {
        switch state {
        case .idle:
            return 52
        case .recording:
            return 200
        case .processing:
            return 90
        case .selecting:
            return PillContainerMetrics.optionsWidth
        case .cancelled:
            return 130
        case .complete(_, let showCopied):
            return showCopied ? 160 : 130
        }
    }

    private var widgetHeight: CGFloat {
        switch state {
        case .idle:
            return 36
        case .recording:
            return 36
        case .processing:
            return 38
        case .selecting:
            return 98
        case .cancelled:
            return 38
        case .complete:
            return 38
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .idle:
            IdleView()
                .transition(.scale.combined(with: .opacity))

        case .recording(let duration, let liveText):
            RecordingView(
                duration: duration,
                liveText: liveText,
                audioMeter: audioMeter
            )
            .transition(.opacity)

        case .processing:
            ProcessingView()
                .transition(.opacity)

        case .selecting:
            SelectingView(onSelect: onOptionSelected)
                .transition(.opacity)

        case .cancelled:
            CancelledView()
                .transition(.opacity)

        case .complete(let mode, let showCopied):
            CompleteView(mode: mode, showCopied: showCopied)
                .transition(.opacity)
        }
    }
}

// MARK: - Idle View

private struct IdleView: View {
    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recording View

private struct RecordingView: View {
    let duration: TimeInterval
    let liveText: String
    let audioMeter: AudioMeter

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .modifier(PulseModifier())

                WaveformDots(audioMeter: audioMeter)

                Spacer()

                Text(duration.formatted)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.9))
            }

            Text(liveText)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 110, alignment: .center)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Processing View

private struct ProcessingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(.white.opacity(0.9), lineWidth: 1.5)
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 0.6).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("...")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Cancelled View

private struct CancelledView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))

            Text("Canceled")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Selecting View

private struct SelectingView: View {
    let onSelect: (SmartModeOption) -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(PillTranscriptionMode.all.enumerated()), id: \.element.id) { index, mode in
                    ModeButton(mode: mode, onSelect: {
                        onSelect(option(for: mode))
                    })
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom)
                                .combined(with: .opacity)
                                .animation(.spring(response: 0.22, dampingFraction: 0.75).delay(Double(index) * 0.03)),
                            removal: .opacity.animation(.easeOut(duration: 0.1))
                        )
                    )
                }
            }

            Button {
                onSelect(.cancel)
            } label: {
                Text("Don't change my yap")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "FF3633"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func option(for mode: PillTranscriptionMode) -> SmartModeOption {
        switch mode.id {
        case "slack": return .slack
        case "chat": return .chat
        case "email": return .email
        case "prompt": return .prompt
        default: return .slack
        }
    }
}

// MARK: - Mode Button

private struct ModeButton: View {
    let mode: PillTranscriptionMode
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Text(mode.shortcut)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(isHovered ? 0.5 : 0.25))
                    .frame(width: 12)

                Text(mode.label)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(isHovered ? 1 : 0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isHovered ? .white.opacity(0.1) : .clear)
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Complete View

private struct CompleteView: View {
    let mode: PillTranscriptionMode
    let showCopied: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "34D399"))
                .transition(.scale.animation(.spring(response: 0.2, dampingFraction: 0.6)))

            Text(showCopied ? "Copied" : mode.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: showCopied)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Waveform Dots

private struct WaveformDots: View {
    let audioMeter: AudioMeter

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(audioMeter.bars.enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(index < 4 ? Color(red: 0.98, green: 0.21, blue: 0.20) : .white.opacity(0.35))
                    .frame(width: 4, height: height(for: value))
                    .animation(.easeOut(duration: 0.08), value: value)
            }
        }
    }

    private func height(for value: Float) -> CGFloat {
        let clamped = max(0.05, min(1, CGFloat(value)))
        return 3 + (clamped * 12)
    }
}

// MARK: - Animation Modifiers

private struct PulseModifier: ViewModifier {
    @State private var opacity: Double = 1

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    opacity = 0.4
                }
            }
    }
}

// MARK: - Helpers

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

private extension TimeInterval {
    var formatted: String {
        let mins = Int(self) / 60
        let secs = Int(self) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
