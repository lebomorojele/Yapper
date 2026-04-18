import SwiftUI

struct PillContentView: View {
    var state: RecordingState = .idle
    var partialTranscript: String = ""
    var showOptions: Bool = false
    var audioLevel: Float = 0
    var onOptionSelected: (SmartModeOption) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            mainPill
            if showOptions {
                optionsPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(0.88))
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Main Pill

    @ViewBuilder
    private var mainPill: some View {
        HStack(spacing: 12) {
            indicator
            label
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .idle:
            EmptyView()
        case .recording:
            WaveformView(audioLevel: audioLevel)
        case .processing:
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
        }
    }

    @ViewBuilder
    private var label: some View {
        switch state {
        case .idle:
            EmptyView()
        case .recording(let smart):
            VStack(alignment: .leading, spacing: 2) {
                Text(smart ? "Smart Mode" : "Listening...")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if !partialTranscript.isEmpty {
                    Text(partialTranscript)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        case .processing:
            Text("Processing...")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Smart Mode Options

    @ViewBuilder
    private var optionsPanel: some View {
        VStack(spacing: 8) {
            Divider()
                .background(.white.opacity(0.2))

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 8
            ) {
                ForEach(SmartModeOption.allCases.filter { $0 != .cancel }) { option in
                    Button {
                        onOptionSelected(option)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 11))
                            Text(option.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.white.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                onOptionSelected(.cancel)
            } label: {
                Text("Cancel")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

// MARK: - Waveform Visualization

struct WaveformView: View {
    let audioLevel: Float
    private let barCount = 5

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08)) { timeline in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        audioLevel: audioLevel,
                        index: index,
                        time: timeline.date.timeIntervalSinceReferenceDate
                    )
                }
            }
        }
    }
}

struct WaveformBar: View {
    let audioLevel: Float
    let index: Int
    let time: TimeInterval

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(.red)
            .frame(width: 3, height: barHeight)
            .animation(.easeInOut(duration: 0.1), value: barHeight)
    }

    private var barHeight: CGFloat {
        let minH: CGFloat = 4
        let maxH: CGFloat = 20
        let level = CGFloat(max(0.05, audioLevel))

        // Each bar oscillates at a slightly different phase/frequency
        let freq = 2.0 + Double(index) * 0.7
        let phase = Double(index) * 0.8
        let wave = sin(time * freq + phase)

        // Combine audio level with oscillation for organic movement
        let amplitude = minH + (maxH - minH) * level * (0.4 + 0.6 * CGFloat((wave + 1) / 2))
        return max(minH, min(maxH, amplitude))
    }
}

struct SmartModeButton: View {
    let option: SmartModeOption
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 11))
                Text(option.rawValue)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
