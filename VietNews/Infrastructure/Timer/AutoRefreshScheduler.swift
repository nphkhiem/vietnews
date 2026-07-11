import Foundation

protocol RefreshScheduling: AnyObject {
    var onTick: (() -> Void)? { get set }
    func start(interval: TimeInterval)
    func stop()
}

final class AutoRefreshScheduler: RefreshScheduling {
    var onTick: (() -> Void)?
    private var timer: Timer?

    func start(interval: TimeInterval) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onTick?()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}
