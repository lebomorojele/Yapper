import Foundation

enum SoundEffect {
    case recordingStart, recordingStop, processingComplete, error
}

final class SoundManager: @unchecked Sendable {
    static let shared = SoundManager()
    private let projectDir = FileManager.default.currentDirectoryPath
    private let systemSoundDir = "/System/Library/Sounds/"
    
    private init() {}
    
    func play(_ effect: SoundEffect) {
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
            
            var soundPath = ""
            
            switch effect {
            case .recordingStart:
                soundPath = "\(self.projectDir)/start.mp3"
            case .recordingStop, .processingComplete:
                soundPath = "\(self.projectDir)/success.mp3"
            case .error:
                soundPath = self.systemSoundDir + "Glass.aiff"
            }
            
            // Fallback to system sounds if custom not found
            if !FileManager.default.fileExists(atPath: soundPath) {
                if effect == .error {
                    soundPath = self.systemSoundDir + "Glass.aiff"
                } else {
                    soundPath = self.systemSoundDir + "Pop.aiff"
                }
            }
            
            process.arguments = [soundPath]
            try? process.run()
            process.waitUntilExit()
        }
    }
}
