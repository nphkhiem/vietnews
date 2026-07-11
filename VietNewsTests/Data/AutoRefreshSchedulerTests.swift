import XCTest
@testable import VietNews

final class AutoRefreshSchedulerTests: XCTestCase {
    func test_givenStartedScheduler_whenIntervalElapsesRepeatedly_thenTicksMultipleTimes() {
        let sut = AutoRefreshScheduler()
        let exp = expectation(description: "two ticks")
        exp.expectedFulfillmentCount = 2
        sut.onTick = { exp.fulfill() }

        sut.start(interval: 0.05)

        wait(for: [exp], timeout: 1.0)
        sut.stop()
    }

    func test_givenStoppedScheduler_whenIntervalElapses_thenNoFurtherTicks() {
        let sut = AutoRefreshScheduler()
        var ticks = 0
        sut.onTick = { ticks += 1 }

        sut.start(interval: 0.05)
        sut.stop()
        let settled = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
        wait(for: [settled], timeout: 1.0)

        XCTAssertEqual(ticks, 0)
    }
}
