import Foundation

protocol NetworkService {
    func data(from url: URL) async throws -> Data
}

final class URLSessionNetworkService: NetworkService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw NewsError.invalidResponse(statusCode: -1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw NewsError.invalidResponse(statusCode: http.statusCode)
        }
        return data
    }
}
