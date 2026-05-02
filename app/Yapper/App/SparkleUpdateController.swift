import Foundation
import Sparkle

@MainActor
final class SparkleUpdateController {
    static let shared = SparkleUpdateController()

    private var updaterController: SPUStandardUpdaterController?

    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    private init() {}

    func start() {
        guard isAvailable, updaterController == nil else { return }
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        guard isAvailable else { return }
        start()
        updaterController?.checkForUpdates(nil)
    }
}
