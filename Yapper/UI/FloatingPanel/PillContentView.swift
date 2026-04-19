import SwiftUI

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
                SmartRecordOptions(onOptionSelected: onOptionSelected)
            } else {
                switch state {
                case .idle:
                    IdleView()
                case .ready:
                    Ready()
                case .recording:
                    SimpleSmartRecording(transcript: partialTranscript, audioLevel: audioLevel, startTime: recordingStartTime ?? Date())
                case .recordingMeeting:
                    MeetingRecordingView(audioLevel: audioLevel, startTime: recordingStartTime ?? Date())
                case .processing:
                    ProcessingView()
                case .complete:
                    ProcessingComplete()
                case .completeClipboard:
                    ProcessingCompleteClipboardFallback()
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showOptions)
        .animation(.easeInOut(duration: 0.4), value: state)
    }
}

// MARK: - Idle State
struct IdleView: View {
    var body: some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(width: 317, height: 40)
            .background(.black)
            .cornerRadius(22)
    }
}

// MARK: - Ready State
struct Ready: View {
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 1.22) {
                ForEach(0..<7) { _ in
                    Rectangle()
                        .foregroundColor(.clear)
                        .frame(width: 1.83, height: 1.83)
                        .background(Color(red: 0.35, green: 0.35, blue: 0.35))
                        .cornerRadius(2.44)
                        .opacity(0.40)
                }
            }
            .frame(width: 39)
            Text("Ready")
                .font(.custom("SF Pro", size: 14))
                .lineSpacing(18)
                .foregroundColor(Color(red: 0.64, green: 0.64, blue: 0.66))
            HStack(alignment: .top, spacing: 10) {
                Text("00:00")
                    .font(.custom("SF Pro", size: 14))
                    .lineSpacing(18)
                    .foregroundColor(Color(red: 0.64, green: 0.64, blue: 0.66))
            }
        }
        .padding(12)
        .frame(width: 317)
        .background(.black)
        .cornerRadius(22)
    }
}

// MARK: - Recording State
struct SimpleSmartRecording: View {
    let transcript: String
    let audioLevel: Float
    let startTime: Date

    var body: some View {
        HStack(spacing: 12) {
            FigmaWaveform(audioLevel: audioLevel)
            
            Text(transcript.isEmpty ? "Listening..." : transcript)
                .font(.custom("SF Pro", size: 14))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(Color(red: 0.64, green: 0.64, blue: 0.66))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TimelineView(.periodic(from: startTime, by: 1.0)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(startTime))
                Text(timeString(from: elapsed))
                    .font(.custom("SF Pro", size: 14).weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(Color(red: 0.98, green: 0.21, blue: 0.20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 317, height: 44)
        .background(.black)
        .cornerRadius(22)
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Meeting Recording State
struct MeetingRecordingView: View {
    let audioLevel: Float
    let startTime: Date

    var body: some View {
        HStack(spacing: 12) {
            FigmaWaveform(audioLevel: audioLevel)
            
            Text("Recording meeting...")
                .font(.custom("SF Pro", size: 14))
                .foregroundColor(Color(red: 0.64, green: 0.64, blue: 0.66))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            TimelineView(.periodic(from: startTime, by: 1.0)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(startTime))
                Text(timeString(from: elapsed))
                    .font(.custom("SF Pro", size: 14).weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(Color(red: 0.98, green: 0.21, blue: 0.20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 317, height: 44)
        .background(.black)
        .cornerRadius(22)
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Figma Waveform
struct FigmaWaveform: View {
    let audioLevel: Float
    
    var body: some View {
        HStack(spacing: 1.5) {
            WaveBar(level: audioLevel, index: 0, minH: 3, maxH: 10)
            WaveBar(level: audioLevel, index: 1, minH: 4, maxH: 14)
            WaveBar(level: audioLevel, index: 2, minH: 5, maxH: 17)
            WaveBar(level: audioLevel, index: 3, minH: 3, maxH: 10)
            WaveBar(level: audioLevel, index: 4, minH: 4, maxH: 12)
            WaveBar(level: audioLevel, index: 5, minH: 2, maxH: 8).opacity(0.6)
            WaveBar(level: 0, index: 6, minH: 2, maxH: 2).opacity(0.4).foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
            WaveBar(level: 0, index: 7, minH: 2, maxH: 2).opacity(0.4).foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
            WaveBar(level: 0, index: 8, minH: 2, maxH: 2).opacity(0.4).foregroundColor(Color(red: 0.35, green: 0.35, blue: 0.35))
        }
        .frame(width: 39)
    }
}

struct WaveBar: View {
    let level: Float
    let index: Int
    let minH: CGFloat
    let maxH: CGFloat
    
    var body: some View {
        Rectangle()
            .foregroundColor(Color(red: 0.98, green: 0.21, blue: 0.20))
            .frame(width: 2, height: barHeight)
            .cornerRadius(2.44)
            .animation(.easeInOut(duration: 0.1), value: barHeight)
    }
    
    private var barHeight: CGFloat {
        if maxH == minH { return minH } // Static dots
        let boost = CGFloat(max(0, level))
        let amplitude = minH + (maxH - minH) * boost * 1.5
        return max(minH, min(maxH, amplitude))
    }
}

// MARK: - Processing State
struct ProcessingView: View {
    @State private var offset: CGFloat = -14
    
    var body: some View {
        HStack {
            Text("Processing")
                .font(.custom("SF Pro", size: 14))
                .foregroundColor(.white)
            
            Spacer()
            
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color(red: 0.36, green: 0.36, blue: 0.36))
                    .frame(width: 36, height: 5)
                    .cornerRadius(16)
                
                Rectangle()
                    .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85))
                    .frame(width: 20, height: 5)
                    .cornerRadius(16)
                    .offset(x: offset)
            }
            .frame(width: 36, height: 5)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 16)
        .frame(width: 317, height: 44)
        .background(.black)
        .cornerRadius(22)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                offset = 16
            }
        }
    }
}

// MARK: - Processing Complete State
struct ProcessingComplete: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Complete")
                .font(.custom("SF Pro", size: 14))
                .foregroundColor(.white)
            ZStack() {
                Text("􀁢")
                    .font(.custom("SF Pro Text", size: 20))
                    .foregroundColor(Color(red: 0.94, green: 0.94, blue: 0.96))
            }
            .frame(width: 24, height: 18)
        }
        .padding(12)
        .frame(width: 317, height: 38)
        .background(.black)
        .cornerRadius(22)
    }
}

// MARK: - Clipboard Fallback State
struct ProcessingCompleteClipboardFallback: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Complete → copied to clipboard")
                .font(.custom("SF Pro", size: 14))
                .foregroundColor(.white)
            ZStack() {
                Text("􀁢")
                    .font(.custom("SF Pro Text", size: 20))
                    .foregroundColor(Color(red: 0.94, green: 0.94, blue: 0.96))
            }
            .frame(width: 24, height: 18)
        }
        .padding(12)
        .frame(width: 317, height: 38)
        .background(.black)
        .cornerRadius(22)
    }
}

// MARK: - Smart Options State
struct SmartRecordOptions: View {
    var onOptionSelected: (SmartModeOption) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text("􀖀")
                    .font(.custom("SF Pro Text", size: 28).weight(.bold))
                    .foregroundColor(Color(red: 0.22, green: 0.75, blue: 0.35))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Finished Yapping?")
                        .font(.custom("SF Pro", size: 16).weight(.semibold))
                        .foregroundColor(.white)
                    Text("Would you like to change the tone of your yap?")
                        .font(.custom("SF Pro", size: 14))
                        .foregroundColor(Color(red: 0.51, green: 0.51, blue: 0.51))
                }
            }
            .padding(.horizontal, 8)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SmartButton(title: "Polish", option: .polish, action: { onOptionSelected(.polish) })
                    SmartButton(title: "Chat", option: .chat, action: { onOptionSelected(.chat) })
                }
                HStack(spacing: 12) {
                    SmartButton(title: "Email", option: .email, action: { onOptionSelected(.email) })
                    SmartButton(title: "Prompt", option: .prompt, action: { onOptionSelected(.prompt) })
                }
                
                Button {
                    onOptionSelected(.cancel)
                } label: {
                    Text("Don’t change (Fn)")
                        .font(.custom("SF Pro", size: 16).weight(.medium))
                        .foregroundColor(Color(red: 0.98, green: 0.21, blue: 0.20))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.11, green: 0.06, blue: 0.07))
                        .cornerRadius(300)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .frame(width: 367)
        .background(.black)
        .cornerRadius(42)
        .shadow(color: Color.black.opacity(0.25), radius: 16, y: 8)
    }
}

struct SmartButton: View {
    let title: String
    let option: SmartModeOption
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("SF Pro", size: 16).weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.17, green: 0.17, blue: 0.18))
                .cornerRadius(300)
        }
        .buttonStyle(.plain)
    }
}
