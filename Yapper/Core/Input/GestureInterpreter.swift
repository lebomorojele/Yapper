import Foundation

final class GestureInterpreter: @unchecked Sendable {
    var onGesture: (@Sendable (InputGesture) -> Void)?

    private var isKeyDown = false
    private let lock = NSLock()

    func keyDown() {
        lock.lock()
        defer { lock.unlock() }
        guard !isKeyDown else { return }
        isKeyDown = true
    }

    func keyUp() {
        lock.lock()
        guard isKeyDown else {
            lock.unlock()
            return
        }
        isKeyDown = false
        lock.unlock()
        onGesture?(.singleTap)
    }
}
