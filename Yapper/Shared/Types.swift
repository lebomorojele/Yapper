import Foundation

// MARK: - Recording State

enum RecordingState: Equatable, Sendable {
    case idle
    case ready
    case recording(isSmartMode: Bool)
    case recordingMeeting
    case processing
    case complete
    case completeClipboard
    case cancelled
}

enum RuntimeRecordingPhase: Equatable, Sendable {
    case idle
    case preparing
    case recording
    case recordingSmart
    case recordingMeeting
    case processing
    case selectingSmartMode
    case completed(InsertionOutcome?)
    case cancelled
    case failed(String?)
}

enum InsertionOutcome: String, Codable, Equatable, Sendable {
    case accessibility
    case clipboard
}

enum RecordingPurpose: String, Codable, Equatable, Sendable {
    case dictation
    case smart
    case meeting
}

enum RecordingDisposition: Equatable, Sendable {
    case stop
    case cancel
    case discard
    case failure(String?)
    case completion
}

struct RecordingSession: Equatable, Sendable {
    let id: UUID
    let purpose: RecordingPurpose
    let startedAt: Date
    var partialTranscript: String
    var meter: AudioMeter

    init(
        id: UUID = UUID(),
        purpose: RecordingPurpose,
        startedAt: Date = Date(),
        partialTranscript: String = "",
        meter: AudioMeter = .empty
    ) {
        self.id = id
        self.purpose = purpose
        self.startedAt = startedAt
        self.partialTranscript = partialTranscript
        self.meter = meter
    }
}

struct RecordingSessionConfiguration: Equatable, Sendable {
    var purpose: RecordingPurpose
    var autoStopOnSilence: Bool
    var shouldInsertText: Bool
}

struct RecordingSessionResult: Equatable, Sendable {
    var session: RecordingSession
    var transcript: String
    var insertionOutcome: InsertionOutcome?
}

struct AudioMeter: Codable, Equatable, Sendable {
    var level: Float
    var peak: Float
    var bars: [Float]

    static let empty = AudioMeter(level: 0, peak: 0, bars: Array(repeating: 0, count: 6))
}

enum PermissionAuthorizationStatus: String, Codable, Equatable, Sendable {
    case authorized
    case denied
    case notDetermined
}

struct PermissionSnapshot: Equatable, Sendable {
    var microphone: PermissionAuthorizationStatus = .notDetermined
    var accessibility: PermissionAuthorizationStatus = .denied
    var inputMonitoring: PermissionAuthorizationStatus = .denied

    var hasHotkeyPermissions: Bool {
        accessibility == .authorized && inputMonitoring == .authorized
    }
}

enum HotkeyMonitoringStatus: Equatable, Sendable {
    case stopped
    case missingPermissions
    case temporarilyDisabled
    case failedToInstall
    case ready
}

struct AppRuntimeState: Equatable, Sendable {
    var recordingPhase: RuntimeRecordingPhase = .idle
    var permissions: PermissionSnapshot = PermissionSnapshot()
    var hotkeyMonitoringStatus: HotkeyMonitoringStatus = .stopped
    var modelReady = false
    var session: RecordingSession? = nil
    var recordingStartTime: Date? = nil

    var displayRecordingState: RecordingState {
        switch recordingPhase {
        case .idle:
            return .idle
        case .preparing:
            return .ready
        case .recording:
            return .recording(isSmartMode: false)
        case .recordingSmart:
            return .recording(isSmartMode: true)
        case .recordingMeeting:
            return .recordingMeeting
        case .processing:
            return .processing
        case .selectingSmartMode:
            return .idle
        case .completed(let outcome):
            return outcome == .clipboard ? .completeClipboard : .complete
        case .cancelled:
            return .cancelled
        case .failed:
            return .idle
        }
    }

    var showsSmartOptions: Bool {
        recordingPhase == .selectingSmartMode
    }

    var partialTranscript: String {
        session?.partialTranscript ?? ""
    }

    var audioMeter: AudioMeter {
        session?.meter ?? .empty
    }
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
    case slack = "Slack"
    case chat = "Chat"
    case email = "Email"
    case prompt = "Prompt"
    case cancel = "Don't change my yap"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .slack: return "bubble.left.and.bubble.right"
        case .chat: return "message"
        case .email: return "envelope"
        case .prompt: return "chevron.left.forwardslash.chevron.right"
        case .cancel: return "xmark"
        }
    }

    var shortcut: String {
        switch self {
        case .slack: return "s"
        case .chat: return "c"
        case .email: return "e"
        case .prompt: return "r"
        case .cancel: return ""
        }
    }

    var promptTemplate: String {
        switch self {
        case .slack:
            return "Rewrite the following for a polished Slack message. Keep it concise, clear, and natural. Return ONLY the message text:\n\n{input}"
        case .chat:
            return "Make the following concise and friendly for a chat conversation. Return ONLY the message text:\n\n{input}"
        case .email:
            return "Rewrite the following as a professional email. Return ONLY the email text:\n\n{input}"
        case .prompt:
            return "Convert the following into a clear, detailed prompt for an AI assistant. Return ONLY the prompt:\n\n{input}"
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

// MARK: - Smart Mode

struct TranscriptionMode: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var prompt: String
}

enum HistoryEntryKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case dictation
    case meeting

    var id: String { rawValue }
}

struct HistoryEnrichment: Codable, Equatable, Sendable {
    var summary: String?
    var actionItems: [String]
    var lastError: String?

    init(summary: String? = nil, actionItems: [String] = [], lastError: String? = nil) {
        self.summary = summary
        self.actionItems = actionItems
        self.lastError = lastError
    }
}

struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var kind: HistoryEntryKind
    var transcript: String
    var createdAt: Date
    var duration: TimeInterval
    var insertionOutcome: InsertionOutcome?
    var exportedFilePath: String?
    var enrichment: HistoryEnrichment

    init(
        id: UUID = UUID(),
        kind: HistoryEntryKind,
        transcript: String,
        createdAt: Date = Date(),
        duration: TimeInterval,
        insertionOutcome: InsertionOutcome? = nil,
        exportedFilePath: String? = nil,
        enrichment: HistoryEnrichment = HistoryEnrichment()
    ) {
        self.id = id
        self.kind = kind
        self.transcript = transcript
        self.createdAt = createdAt
        self.duration = duration
        self.insertionOutcome = insertionOutcome
        self.exportedFilePath = exportedFilePath
        self.enrichment = enrichment
    }
}

// MARK: - Settings

struct Settings: Codable, Sendable {
    var insertionMethod: InsertionMethod = .axuiElement
    var launchAtLogin: Bool = false
    var silenceThreshold: TimeInterval = 1.5
    var silenceDetectionEnabled: Bool = true
    var inputGain: Float = 1.0
    var openAIAPIKey: String?
    var anthropicAPIKey: String?
    var ollamaEndpoint: String = "http://localhost:11434"
    var llmModel: String = "gpt-4o-mini"
    
    // Audio Settings
    var selectedAudioDeviceId: String? = nil
    
    // New Settings
    var aiProvider: String = "OpenAI"
    var autoRecordMeetings: Bool = false
    var saveTranscripts: Bool = true
    var saveLocation: String? = nil
    var meetingSummaryMode: String = "bullets"
    var transcriptionModes: [TranscriptionMode] = [
        TranscriptionMode(name: "Slack", prompt: "Rewrite the following for a polished Slack message. Keep it concise, clear, and natural. Return ONLY the message text:\n\n{input}"),
        TranscriptionMode(name: "Chat", prompt: "Make the following concise and friendly for a chat conversation. Return ONLY the message text:\n\n{input}"),
        TranscriptionMode(name: "Email", prompt: "Rewrite the following as a professional email. Return ONLY the email text, no explanations:\n\n{input}")
    ]

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
