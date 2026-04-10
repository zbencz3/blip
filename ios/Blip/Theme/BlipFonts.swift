import SwiftUI

enum BlipFonts {
    // MARK: - Display (large headings)
    /// 44pt black monospaced — app name, hero text
    static let hero = Font.system(size: 44, weight: .black, design: .monospaced)
    /// 32pt bold — page headings (subscription)
    static let display = Font.system(size: 32, weight: .bold)

    // MARK: - Titles
    /// 24pt black monospaced — status text (UP/DOWN)
    static let titleLarge = Font.system(size: 24, weight: .black, design: .monospaced)
    /// 20pt bold monospaced — stats numbers (uptime %)
    static let titleMono = Font.system(size: 20, weight: .black, design: .monospaced)
    /// 18pt semibold monospaced — section titles, view subtitles
    static let title = Font.system(size: 18, weight: .semibold, design: .monospaced)
    /// 16pt semibold monospaced — button text, row titles
    static let subtitle = Font.system(size: 16, weight: .semibold, design: .monospaced)

    // MARK: - Body
    /// 15pt bold monospaced — card titles (monitor name)
    static let cardTitle = Font.system(size: 15, weight: .bold, design: .monospaced)
    /// 15pt regular monospaced — text fields
    static let input = Font.system(size: 15, design: .monospaced)
    /// 14pt semibold monospaced — labels, prompt text
    static let label = Font.system(size: 14, weight: .semibold, design: .monospaced)
    /// 14pt bold monospaced — emphasized labels
    static let labelBold = Font.system(size: 14, weight: .bold, design: .monospaced)

    // MARK: - Caption
    /// 13pt semibold monospaced — picker button text
    static let button = Font.system(size: 13, weight: .semibold, design: .monospaced)
    /// 13pt regular monospaced — secondary text
    static let caption = Font.system(size: 13, design: .monospaced)
    /// 12pt semibold monospaced — small button text, action labels
    static let smallButton = Font.system(size: 12, weight: .semibold, design: .monospaced)
    /// 12pt regular monospaced — helper text, descriptions
    static let small = Font.system(size: 12, design: .monospaced)

    // MARK: - Micro
    /// 11pt bold monospaced — section labels (URL, INTERVAL, etc.)
    static let sectionLabel = Font.system(size: 11, weight: .bold, design: .monospaced)
    /// 11pt medium monospaced — timestamps, metadata
    static let metadata = Font.system(size: 11, weight: .medium, design: .monospaced)
    /// 11pt regular monospaced — helper/info text
    static let helper = Font.system(size: 11, design: .monospaced)

    // MARK: - Tiny
    /// 10pt bold monospaced — status badges (UP/DOWN capsule)
    static let badge = Font.system(size: 10, weight: .bold, design: .monospaced)
    /// 10pt regular monospaced — timestamps, relative dates
    static let tiny = Font.system(size: 10, design: .monospaced)
    /// 9pt bold monospaced — dashboard labels (UP/DOWN/PAUSED)
    static let micro = Font.system(size: 9, weight: .bold, design: .monospaced)

    // MARK: - Code
    /// 12pt monospaced — code snippets, curl commands
    static let code = Font.system(size: 12, design: .monospaced)
    /// 10pt monospaced — inline code examples
    static let codeSmall = Font.system(size: 10, design: .monospaced)

    // MARK: - Legacy (for views still using non-monospaced)
    /// 16pt regular — non-monospaced body (settings, subscription)
    static let body = Font.system(size: 16)
    /// 13pt regular — non-monospaced caption
    static let captionRegular = Font.system(size: 13)
    /// 18pt semibold — non-monospaced section header
    static let sectionHeader = Font.system(size: 18, weight: .semibold)
}
