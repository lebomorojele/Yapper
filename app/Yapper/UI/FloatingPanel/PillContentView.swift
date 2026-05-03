import AppKit
import SwiftUI

private enum PebbleMode: Equatable {
    case listening
    case thinking
    case speaking
}

private enum PebbleMetrics {
    private static let designScale: CGFloat = 2.0 / 3.0
    static let idleWidth: CGFloat = 72
    static let maxContentWidth: CGFloat = 320
    static let height: CGFloat = 36 * designScale
    static let horizontalPadding: CGFloat = 20 * designScale
    static let verticalPadding: CGFloat = 6 * designScale
    static let fontSize: CGFloat = 17 * designScale
    static let fontWeight: Font.Weight = .medium
    static let nsFontWeight: NSFont.Weight = .medium
}

struct PillContentView: View {
    var state: RecordingState = .idle
    var partialTranscript: String = ""
    var audioMeter: AudioMeter = .empty
    var resolvedWidth: CGFloat? = nil

    private var mode: PebbleMode {
        switch state {
        case .processing:
            return .thinking
        case .inserted, .copied, .cancelled, .failed:
            return .speaking
        case .listening:
            return partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .listening : .speaking
        case .idle, .loading:
            return .listening
        }
    }

    static func preferredWidth(for state: RecordingState, partialTranscript: String) -> CGFloat {
        switch state {
        case .processing, .listening:
            let trimmed = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return PebbleMetrics.idleWidth }
            return widthForText(visibleTranscriptText(from: trimmed))
        case .inserted:
            return widthForText("Inserted")
        case .copied:
            return widthForText("Copied")
        case .cancelled:
            return widthForText("Canceled")
        case .failed:
            return widthForText("Failed")
        case .idle, .loading:
            return PebbleMetrics.idleWidth
        }
    }

    static func resolvedWidth(
        currentWidth: CGFloat,
        state: RecordingState,
        partialTranscript: String
    ) -> CGFloat {
        let preferredWidth = preferredWidth(for: state, partialTranscript: partialTranscript)
        let trimmedTranscript = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        switch state {
        case .listening where !trimmedTranscript.isEmpty,
             .processing where !trimmedTranscript.isEmpty:
            return max(currentWidth, preferredWidth)
        default:
            return preferredWidth
        }
    }

    static var preferredHeight: CGFloat {
        PebbleMetrics.height
    }

    private static func visibleTranscriptText(from partialTranscript: String) -> String {
        let words = partialTranscript
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        let visibleCount = 7
        let start = max(words.count - visibleCount, 0)
        return words[start..<words.count].joined(separator: " ")
    }

    private static func widthForText(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: PebbleMetrics.fontSize, weight: PebbleMetrics.nsFontWeight)
        let measuredTextWidth = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        let paddedWidth = measuredTextWidth + (PebbleMetrics.horizontalPadding * 2)
        return min(max(PebbleMetrics.idleWidth, paddedWidth), PebbleMetrics.maxContentWidth)
    }

    var body: some View {
        DictationPebble(
            mode: mode,
            state: state,
            partialTranscript: partialTranscript,
            resolvedWidth: resolvedWidth
        )
    }
}

private struct DictationPebble: View {
    @Environment(\.colorScheme) private var colorScheme

    let mode: PebbleMode
    let state: RecordingState
    let partialTranscript: String
    let resolvedWidth: CGFloat?

    @State private var animateDots = false

    private var dotsMove: Bool {
        mode == .thinking || mode == .listening
    }

    private var width: CGFloat {
        resolvedWidth ?? PillContentView.preferredWidth(for: state, partialTranscript: partialTranscript)
    }

    private var foregroundColor: Color {
        colorScheme == .dark ? .white.opacity(0.80) : .black.opacity(0.40)
    }

    var body: some View {
        Group {
            if mode == .speaking {
                if liveTranscriptWords.isEmpty {
                    Text(statusPhrase)
                        .font(.system(size: PebbleMetrics.fontSize, weight: PebbleMetrics.fontWeight))
                        .foregroundStyle(foregroundColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .minimumScaleFactor(0.82)
                        .padding(.horizontal, PebbleMetrics.horizontalPadding)
                        .padding(.vertical, PebbleMetrics.verticalPadding)
                } else {
                    SmoothTranscriptStrip(words: liveTranscriptWords, foregroundColor: foregroundColor)
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(foregroundColor)
                            .frame(width: 4, height: 4)
                            .opacity(animateDots ? 1 : 0.4)
                            .offset(y: animateDots ? -1.5 : 1.5)
                            .animation(
                                .easeInOut(duration: 0.70)
                                    .repeatForever()
                                    .delay(Double(index) * 0.12),
                                value: animateDots
                            )
                    }
                }
                .frame(width: 22, height: 10, alignment: .center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .accessibilityLabel(accessibilityLabel)
            }
        }
        .frame(width: width, height: PebbleMetrics.height)
        .pebbleGlass(isActive: dotsMove)
        .animation(.easeOut(duration: 0.18), value: mode)
        .onAppear {
            animateDots = true
        }
        .onChange(of: mode) { _, _ in
            animateDots = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animateDots = true
            }
        }
    }

    private var liveTranscriptWords: [String] {
        let trimmed = partialTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private var statusPhrase: String {
        switch state {
        case .inserted:
            return "Inserted"
        case .copied:
            return "Copied"
        case .cancelled:
            return "Canceled"
        case .failed:
            return "Failed"
        default:
            return "Yapper"
        }
    }

    private var accessibilityLabel: String {
        switch mode {
        case .thinking:
            return "Yapper processing"
        case .listening:
            return "Yapper listening"
        case .speaking:
            return "Yapper status"
        }
    }
}

private struct SmoothTranscriptStrip: View {
    let words: [String]
    let foregroundColor: Color
    @State private var visibleTokens: [TranscriptToken] = []

    var body: some View {
        HStack(spacing: 5) {
            ForEach(visibleTokens) { token in
                Text(token.text)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        )
                    )
            }
        }
        .font(.system(size: PebbleMetrics.fontSize, weight: PebbleMetrics.fontWeight))
        .foregroundStyle(foregroundColor)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .center)
        .clipped()
        .padding(.horizontal, PebbleMetrics.horizontalPadding)
        .padding(.vertical, PebbleMetrics.verticalPadding)
        .onAppear {
            visibleTokens = tokens(from: words)
        }
        .onChange(of: words) { _, newWords in
            withAnimation(.easeOut(duration: 0.16)) {
                visibleTokens = tokens(from: newWords)
            }
        }
    }

    private func tokens(from words: [String]) -> [TranscriptToken] {
        let visibleCount = 7
        let start = max(words.count - visibleCount, 0)
        return words[start..<words.count].enumerated().map { offset, word in
            TranscriptToken(id: start + offset, text: word)
        }
    }
}

private struct TranscriptToken: Identifiable, Equatable {
    let id: Int
    let text: String
}

private struct PebbleGlassModifier: ViewModifier {
    var isActive = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Capsule(style: .continuous)
                        .fill(.regularMaterial)
                    Capsule(style: .continuous)
                        .fill((isActive ? Color(red: 0.09, green: 0.75, blue: 0.73) : .white).opacity(isActive ? 0.18 : 0.58))
                    LinearGradient(
                        colors: [.white.opacity(0.72), .white.opacity(0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(Capsule(style: .continuous))
                }
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
    }
}

private extension View {
    func pebbleGlass(isActive: Bool = false) -> some View {
        modifier(PebbleGlassModifier(isActive: isActive))
    }
}
