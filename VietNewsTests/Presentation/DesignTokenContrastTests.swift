import UIKit
import XCTest
@testable import VietNews

/// Recomputes WCAG contrast from the shipped asset catalog, in both appearances.
///
/// A palette checked once in a spreadsheet drifts the first time somebody nudges a colour. This
/// reads the same assets the app renders, so a change that breaks a requirement fails here.
final class DesignTokenContrastTests: XCTestCase {
    private func color(_ name: String, dark: Bool) throws -> UIColor {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        let color = try XCTUnwrap(
            UIColor(named: "Colors/\(name)", in: Bundle(for: NewsFeedViewModel.self), compatibleWith: traits),
            "missing colour set \(name)"
        )
        return color.resolvedColor(with: traits)
    }

    /// Relative luminance, per the WCAG definition.
    private func luminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func channel(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    private func ratio(_ foreground: UIColor, on background: UIColor) -> CGFloat {
        let a = luminance(foreground), b = luminance(background)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private func assertContrast(
        _ foreground: String,
        on background: String,
        atLeast required: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for dark in [true, false] {
            let measured = ratio(try color(foreground, dark: dark), on: try color(background, dark: dark))
            XCTAssertGreaterThanOrEqual(
                measured,
                required,
                "\(foreground) on \(background) in \(dark ? "dark" : "light") is \(String(format: "%.2f", measured)):1",
                file: file,
                line: line
            )
        }
    }

    func test_givenBodyTextColours_whenMeasured_thenMeetAA() throws {
        // given
        let pairs = [
            ("ink", "bg"), ("inkSecondary", "bg"), ("inkTertiary", "bg"),
            ("ink", "surface"), ("inkSecondary", "surface")
        ]

        // when
        // `assertContrast` measures and asserts together so a failure names the offending pair
        // and its ratio; measuring separately would report only that some number was too low.

        // then
        for (foreground, background) in pairs {
            try assertContrast(foreground, on: background, atLeast: 4.5)
        }
    }

    /// A read headline recedes, but receding must not mean becoming hard to read.
    func test_givenReadHeadlineColour_whenMeasured_thenStillMeetsAA() throws {
        // given
        let foreground = "inkRead"
        let background = "bg"

        // when
        // Measured and asserted in one step, so a failure names the pair and its ratio.

        // then
        try assertContrast(foreground, on: background, atLeast: 4.5)
    }

    func test_givenAccent_whenUsedForText_thenMeetsAA() throws {
        // given
        let foreground = "accent"
        let background = "bg"

        // when
        // Measured and asserted in one step, so a failure names the pair and its ratio.

        // then
        try assertContrast(foreground, on: background, atLeast: 4.5)
    }

    /// Text placed on the accent, such as a selected category. White fails here, which is why
    /// the token is near black in dark mode rather than the reflexive choice.
    func test_givenTextOnAccent_whenMeasured_thenMeetsAA() throws {
        // given
        let foreground = "onAccent"
        let background = "accent"

        // when
        // Measured and asserted in one step, so a failure names the pair and its ratio.

        // then
        try assertContrast(foreground, on: background, atLeast: 4.5)
    }

    /// Source marks are small text, so they carry the body requirement rather than the large
    /// text one, and they must never be the only thing distinguishing a source.
    func test_givenEverySourceMark_whenMeasured_thenMeetsAA() throws {
        // given
        let marks = ["sourceVNExpress", "sourceNYT", "sourceBBC", "sourceSubstack", "sourceEurogamer"]

        // when
        // Measured and asserted in one step, so a failure names the mark and its ratio.

        // then
        for name in marks {
            try assertContrast(name, on: "bg", atLeast: 4.5)
        }
    }

    /// The caution rule marks a state the reader should notice, so it is held to the same
    /// readability bar as text even though it is drawn as a rule.
    func test_givenCautionRule_whenMeasured_thenIsDistinguishableFromTheBackground() throws {
        // given
        let foreground = "caution"
        let background = "bg"

        // when
        // Measured and asserted in one step, so a failure names the pair and its ratio.

        // then
        try assertContrast(foreground, on: background, atLeast: 3.0)
    }

    /// Writes the measured table out with the results, so the audit is a record produced by
    /// every run rather than a number somebody wrote down once and stopped checking.
    func test_givenEveryTextAndBackgroundPair_whenMeasured_thenTheTableIsRecorded() throws {
        // given
        let foregrounds = [
            "ink", "inkSecondary", "inkTertiary", "inkRead", "accent", "caution",
            "sourceVNExpress", "sourceNYT", "sourceBBC", "sourceSubstack", "sourceEurogamer"
        ]
        var lines = ["foreground,background,appearance,ratio"]
        for background in ["bg", "surface"] {
            for foreground in foregrounds {
                for dark in [true, false] {
                    let measured = ratio(
                        try color(foreground, dark: dark),
                        on: try color(background, dark: dark)
                    )
                    lines.append(
                        "\(foreground),\(background),\(dark ? "dark" : "light"),\(String(format: "%.2f", measured))"
                    )
                }
            }
        }
        for dark in [true, false] {
            let measured = ratio(try color("onAccent", dark: dark), on: try color("accent", dark: dark))
            lines.append("onAccent,accent,\(dark ? "dark" : "light"),\(String(format: "%.2f", measured))")
        }
        let record = XCTAttachment(string: lines.joined(separator: "\n"))
        record.name = "contrast-audit.csv"
        record.lifetime = .keepAlways

        // when
        add(record)

        // then
        XCTAssertEqual(lines.count, foregrounds.count * 2 * 2 + 2 + 1)
    }

    func test_givenEveryToken_whenResolvedInBothAppearances_thenTheyActuallyDiffer() throws {
        // given
        let names = ["bg", "surface", "hairline", "ink", "inkSecondary", "inkTertiary", "inkRead", "accent", "caution"]

        // when
        let resolved = try names.map { (name: $0, dark: try color($0, dark: true), light: try color($0, dark: false)) }

        // then
        for entry in resolved {
            XCTAssertNotEqual(
                entry.dark, entry.light,
                "\(entry.name) is identical in both appearances, so it is not really adapting"
            )
        }
    }
}
