import Foundation

// MARK: - Recording State

enum RecordingState: Equatable, Sendable {
    case idle
    case loading
    case listening
    case processing
    case inserted
    case copied
    case cancelled
    case failed
}

enum RuntimeRecordingPhase: Equatable, Sendable {
    case idle
    case loading
    case recording
    case processing
    case completed(InsertionOutcome?)
    case cancelled
    case failed(String?)
}

enum InsertionOutcome: String, Codable, Equatable, Sendable {
    case accessibility
    case clipboard
}

enum RecordingDisposition: Equatable, Sendable {
    case stop
    case cancel
    case failure(String?)
    case completion
}

struct RecordingSession: Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    var partialTranscript: String
    var meter: AudioMeter

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        partialTranscript: String = "",
        meter: AudioMeter = .empty
    ) {
        self.id = id
        self.startedAt = startedAt
        self.partialTranscript = partialTranscript
        self.meter = meter
    }
}

struct RecordingSessionConfiguration: Equatable, Sendable {
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
        if !modelReady {
            return .loading
        }

        switch recordingPhase {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .recording:
            return .listening
        case .processing:
            return .processing
        case .completed(let outcome):
            return outcome == .clipboard ? .copied : .inserted
        case .cancelled:
            return .cancelled
        case .failed:
            return .failed
        }
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
}

// MARK: - Insertion Method

enum InsertionMethod: String, Codable, CaseIterable, Sendable {
    case axuiElement
    case clipboard
}

// MARK: - Settings

struct Settings: Codable, Sendable {
    var insertionMethod: InsertionMethod = .axuiElement
    var launchAtLogin: Bool = false
    var silenceThreshold: TimeInterval = 1.5
    var silenceDetectionEnabled: Bool = true
    var inputGain: Float = 1.0
    var selectedAudioDeviceId: String? = nil
    var cleanupEnabled: Bool = true
    var modelCleanupWordThreshold: Int = 10

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
