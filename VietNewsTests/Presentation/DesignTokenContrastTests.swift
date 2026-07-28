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
        try assertContrast("ink", on: "bg", atLeast: 4.5)
        try assertContrast("inkSecondary", on: "bg", atLeast: 4.5)
        try assertContrast("inkTertiary", on: "bg", atLeast: 4.5)
        try assertContrast("ink", on: "surface", atLeast: 4.5)
        try assertContrast("inkSecondary", on: "surface", atLeast: 4.5)
    }

    /// A read headline recedes, but receding must not mean becoming hard to read.
    func test_givenReadHeadlineColour_whenMeasured_thenStillMeetsAA() throws {
        try assertContrast("inkRead", on: "bg", atLeast: 4.5)
    }

    func test_givenAccent_whenUsedForText_thenMeetsAA() throws {
        try assertContrast("accent", on: "bg", atLeast: 4.5)
    }

    /// Text placed on the accent, such as a selected category. White fails here, which is why
    /// the token is near black in dark mode rather than the reflexive choice.
    func test_givenTextOnAccent_whenMeasured_thenMeetsAA() throws {
        try assertContrast("onAccent", on: "accent", atLeast: 4.5)
    }

    /// Source marks are small text, so they carry the body requirement rather than the large
    /// text one, and they must never be the only thing distinguishing a source.
    func test_givenEverySourceMark_whenMeasured_thenMeetsAA() throws {
        for name in ["sourceVNExpress", "sourceNYT", "sourceBBC", "sourceSubstack", "sourceEurogamer"] {
            try assertContrast(name, on: "bg", atLeast: 4.5)
        }
    }

    func test_givenEveryToken_whenResolvedInBothAppearances_thenTheyActuallyDiffer() throws {
        let names = ["bg", "surface", "hairline", "ink", "inkSecondary", "inkTertiary", "inkRead", "accent"]
        for name in names {
            let dark = try color(name, dark: true)
            let light = try color(name, dark: false)
            XCTAssertNotEqual(
                dark, light,
                "\(name) is identical in both appearances, so it is not really adapting"
            )
        }
    }
}
