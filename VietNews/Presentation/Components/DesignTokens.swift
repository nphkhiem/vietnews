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
        /// Something the reader should know but need not act on, such as being offline. Distinct
        /// from the accent, which marks a problem or an action.
        static let caution = Color("Colors/caution")
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
        /// The separation between one group of settings and the next. A step clear of `xxl` so
        /// that a gap between groups can never be mistaken for a gap inside one.
        static let xxxl: CGFloat = 32
    }

    /// Five steps, no more.
    ///
    /// Built on text styles rather than fixed point sizes. `Font.system(size:)` does not scale
    /// with Dynamic Type in SwiftUI, so an earlier version of these tokens silently switched off
    /// text scaling everywhere they were used. The line limits still adapted, which made the
    /// result look plausible in a screenshot while the type never actually grew.
    ///
    /// The chosen styles sit within half a point of the sizes the design was drawn at: title2 is
    /// 22 against a drawn 21, headline 17 against 17.5, subheadline 15, footnote 13 against 13.5,
    /// and caption2 11.
    enum Typography {
        static let lead = Font.system(.title2, weight: .semibold)
        static let headline = Font.system(.headline, weight: .semibold)
        static let category = Font.system(.subheadline)
        static let summary = Font.system(.footnote)
        /// Source marks and timestamps. Tracked and uppercased at the call site.
        static let meta = Font.system(.caption2, weight: .semibold)
        /// The nameplate. A step above metadata, because it is the one element allowed to
        /// announce itself.
        static let masthead = Font.system(.footnote, weight: .bold)
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
