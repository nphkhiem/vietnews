import Foundation
import Network

/// Network reachability status, decoupled from `NWPath` so it can be constructed in tests
/// (`NWPath` itself has no public initializer).
enum NetworkPathStatus {
    case satisfied
    case unsatisfied
    case requiresConnection

    init(_ status: NWPath.Status) {
        switch status {
        case .satisfied: self = .satisfied
        case .unsatisfied: self = .unsatisfied
        case .requiresConnection: self = .requiresConnection
        @unknown default: self = .unsatisfied
        }
    }
}

/// The slice of `NWPathMonitor`'s API that `NetworkMonitor` needs, extracted so a fake
/// implementation can drive path updates deterministically in tests.
protocol NetworkPathMonitoring: AnyObject {
    var pathUpdateHandler: ((NetworkPathStatus) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

/// Production adapter wrapping the real `NWPathMonitor`.
final class NWPathMonitorAdapter: NetworkPathMonitoring {
    private let monitor = NWPathMonitor()

    var pathUpdateHandler: ((NetworkPathStatus) -> Void)? {
        didSet {
            monitor.pathUpdateHandler = { [weak self] path in
                self?.pathUpdateHandler?(NetworkPathStatus(path.status))
            }
        }
    }

    func start(queue: DispatchQueue) {
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}

final class NetworkMonitor: ObservableObject {
    @Published private(set) var isOnline = true

    private let monitor: NetworkPathMonitoring
    private let queue = DispatchQueue(label: "com.khiemnph.vietnews.networkmonitor")

    init(monitor: NetworkPathMonitoring = NWPathMonitorAdapter()) {
        self.monitor = monitor
        self.monitor.pathUpdateHandler = { [weak self] status in
            DispatchQueue.main.async {
                self?.isOnline = status == .satisfied
            }
        }
        self.monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
