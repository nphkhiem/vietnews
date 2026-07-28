import UIKit
import XCTest
@testable import VietNews

private actor CountingNetworkService: NetworkService {
    private let payload: Result<Data, Error>
    private(set) var callCount = 0
    private var gate: CheckedContinuation<Void, Never>?
    private(set) var didEnter = false
    private let isGated: Bool

    init(payload: Result<Data, Error>, gated: Bool = false) {
        self.payload = payload
        self.isGated = gated
    }

    func release() {
        gate?.resume()
        gate = nil
    }

    func data(from url: URL) async throws -> Data {
        callCount += 1
        if isGated {
            didEnter = true
            await withCheckedContinuation { gate = $0 }
        }
        return try payload.get()
    }
}

final class ThumbnailLoaderTests: XCTestCase {
    /// A deliberately large source image, so the downsampling claim is measured rather than
    /// assumed. At 1000 points square this decodes to roughly 4 MB untouched.
    private func largeImageData(side: CGFloat = 1_000) throws -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
        return try XCTUnwrap(image.pngData())
    }

    private let url = URL(string: "https://example.com/photo.png")!

    func test_givenLargeSourceImage_whenLoading_thenDecodesNoLargerThanRequested() async throws {
        let network = CountingNetworkService(payload: .success(try largeImageData()))
        let sut = ThumbnailLoader(network: network)

        let image = try await sut.thumbnail(for: url, maxPixelSize: 160)

        let longestEdge = max(image.size.width * image.scale, image.size.height * image.scale)
        XCTAssertLessThanOrEqual(longestEdge, 160, "the decode must be bounded by what is displayed")
        XCTAssertGreaterThan(longestEdge, 0)
    }

    func test_givenSameURLRequestedTwice_whenSecondRequestArrivesAfterTheFirst_thenServesFromCache() async throws {
        let network = CountingNetworkService(payload: .success(try largeImageData()))
        let sut = ThumbnailLoader(network: network)

        _ = try await sut.thumbnail(for: url, maxPixelSize: 160)
        _ = try await sut.thumbnail(for: url, maxPixelSize: 160)

        let calls = await network.callCount
        XCTAssertEqual(calls, 1)
    }

    /// Several rows can show the same image, and a row can be rebuilt mid-flight. Without
    /// coalescing that is one download and one decode per row.
    func test_givenConcurrentRequestsForOneURL_whenBothInFlight_thenOnlyOneDownloadHappens() async throws {
        let network = CountingNetworkService(payload: .success(try largeImageData()), gated: true)
        let sut = ThumbnailLoader(network: network)

        async let first = sut.thumbnail(for: url, maxPixelSize: 160)
        while await !network.didEnter {
            await Task.yield()
        }
        async let second = sut.thumbnail(for: url, maxPixelSize: 160)
        for _ in 0..<10 {
            await Task.yield()
        }
        await network.release()
        _ = try await (first, second)

        let calls = await network.callCount
        XCTAssertEqual(calls, 1)
    }

    func test_givenDifferentSizesForOneURL_whenLoading_thenEachSizeIsItsOwnEntry() async throws {
        let network = CountingNetworkService(payload: .success(try largeImageData()))
        let sut = ThumbnailLoader(network: network)

        _ = try await sut.thumbnail(for: url, maxPixelSize: 160)
        _ = try await sut.thumbnail(for: url, maxPixelSize: 320)

        let calls = await network.callCount
        XCTAssertEqual(calls, 2, "a larger request cannot be served by a smaller decode")
    }

    func test_givenResponseThatIsNotAnImage_whenLoading_thenReportsItRatherThanReturningNothing() async throws {
        let network = CountingNetworkService(payload: .success(Data("<html>blocked</html>".utf8)))
        let sut = ThumbnailLoader(network: network)

        do {
            _ = try await sut.thumbnail(for: url, maxPixelSize: 160)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? ThumbnailError, .notAnImage)
        }
    }

    func test_givenNetworkFailure_whenLoading_thenPropagatesTheError() async throws {
        let network = CountingNetworkService(payload: .failure(NewsError.invalidResponse(statusCode: 404)))
        let sut = ThumbnailLoader(network: network)

        do {
            _ = try await sut.thumbnail(for: url, maxPixelSize: 160)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .invalidResponse(statusCode: 404))
        }
    }

    /// A failed load must not poison the entry, otherwise the retry the interface offers could
    /// never succeed.
    func test_givenFailedLoad_whenRetrying_thenTheRequestIsMadeAgain() async throws {
        let network = CountingNetworkService(payload: .success(Data("not an image".utf8)))
        let sut = ThumbnailLoader(network: network)

        _ = try? await sut.thumbnail(for: url, maxPixelSize: 160)
        _ = try? await sut.thumbnail(for: url, maxPixelSize: 160)

        let calls = await network.callCount
        XCTAssertEqual(calls, 2)
    }
}
