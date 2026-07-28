import Foundation

extension String {
    /// Removes markup, then resolves character references exactly once.
    ///
    /// Order matters and so does the single pass. Tags go first so that escaped text a publisher
    /// deliberately wrote, such as `5 &lt; 10`, survives instead of being mistaken for a tag.
    /// Resolving only once means a double encoded payload decodes to visible text rather than
    /// cascading back into markup that was already stripped.
    func strippingHTML() -> String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .decodingHTMLEntities()
            .replacingOccurrences(of: "[ \t\u{00A0}]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves both named and numeric character references. The previous handful of literal
    /// replacements left everything else as raw text, so feeds using numeric references showed
    /// sequences like `&#8217;` in the middle of a headline.
    func decodingHTMLEntities() -> String {
        guard contains("&") else { return self }

        var result = ""
        result.reserveCapacity(count)
        var cursor = startIndex

        while let ampersand = self[cursor...].firstIndex(of: "&") {
            result.append(contentsOf: self[cursor..<ampersand])

            let afterAmpersand = index(after: ampersand)
            guard
                let semicolon = self[afterAmpersand...].firstIndex(of: ";"),
                distance(from: afterAmpersand, to: semicolon) <= 12,
                let decoded = Self.character(forEntity: String(self[afterAmpersand..<semicolon]))
            else {
                result.append("&")
                cursor = afterAmpersand
                continue
            }

            result.append(decoded)
            cursor = index(after: semicolon)
        }

        result.append(contentsOf: self[cursor...])
        return result
    }

    private static func character(forEntity entity: String) -> String? {
        if entity.hasPrefix("#") {
            let digits = entity.dropFirst()
            let scalarValue: UInt32?
            if digits.hasPrefix("x") || digits.hasPrefix("X") {
                scalarValue = UInt32(digits.dropFirst(), radix: 16)
            } else {
                scalarValue = UInt32(digits, radix: 10)
            }
            guard let scalarValue, let scalar = Unicode.Scalar(scalarValue) else { return nil }
            return String(Character(scalar))
        }
        return namedEntities[entity]
    }

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "ndash": "\u{2013}", "mdash": "\u{2014}",
        "hellip": "\u{2026}", "lsquo": "\u{2018}", "rsquo": "\u{2019}",
        "ldquo": "\u{201C}", "rdquo": "\u{201D}", "bull": "\u{2022}",
        "middot": "\u{00B7}", "laquo": "\u{00AB}", "raquo": "\u{00BB}",
        "copy": "\u{00A9}", "reg": "\u{00AE}", "trade": "\u{2122}",
        "deg": "\u{00B0}", "euro": "\u{20AC}", "pound": "\u{00A3}",
        "eacute": "\u{00E9}", "egrave": "\u{00E8}", "agrave": "\u{00E0}",
        "ccedil": "\u{00E7}", "uuml": "\u{00FC}", "ouml": "\u{00F6}", "auml": "\u{00E4}"
    ]

    func firstImageURL() -> URL? {
        // Both quote styles appear in the wild, and a feed using single quotes previously lost
        // its image silently.
        for pattern in [#"<img[^>]*src="([^"]+)""#, #"<img[^>]*src='([^']+)'"#] {
            guard let range = range(of: pattern, options: .regularExpression) else { continue }
            let tag = String(self[range])
            guard let sourceRange = tag.range(
                of: #"src=["']([^"']+)["']"#,
                options: .regularExpression
            ) else { continue }

            let source = String(tag[sourceRange])
                .replacingOccurrences(of: "src=", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                .decodingHTMLEntities()
            if let url = URL(string: source) {
                return url
            }
        }
        return nil
    }
}
