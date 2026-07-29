import XCTest
@testable import VietNews

final class FakeNetworkPathMonitor: NetworkPathMonitoring {
    var pathUpdateHandler: ((NetworkPathStatus) -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    func start(queue: DispatchQueue) {
        startCallCount += 1
    }

    func cancel() {
        cancelCallCount += 1
    }

    func simulate(_ status: NetworkPathStatus) {
        pathUpdateHandler?(status)
    }
}

final class NetworkMonitorTests: XCTestCase {
    func test_givenDefaultState_whenMonitorStarts_thenIsOnlineIsTrue() {
        // given
        let fakeMonitor = FakeNetworkPathMonitor()

        // when
        let sut = NetworkMonitor(monitor: fakeMonitor)

        // then
        XCTAssertTrue(sut.isOnline)
        XCTAssertEqual(fakeMonitor.startCallCount, 1)
    }

    func test_givenPathBecomesUnsatisfied_whenPathUpdateReceived_thenIsOnlineBecomesFalse() {
        // given
        let fakeMonitor = FakeNetworkPathMonitor()
        let sut = NetworkMonitor(monitor: fakeMonitor)
        fakeMonitor.simulate(.unsatisfied)

        // when
        waitForMainQueue()

        // then
        XCTAssertFalse(sut.isOnline)
    }

    func test_givenOfflinePath_whenPathBecomesSatisfiedAgain_thenIsOnlineBecomesTrue() {
        // given
        let fakeMonitor = FakeNetworkPathMonitor()
        let sut = NetworkMonitor(monitor: fakeMonitor)
        fakeMonitor.simulate(.unsatisfied)

        // when
        waitForMainQueue()

        // then
        XCTAssertFalse(sut.isOnline)
        fakeMonitor.simulate(.satisfied)
        waitForMainQueue()
        XCTAssertTrue(sut.isOnline)
    }

    /// `isOnline` is updated via `DispatchQueue.main.async` (mirroring how the real
    /// `NWPathMonitor` callback, which fires on a background queue, hops back to main).
    /// Flush the main queue so that hop has a chance to complete before asserting.
    private func waitForMainQueue() {
        let expectation = expectation(description: "main queue flushed")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }
}
