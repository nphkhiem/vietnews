import XCTest
import Factory
@testable import VietNews

final class ContainerRegistrationTests: XCTestCase {
    override func tearDown() {
        Container.shared.manager.reset()
        super.tearDown()
    }

    func test_givenContainer_whenResolvingNetworkServiceTwice_thenReturnsSameSingletonInstance() {
        // given
        let first = Container.shared.networkService() as AnyObject

        // when
        let second = Container.shared.networkService() as AnyObject

        // then
        XCTAssertTrue(first === second)
    }

    func test_givenContainer_whenResolvingNewsSourceAdapters_thenEverySourceIsRegisteredOnce() {
        // given
        let container = Container.shared

        // when
        let adapters = container.newsSourceAdapters()

        // then
        XCTAssertEqual(adapters.count, NewsSource.allCases.count)
        XCTAssertEqual(Set(adapters.map(\.source)), Set(NewsSource.allCases))
    }

    func test_givenOverriddenNetworkService_whenResolving_thenReturnsRegisteredStub() {
        // given
        final class StubNetworkService: NetworkService {
            func data(from url: URL) async throws -> Data { Data() }
        }
        Container.shared.networkService.register { StubNetworkService() }

        // when
        let resolved = Container.shared.networkService()

        // then
        XCTAssertTrue(resolved is StubNetworkService)
    }

    @MainActor
    func test_givenContainer_whenResolvingNewsFeedViewModelTwice_thenReturnsSameSingletonInstance() {
        // given
        let first = Container.shared.newsFeedViewModel()

        // when
        let second = Container.shared.newsFeedViewModel()

        // then
        XCTAssertTrue(first === second)
    }
}
