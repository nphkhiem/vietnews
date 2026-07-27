import XCTest
@testable import VietNews

/// Contract check against the live feeds every source is configured to use.
///
/// Excluded from normal runs, because a network hiccup must never redden CI. Run it on demand.
/// Note the `TEST_RUNNER_` prefix: xcodebuild does not pass the shell's environment to the test
/// process, and without the prefix this check silently skips and the run reports success.
///
///     TEST_RUNNER_RUN_SOURCE_HEALTH=1 TEST_RUNNER_NYT_API_KEY=your_key \
///       xcodebuild -project VietNews.xcodeproj -scheme VietNews \
///       -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///       -only-testing:VietNewsTests/SourceHealthChecks test
///
/// Reachability and parsing are reported separately, so an endpoint that answers with a 200 and
/// unparseable markup is distinguishable from one that is simply gone.
final class SourceHealthChecks: XCTestCase {
    private enum Outcome {
        case ok(Int)
        case unreachable(String)
        case unparseable(String)
        case notConfigured

        var isOK: Bool {
            if case .ok = self { return true }
            return false
        }

        var describedOutcome: String {
            switch self {
            case .ok(let count): return "ok, \(count) articles"
            case .unreachable(let why): return "UNREACHABLE, \(why)"
            case .unparseable(let why): return "UNPARSEABLE, \(why)"
            case .notConfigured: return "not configured, skipped"
            }
        }
    }

    private var network: NetworkService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["RUN_SOURCE_HEALTH"] == "1",
            "Set RUN_SOURCE_HEALTH=1 to run the live source health check."
        )
        network = URLSessionNetworkService()
    }

    func test_givenEveryConfiguredSource_whenCheckingHealth_thenEachOneReturnsArticles() async throws {
        var report: [String] = []
        var failedSources: [NewsSource] = []

        for adapter in adapters() {
            var outcomes: [(NewsCategory, Language, Outcome)] = []

            for language in Language.allCases {
                for category in NewsCategory.allCases where adapter.supports(category: category, language: language) {
                    let outcome = await check(adapter, category, language)
                    outcomes.append((category, language, outcome))
                }
            }

            if outcomes.isEmpty {
                report.append("\(adapter.source.rawValue): no endpoints configured")
                continue
            }

            for (category, language, outcome) in outcomes {
                report.append(
                    "\(adapter.source.rawValue) \(category.rawValue)/\(language.rawValue): \(outcome.describedOutcome)"
                )
            }

            let configured = outcomes.filter { if case .notConfigured = $0.2 { return false } else { return true } }
            if !configured.isEmpty, !configured.contains(where: { $0.2.isOK }) {
                failedSources.append(adapter.source)
            }
        }

        print("Source health report\n" + report.joined(separator: "\n"))

        XCTAssertTrue(
            failedSources.isEmpty,
            "These sources returned nothing for every category they claim to support: "
                + failedSources.map(\.rawValue).joined(separator: ", ")
                + "\n" + report.joined(separator: "\n")
        )
    }

    // MARK: - Helpers

    private func adapters() -> [NewsSourceAdapter] {
        let parser = FeedKitRSSParser()
        return [
            VNExpressSource.make(network: network, parser: FeedKitRSSParser(parsingSource: .vnexpress)),
            BBCSource.make(network: network, parser: FeedKitRSSParser(parsingSource: .bbc)),
            EurogamerSource.make(network: network, parser: FeedKitRSSParser(parsingSource: .eurogamer)),
            NYTSource(network: network, apiKey: nytAPIKey()),
            SubstackSource(
                network: network,
                parser: parser,
                feeds: { UserPreferences(defaults: .standard).substackFeeds }
            )
        ]
    }

    /// Read from the environment rather than the bundle: a unit test bundle does not carry the
    /// app's Info.plist. With no key, NYT reports as not configured instead of failing.
    private func nytAPIKey() -> String {
        ProcessInfo.processInfo.environment["NYT_API_KEY"] ?? ""
    }

    private func check(_ adapter: NewsSourceAdapter, _ category: NewsCategory, _ language: Language) async -> Outcome {
        let urls = adapter.endpoints(category: category, language: language)
        guard !urls.isEmpty else { return .notConfigured }

        for url in urls {
            do {
                _ = try await network.data(from: url)
            } catch {
                return .unreachable("\(redacted(url)) \(describe(error))")
            }
        }

        do {
            let articles = try await adapter.fetch(category: category, language: language)
            guard !articles.isEmpty else {
                return .unparseable("\(redacted(urls[0])) reachable but produced no articles")
            }
            return .ok(articles.count)
        } catch {
            return .unparseable("\(redacted(urls[0])) \(describe(error))")
        }
    }

    /// Endpoints can carry credentials, so never put a raw URL in test output.
    private func redacted(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = url.query == nil ? nil : "redacted"
        return components?.url?.absoluteString ?? url.host ?? "unknown host"
    }

    private func describe(_ error: Error) -> String {
        if let newsError = error as? NewsError {
            switch newsError {
            case .invalidResponse(let statusCode): return "HTTP \(statusCode)"
            case .parsingFailed(let source): return "parsing failed for \(source.rawValue)"
            case .sourceTimeout(let source): return "timed out for \(source.rawValue)"
            case .networkUnavailable: return "network unavailable"
            case .allSourcesFailed(let sources, let cause):
                return "all sources failed (\(cause)): " + sources.map(\.rawValue).joined(separator: ", ")
            case .cacheFailed: return "cache failed"
            }
        }
        return (error as NSError).localizedDescription
    }
}
