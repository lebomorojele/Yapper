import SwiftUI

private enum PillMetrics {
    static let compactWidth: CGFloat = 317
    static let compactHeight: CGFloat = 48
    static let optionsWidth: CGFloat = 317
    static let optionsHeight: CGFloat = 124
    static let cardBackground = Color.black
    static let muted = Color(red: 0.64, green: 0.64, blue: 0.66)
    static let accent = Color(red: 0.98, green: 0.21, blue: 0.20)
    static let inactive = Color(red: 0.35, green: 0.35, blue: 0.35)
}

struct PillContentView: View {
    var state: RecordingState = .idle
    var partialTranscript: String = ""
    var showOptions: Bool = false
    var audioLevel: Float = 0
    var recordingStartTime: Date? = nil
    var onOptionSelected: (SmartModeOption) -> Void = { _ in }

    var body: some View {
        Group {
            if showOptions {
                SmartModeSelectionView(onOptionSelected: onOptionSelected)
            } else {
                switch state {
                case .idle:
                    EmptyView()
                case .ready:
                    PillShell {
                        WaveformView(audioLevel: 0, activeBars: 0)
                        PillLabel("Ready")
                        PillTimer(
                            textColor: PillMetrics.muted,
                            startTime: nil,
                            fallback: "00:00"
                        )
                    }
                case .recording:
                    PillShell {
                        WaveformView(audioLevel: audioLevel, activeBars: 6)
                        PillLabel(partialTranscript.isEmpty ? "Listening..." : partialTranscript)
                        PillTimer(
                            textColor: PillMetrics.accent,
                            startTime: recordingStartTime,
                            fallback: "00:00"
                        )
                    }
                case .recordingMeeting:
                    PillShell {
                        WaveformView(audioLevel: audioLevel, activeBars: 6)
                        PillLabel("recording meeting")
                        PillTimer(
                            textColor: PillMetrics.accent,
                            startTime: recordingStartTime,
                            fallback: "00:00"
                        )
                    }
                case .processing:
                    ProcessingPill()
                case .complete:
                    StatusPill(title: "Complete")
                case .completeClipboard:
                    StatusPill(title: "Copied to clipboard")
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showOptions)
        .animation(.easeInOut(duration: 0.2), value: state)
    }
}

private struct PillShell<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 12) {
            content
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: PillMetrics.compactWidth, height: PillMetrics.compactHeight)
        .background(PillMetrics.cardBackground)
        .clipShape(Capsule(style: .continuous))
    }
}

private struct PillLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(PillMetrics.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PillTimer: View {
    let textColor: Color
    let startTime: Date?
    let fallback: String

    var body: some View {
        Group {
            if let startTime {
                TimelineView(.periodic(from: startTime, by: 1.0)) { timeline in
                    Text(Self.timeString(from: max(0, timeline.date.timeIntervalSince(startTime))))
                        .font(.system(size: 14, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                }
            } else {
                Text(fallback)
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(textColor)
            }
        }
        .frame(width: 42, alignment: .trailing)
    }

    private static func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct WaveformView: View {
    let audioLevel: Float
    let activeBars: Int
    private let minHeights: [CGFloat] = [10, 13, 16, 9, 12, 7, 2, 2, 2]
    private let maxHeights: [CGFloat] = [10, 14, 17, 10, 12, 8, 2, 2, 2]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: false)) { timeline in
            HStack(spacing: 1.22) {
                ForEach(Array(minHeights.enumerated()), id: \.offset) { index, minHeight in
                    RoundedRectangle(cornerRadius: 2.44, style: .continuous)
                        .fill(index < activeBars ? PillMetrics.accent : PillMetrics.inactive)
                        .frame(width: 1.83, height: barHeight(at: index, minHeight: minHeight, time: timeline.date.timeIntervalSinceReferenceDate))
                        .opacity(index < activeBars ? (index == activeBars - 1 ? 0.4 : 1.0) : 0.4)
                }
            }
            .frame(width: 39, alignment: .leading)
        }
    }

    private func barHeight(at index: Int, minHeight: CGFloat, time: TimeInterval) -> CGFloat {
        guard index < activeBars else { return minHeight }
        let pulse = CGFloat(abs(sin((time * 5) + Double(index) * 0.55))) * 0.18
        let normalized = max(CGFloat(audioLevel), pulse)
        let maxHeight = maxHeights[index]
        let phaseOffset = CGFloat((index % 3)) * 0.08
        let animated = min(1, normalized + phaseOffset)
        return minHeight + ((maxHeight - minHeight) * animated)
    }
}

private struct ProcessingPill: View {
    @State private var progressOffset: CGFloat = -10

    var body: some View {
        PillShell {
            Text("Processing")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 36, height: 5)

                Capsule()
                    .fill(Color.white.opacity(0.86))
                    .frame(width: 20, height: 5)
                    .offset(x: progressOffset)
            }
            .frame(width: 36, height: 5)
            .clipShape(Capsule())
            .onAppear {
                progressOffset = -10
                withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                    progressOffset = 16
                }
            }
        }
    }
}

private struct StatusPill: View {
    let title: String

    var body: some View {
        PillShell {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white)

            Spacer(minLength: 0)

            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.94))
                .frame(width: 24, height: 18)
        }
    }
}

private struct SmartModeSelectionView: View {
    let onOptionSelected: (SmartModeOption) -> Void
    private let options: [SmartModeOption] = [.slack, .chat, .email, .prompt]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(options) { option in
                    Button(option.rawValue) {
                        onOptionSelected(option)
                    }
                    .buttonStyle(SmartModeTabButtonStyle())
                }
            }
            .frame(height: 38)

            Button {
                onOptionSelected(.cancel)
            } label: {
                Text("Don't change my yap")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PillMetrics.accent)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 11)
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
        .frame(width: PillMetrics.optionsWidth, height: PillMetrics.optionsHeight, alignment: .topLeading)
        .background(PillMetrics.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

private struct SmartModeTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.18 : 0.10))
            )
    }
}
