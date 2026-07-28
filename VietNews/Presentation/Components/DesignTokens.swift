import SwiftUI

/// The visual system, named once so every surface draws from the same set.
///
/// Colours live in the asset catalog with a light and a dark value, which is why no view needs
/// appearance-specific code. The contrast of every text pair is recomputed from those assets by
/// `DesignTokenContrastTests` rather than trusted to have been checked once.
enum Tokens {
    enum Palette {
        static let background = Color("Colors/bg")
        static let surface = Color("Colors/surface")
        static let hairline = Color("Colors/hairline")

        /// Primary reading colour.
        static let ink = Color("Colors/ink")
        /// Supporting text such as an article summary.
        static let inkSecondary = Color("Colors/inkSecondary")
        /// Metadata such as a timestamp.
        static let inkTertiary = Color("Colors/inkTertiary")
        /// A headline the reader has already opened. Still meets the body contrast requirement,
        /// because receding must not mean becoming hard to read.
        static let inkRead = Color("Colors/inkRead")

        /// Reserved for signal: the selected category, a source that is failing, and primary
        /// actions. Never decorative, because an accent spent everywhere signals nothing.
        static let accent = Color("Colors/accent")
        static let onAccent = Color("Colors/onAccent")

        static func source(_ source: NewsSource) -> Color {
            switch source {
            case .vnexpress: return Color("Colors/sourceVNExpress")
            case .nyt: return Color("Colors/sourceNYT")
            case .bbc: return Color("Colors/sourceBBC")
            case .substack: return Color("Colors/sourceSubstack")
            case .eurogamer: return Color("Colors/sourceEurogamer")
            }
        }
    }

    /// A four point rhythm. Every margin and gap in the app comes from here.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    /// Five steps, no more. Sizes are relative so they scale with the reader's text size.
    enum Typography {
        static let headline = Font.system(size: 17.5, weight: .semibold)
        static let lead = Font.system(size: 21, weight: .semibold)
        static let summary = Font.system(size: 13.5)
        static let category = Font.system(size: 15)
        /// Source marks and timestamps. Tracked and uppercased at the call site.
        static let meta = Font.system(size: 11, weight: .semibold)
    }

    enum Radius {
        /// Editorial means tight rather than pill shaped.
        static let image: CGFloat = 3
        static let full: CGFloat = 999
    }

    enum Layout {
        /// Nominal thumbnail edge at the default text size, chosen to match the height of a
        /// source line plus a two line headline. Any taller and the image, not the text, sets
        /// the height of the top band, which opens a gap above the summary. It scales with
        /// Dynamic Type so the image keeps its relationship to the headline beside it.
        static let thumbnailSide: CGFloat = 64
        /// Vietnamese stacks diacritics above and below, which a tighter leading clips.
        static let headlineLineSpacing: CGFloat = 2
    }
}
