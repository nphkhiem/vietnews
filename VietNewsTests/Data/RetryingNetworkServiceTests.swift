import XCTest
@testable import VietNews

/// Returns a scripted sequence of outcomes, so a test can describe "fails once, then succeeds"
/// without any real waiting.
private actor ScriptedNetworkService: NetworkService {
    private var outcomes: [Result<Data, Error>]
    private(set) var callCount = 0
    private(set) var requestedURLs: [URL] = []

    init(_ outcomes: [Result<Data, Error>]) {
        self.outcomes = outcomes
    }

    func data(from url: URL) async throws -> Data {
        callCount += 1
        requestedURLs.append(url)
        guard !outcomes.isEmpty else { return Data() }
        return try outcomes.removeFirst().get()
    }
}

private actor SleepRecorder {
    private(set) var durations: [TimeInterval] = []

    func record(_ duration: TimeInterval) {
        durations.append(duration)
    }
}

final class RetryingNetworkServiceTests: XCTestCase {
    private let url = URL(string: "https://example.com/feed")!

    private func makeSUT(
        _ outcomes: [Result<Data, Error>],
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5
    ) -> (RetryingNetworkService, ScriptedNetworkService, SleepRecorder) {
        let wrapped = ScriptedNetworkService(outcomes)
        let recorder = SleepRecorder()
        let sut = RetryingNetworkService(
            wrapping: wrapped,
            maxAttempts: maxAttempts,
            baseDelay: baseDelay,
            // No pacing delay in these tests: pacing is covered separately.
            pacer: HostRequestPacer(minimumInterval: 0, sleep: { _ in }),
            sleep: { await recorder.record($0) }
        )
        return (sut, wrapped, recorder)
    }

    func test_givenRateLimitThenSuccess_whenRequesting_thenRetriesAndReturnsTheData() async throws {
        // given
        let payload = Data("ok".utf8)
        let (sut, wrapped, _) = makeSUT([
            .failure(NewsError.rateLimited(retryAfter: nil)),
            .success(payload)
        ])
        let data = try await sut.data(from: url)

        // when
        let calls = await wrapped.callCount

        // then
        XCTAssertEqual(data, payload)
        XCTAssertEqual(calls, 2)
    }

    func test_givenRateLimitStatingRetryAfter_whenRetrying_thenHonoursTheServersFigure() async throws {
        // given
        let (sut, _, recorder) = makeSUT([
            .failure(NewsError.rateLimited(retryAfter: 7)),
            .success(Data())
        ])
        _ = try await sut.data(from: url)

        // when
        let durations = await recorder.durations

        // then
        XCTAssertEqual(durations, [7], "the server's own figure must win over our backoff")
    }

    func test_givenRateLimitWithoutRetryAfter_whenRetrying_thenBacksOffExponentially() async throws {
        // given
        let (sut, _, recorder) = makeSUT([
            .failure(NewsError.rateLimited(retryAfter: nil)),
            .failure(NewsError.rateLimited(retryAfter: nil)),
            .success(Data())
        ], baseDelay: 0.5)
        _ = try await sut.data(from: url)

        // when
        let durations = await recorder.durations

        // then
        XCTAssertEqual(durations, [0.5, 1.0])
    }

    func test_givenServerError_whenRequesting_thenRetries() async throws {
        // given
        let (sut, wrapped, _) = makeSUT([
            .failure(NewsError.invalidResponse(statusCode: 503)),
            .success(Data())
        ])
        _ = try await sut.data(from: url)

        // when
        let calls = await wrapped.callCount

        // then
        XCTAssertEqual(calls, 2)
    }

    /// A refusal will refuse again a moment later. Retrying it wastes the reader's time and their
    /// battery, and makes a rate limit harder to recover from.
    func test_givenRefusal_whenRequesting_thenDoesNotRetry() async {
        // given
        let (sut, wrapped, _) = makeSUT([
            .failure(NewsError.invalidResponse(statusCode: 403)),
            .success(Data())
        ])
        do {
            _ = try await sut.data(from: url)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .invalidResponse(statusCode: 403))
        }

        // when
        let calls = await wrapped.callCount

        // then
        XCTAssertEqual(calls, 1)
    }

    func test_givenPersistentRateLimit_whenAttemptsAreExhausted_thenThrowsTheLastError() async {
        // given
        let (sut, wrapped, _) = makeSUT([
            .failure(NewsError.rateLimited(retryAfter: 1)),
            .failure(NewsError.rateLimited(retryAfter: 1)),
            .failure(NewsError.rateLimited(retryAfter: 1))
        ], maxAttempts: 3)
        do {
            _ = try await sut.data(from: url)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .rateLimited(retryAfter: 1))
        }

        // when
        let calls = await wrapped.callCount

        // then
        XCTAssertEqual(calls, 3, "must stop at the attempt limit")
    }

    func test_givenSuccessFirstTime_whenRequesting_thenDoesNotSleepAtAll() async throws {
        // given
        let (sut, wrapped, recorder) = makeSUT([.success(Data("ok".utf8))])
        _ = try await sut.data(from: url)
        let calls = await wrapped.callCount

        // when
        let durations = await recorder.durations

        // then
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(durations.isEmpty)
    }
}

final class HostRequestPacerTests: XCTestCase {
    func test_givenTwoRequestsToTheSameHost_whenPacing_thenTheSecondWaits() async {
        // given
        let recorder = SleepRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_000)
        let sut = HostRequestPacer(
            minimumInterval: 2,
            now: { fixedNow },
            sleep: { await recorder.record($0) }
        )
        await sut.waitForTurn(host: "api.nytimes.com")
        await sut.waitForTurn(host: "api.nytimes.com")

        // when
        let durations = await recorder.durations

        // then
        XCTAssertEqual(durations, [2], "the first request goes straight through")
    }

    func test_givenRequestsToDifferentHosts_whenPacing_thenNeitherWaits() async {
        // given
        let recorder = SleepRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_000)
        let sut = HostRequestPacer(
            minimumInterval: 2,
            now: { fixedNow },
            sleep: { await recorder.record($0) }
        )
        await sut.waitForTurn(host: "api.nytimes.com")
        await sut.waitForTurn(host: "feeds.bbci.co.uk")

        // when
        let durations = await recorder.durations

        // then
        XCTAssertTrue(durations.isEmpty, "pacing is per host, not global")
    }

    func test_givenThreeRequestsToOneHost_whenPacing_thenEachWaitsLongerThanTheLast() async {
        // given
        let recorder = SleepRecorder()
        let fixedNow = Date(timeIntervalSince1970: 1_000)
        let sut = HostRequestPacer(
            minimumInterval: 1,
            now: { fixedNow },
            sleep: { await recorder.record($0) }
        )
        await sut.waitForTurn(host: "api.nytimes.com")
        await sut.waitForTurn(host: "api.nytimes.com")
        await sut.waitForTurn(host: "api.nytimes.com")

        // when
        let durations = await recorder.durations

        // then
        XCTAssertEqual(durations, [1, 2], "slots accumulate rather than collapsing")
    }
}

final class RetryAfterParsingTests: XCTestCase {
    private func response(retryAfter: String?) throws -> HTTPURLResponse {
        var headers: [String: String] = [:]
        if let retryAfter {
            headers["Retry-After"] = retryAfter
        }
        return try XCTUnwrap(
            HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: headers
            )
        )
    }

    func test_givenSecondsHeader_whenParsing_thenReturnsThoseSeconds() throws {
        // given
        let response = try response(retryAfter: "30")

        // when
        let retryAfter = URLSessionNetworkService.retryAfter(from: response)

        // then
        XCTAssertEqual(retryAfter, 30)
    }

    func test_givenNoHeader_whenParsing_thenReturnsNil() throws {
        // given
        let response = try response(retryAfter: nil)

        // when
        let retryAfter = URLSessionNetworkService.retryAfter(from: response)

        // then
        XCTAssertNil(retryAfter)
    }

    func test_givenGarbageHeader_whenParsing_thenReturnsNil() throws {
        // given
        let response = try response(retryAfter: "soon")

        // when
        let retryAfter = URLSessionNetworkService.retryAfter(from: response)

        // then
        XCTAssertNil(retryAfter)
    }

    func test_givenHTTPDateHeader_whenParsing_thenReturnsSecondsUntilThatDate() throws {
        // given
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        let future = formatter.string(from: Date().addingTimeInterval(120))

        // when
        let parsed = try XCTUnwrap(URLSessionNetworkService.retryAfter(from: try response(retryAfter: future)))

        // then
        XCTAssertEqual(parsed, 120, accuracy: 5)
    }

    /// A date already in the past must not produce a negative delay.
    func test_givenPastDateHeader_whenParsing_thenClampsToZero() throws {
        // given
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"

        // when
        let past = formatter.string(from: Date().addingTimeInterval(-500))

        // then
        XCTAssertEqual(URLSessionNetworkService.retryAfter(from: try response(retryAfter: past)), 0)
    }
}
