import Foundation

// MARK: - Recording State

enum RecordingState: Equatable, Sendable {
    case idle
    case recording(isSmartMode: Bool)
    case recordingMeeting
    case processing
    case complete
}

// MARK: - Input Gesture

enum InputGesture: Sendable {
    case singleTap
    case doubleTap
    case holdStart
    case holdEnd
}

// MARK: - Smart Mode Option

enum SmartModeOption: String, CaseIterable, Identifiable, Sendable {
    case email = "Email"
    case chat = "Chat"
    case prompt = "Prompt"
    case polish = "Polish"
    case cancel = "Don’t change (Fn)"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .email: return "envelope"
        case .chat: return "message"
        case .prompt: return "chevron.left.forwardslash.chevron.right"
        case .polish: return "wand.and.stars"
        case .cancel: return "xmark"
        }
    }

    var shortcut: String {
        switch self {
        case .email: return "e"
        case .chat: return "c"
        case .prompt: return "r"
        case .polish: return "p"
        case .cancel: return ""
        }
    }

    var promptTemplate: String {
        switch self {
        case .email:
            return "Rewrite the following as a professional email. Return ONLY the email text, no explanations:\n\n{input}"
        case .chat:
            return "Make the following concise and friendly for a chat like Slack. Return ONLY the message, no explanations:\n\n{input}"
        case .prompt:
            return "Convert the following into a clear, detailed prompt for an AI coding assistant. Return ONLY the prompt, no explanations:\n\n{input}"
        case .polish:
            return "Fix grammar, punctuation, and clarity in the following. Return ONLY the corrected text, no explanations:\n\n{input}"
        case .cancel:
            return ""
        }
    }
}

// MARK: - Insertion Method

enum InsertionMethod: String, Codable, CaseIterable, Sendable {
    case axuiElement
    case clipboard
}

// MARK: - Settings

struct Settings: Codable, Sendable {
    var insertionMethod: InsertionMethod = .axuiElement
    var silenceThreshold: TimeInterval = 1.5
    var silenceDetectionEnabled: Bool = true
    var inputGain: Float = 1.0
    var openAIAPIKey: String?
    var llmModel: String = "gpt-4o-mini"

    static let `default` = Settings()
}

// MARK: - Settings Manager

final class SettingsManager: @unchecked Sendable {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let key = "com.yapper.settings"
    private let lock = NSLock()

    private init() {}

    var settings: Settings {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let data = defaults.data(forKey: key),
                  let s = try? JSONDecoder().decode(Settings.self, from: data) else {
                return .default
            }
            return s
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: key)
            }
        }
    }

    func update(_ transform: (inout Settings) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var current: Settings
        if let data = defaults.data(forKey: key),
           let s = try? JSONDecoder().decode(Settings.self, from: data) {
            current = s
        } else {
            current = .default
        }
        transform(&current)
        if let data = try? JSONEncoder().encode(current) {
            defaults.set(data, forKey: key)
        }
    }
}
