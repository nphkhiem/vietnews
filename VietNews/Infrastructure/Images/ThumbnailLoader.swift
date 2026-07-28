import Foundation
import ImageIO
import UIKit

enum ThumbnailError: Error, Equatable {
    /// The response arrived but held nothing decodable, which is what a hotlink block or an
    /// error page served with an image content type looks like.
    case notAnImage
}

protocol ThumbnailLoading: Sendable {
    /// Returns an image decoded at no more than `maxPixelSize` on its longest edge.
    func thumbnail(for url: URL, maxPixelSize: Int) async throws -> UIImage
}

/// Loads article thumbnails without ever holding a full resolution decode in memory.
///
/// A feed row shows an 80 point image. Decoding a 2000 pixel wide press photograph to show it
/// costs roughly 16 MB of backing store per image, so a scrolled category could hold hundreds of
/// megabytes. `CGImageSourceCreateThumbnailAtIndex` decodes straight to the size we asked for, so
/// the cost is bounded by what is displayed rather than by what the publisher uploaded.
actor ThumbnailLoader: ThumbnailLoading {
    private let network: NetworkService
    private let cache: NSCache<NSString, UIImage>
    private var inFlight: [String: Task<UIImage, Error>] = [:]

    init(network: NetworkService, memoryLimitInBytes: Int = 24 * 1024 * 1024) {
        self.network = network
        cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = memoryLimitInBytes
    }

    func thumbnail(for url: URL, maxPixelSize: Int) async throws -> UIImage {
        let key = Self.key(url: url, maxPixelSize: maxPixelSize)

        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        // Several rows can show the same image, and a row can be rebuilt while its first request
        // is still running. Joining the existing task keeps that to one download and one decode.
        if let existing = inFlight[key] {
            return try await existing.value
        }

        let task = Task<UIImage, Error> { [network] in
            // Ask a width-templated CDN for something close to what is being shown, rather than
            // stretching the small rendition the feed advertised. Falls back to the original if
            // the larger one cannot be fetched, since a soft image beats an empty frame.
            let requested = ImageVariant.url(url, targetingWidth: maxPixelSize)
            let data: Data
            do {
                data = try await network.data(from: requested)
            } catch {
                guard requested != url else { throw error }
                data = try await network.data(from: url)
            }
            guard let image = Self.downsample(data: data, maxPixelSize: maxPixelSize) else {
                throw ThumbnailError.notAnImage
            }
            return image
        }
        inFlight[key] = task

        defer { inFlight[key] = nil }
        let image = try await task.value
        cache.setObject(image, forKey: key as NSString, cost: Self.cost(of: image))
        return image
    }

    private static func key(url: URL, maxPixelSize: Int) -> String {
        "\(url.absoluteString)|\(maxPixelSize)"
    }

    /// Approximate backing store size, which is what the cache limit is meant to bound. The
    /// byte count of the original file is not a useful proxy, because a small JPEG can decode
    /// into a very large bitmap.
    private static func cost(of image: UIImage) -> Int {
        let pixels = Int(image.size.width * image.scale * image.size.height * image.scale)
        return pixels * 4
    }

    private static func downsample(data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as [CFString: Any] as CFDictionary

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }
}
