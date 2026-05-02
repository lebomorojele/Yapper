import Foundation

enum SoundEffect {
    case recordingStart, recordingStop, processingComplete, error
}

final class SoundManager: @unchecked Sendable {
    static let shared = SoundManager()
    private let systemSoundDir = "/System/Library/Sounds/"
    
    private init() {}
    
    func play(_ effect: SoundEffect) {
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
            
            process.arguments = [self.soundURL(for: effect).path]
            try? process.run()
            process.waitUntilExit()
        }
    }

    private func soundURL(for effect: SoundEffect) -> URL {
        switch effect {
        case .recordingStart:
            return bundledSound(named: "start") ?? systemSound(named: "Pop")
        case .recordingStop, .processingComplete:
            return bundledSound(named: "success") ?? systemSound(named: "Pop")
        case .error:
            return systemSound(named: "Glass")
        }
    }

    private func bundledSound(named name: String) -> URL? {
        AppResourceLocator.url(
            forResource: name,
            withExtension: "mp3",
            subdirectory: "Sounds"
        )
    }

    private func systemSound(named name: String) -> URL {
        URL(fileURLWithPath: systemSoundDir).appendingPathComponent("\(name).aiff")
    }
}
