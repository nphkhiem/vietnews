import Foundation

/// Rewrites image URLs that encode their size, so a full width lead can ask for a full width
/// image instead of upscaling a thumbnail.
///
/// Feeds advertise small images. BBC publishes 240 pixel wide thumbnails, which is right for a
/// 64 point row and visibly soft stretched across a phone. Several sources serve from a CDN
/// whose path encodes the width, so a larger rendition costs a string change rather than a
/// second request.
///
/// Anything unrecognised is returned untouched. Guessing at a URL's structure risks turning a
/// working image into a 404, and a slightly soft image beats no image.
enum ImageVariant {
    /// Known width-templated CDN paths. The width is capture group one.
    ///
    /// Capture groups rather than lookbehind on purpose: ICU requires a lookbehind to have a
    /// bounded length, so a pattern like `(?<=/ace/[a-z]+/)` fails to compile and is then
    /// silently dropped, disabling the rewrite without any error.
    private static let templates: [NSRegularExpression] = [
        // BBC: https://ichef.bbci.co.uk/ace/standard/240/cpsprodpb/...
        #"/ace/[a-z]+/(\d{2,4})/"#,
        // VNExpress resize service: .../resize_640x360/...
        #"/resize_(\d{2,4})x\d{2,4}/"#
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    /// Widths a CDN is likely to have already rendered. Asking for an arbitrary number tends to
    /// miss the cache or be rejected outright.
    private static let ladder = [240, 320, 480, 640, 800, 976, 1024, 1536]

    static func url(_ url: URL, targetingWidth width: Int) -> URL {
        let absolute = url.absoluteString
        let range = NSRange(absolute.startIndex..., in: absolute)

        for template in templates {
            guard let match = template.firstMatch(in: absolute, range: range),
                  match.numberOfRanges > 1,
                  let matchRange = Range(match.range(at: 1), in: absolute),
                  let current = Int(absolute[matchRange])
            else { continue }

            let wanted = nearestWidth(atLeast: width)
            // Never ask for something smaller than the feed already offered. The advertised
            // rendition is known to exist; a narrower one may not.
            guard wanted > current else { return url }

            var rewritten = absolute
            rewritten.replaceSubrange(matchRange, with: String(wanted))
            return URL(string: rewritten) ?? url
        }

        return url
    }

    private static func nearestWidth(atLeast width: Int) -> Int {
        ladder.first { $0 >= width } ?? ladder.last ?? width
    }
}
