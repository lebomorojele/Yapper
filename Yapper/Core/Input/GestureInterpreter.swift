import Foundation

final class GestureInterpreter: @unchecked Sendable {
    var onGesture: (@Sendable (InputGesture) -> Void)?

    private let doubleTapWindow: TimeInterval = 0.3
    private let holdThreshold: TimeInterval = 0.4

    private var keyDownTime: Date?
    private var tapCount: Int = 0
    private var isKeyDown = false
    private var holdFired = false

    private var holdWorkItem: DispatchWorkItem?
    private var singleTapWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.yapper.gesture")

    func keyDown() {
        queue.async { [weak self] in
            self?.handleKeyDown()
        }
    }

    func keyUp() {
        queue.async { [weak self] in
            self?.handleKeyUp()
        }
    }

    // MARK: - Internal (always called on self.queue)

    private func handleKeyDown() {
        isKeyDown = true
        holdFired = false
        keyDownTime = Date()
        tapCount += 1

        // Cancel pending single-tap evaluation
        singleTapWorkItem?.cancel()
        singleTapWorkItem = nil

        // Start hold timer
        holdWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isKeyDown else { return }
            self.holdFired = true
            self.onGesture?(.holdStart)
        }
        holdWorkItem = item
        queue.asyncAfter(deadline: .now() + holdThreshold, execute: item)
    }

    private func handleKeyUp() {
        isKeyDown = false
        holdWorkItem?.cancel()
        holdWorkItem = nil

        guard let downTime = keyDownTime else { return }
        let duration = Date().timeIntervalSince(downTime)

        if holdFired || duration >= holdThreshold {
            // Was a hold — fire holdEnd
            holdFired = false
            tapCount = 0
            onGesture?(.holdEnd)
            return
        }

        // Short press — could be single or double tap
        if tapCount >= 2 {
            // Second tap arrived within window → double tap
            singleTapWorkItem?.cancel()
            singleTapWorkItem = nil
            tapCount = 0
            onGesture?(.doubleTap)
        } else {
            // First tap — wait for possible second tap
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.tapCount = 0
                self.onGesture?(.singleTap)
            }
            singleTapWorkItem = item
            queue.asyncAfter(deadline: .now() + doubleTapWindow, execute: item)
        }
    }
}
