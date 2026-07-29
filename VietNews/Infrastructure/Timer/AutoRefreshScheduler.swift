import Foundation

protocol RefreshScheduling: AnyObject {
    var onTick: (() -> Void)? { get set }
    func start(interval: TimeInterval)
    func stop()
}

final class AutoRefreshScheduler: RefreshScheduling {
    var onTick: (() -> Void)?
    private var timer: Timer?

    /// Added to the common run loop modes rather than the default one. A scheduled timer in the
    /// default mode is suspended for the whole duration of a scroll, so a reader who kept
    /// scrolling simply never got a refresh, and the app looked like it had stopped updating.
    func start(interval: TimeInterval) {
        stop()
        guard interval > 0 else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.onTick?()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        stop()
    }
}
