import XCTest
import Factory
@testable import VietNews

final class ContainerRegistrationTests: XCTestCase {
    override func tearDown() {
        Container.shared.manager.reset()
        super.tearDown()
    }

    func test_givenContainer_whenResolvingNetworkServiceTwice_thenReturnsSameSingletonInstance() {
        let first = Container.shared.networkService() as AnyObject
        let second = Container.shared.networkService() as AnyObject

        XCTAssertTrue(first === second)
    }

    func test_givenContainer_whenResolvingNewsSourceAdapters_thenAllFiveAreRegistered() {
        let adapters = Container.shared.newsSourceAdapters()

        XCTAssertEqual(adapters.count, 6)
    }

    func test_givenOverriddenNetworkService_whenResolving_thenReturnsRegisteredStub() {
        final class StubNetworkService: NetworkService {
            func data(from url: URL) async throws -> Data { Data() }
        }
        Container.shared.networkService.register { StubNetworkService() }

        let resolved = Container.shared.networkService()

        XCTAssertTrue(resolved is StubNetworkService)
    }

    @MainActor
    func test_givenContainer_whenResolvingNewsFeedViewModelTwice_thenReturnsSameSingletonInstance() {
        let first = Container.shared.newsFeedViewModel()
        let second = Container.shared.newsFeedViewModel()

        XCTAssertTrue(first === second)
    }
}
