import Foundation

extension String {
    func strippingHTML() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func firstImageURL() -> URL? {
        guard let range = range(
            of: #"<img[^>]*src="([^"]+)""#,
            options: .regularExpression
        ) else { return nil }
        let match = String(self[range])
        guard let srcRange = match.range(of: #"src="([^"]+)""#, options: .regularExpression) else {
            return nil
        }
        let src = String(match[srcRange])
            .replacingOccurrences(of: "src=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
        return URL(string: src)
    }
}
