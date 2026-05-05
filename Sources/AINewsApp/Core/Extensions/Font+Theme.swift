import SwiftUI

// MARK: - Typography scale (marker.)
// All fonts respond to Dynamic Type via `relativeTo:` parameter.
// User's "Settings → Display & Brightness → Text Size" preference applies.
extension Font {
    // Display — Instrument Serif (relativeTo: .largeTitle/.title scaling)
    static let displayXL  = Font.custom("InstrumentSerif-Regular", size: 56, relativeTo: .largeTitle).weight(.regular)
    static let displayLG  = Font.custom("InstrumentSerif-Regular", size: 40, relativeTo: .largeTitle).weight(.regular)
    static let displayMD  = Font.custom("InstrumentSerif-Regular", size: 36, relativeTo: .title).weight(.regular)
    static let displaySM  = Font.custom("InstrumentSerif-Regular", size: 30, relativeTo: .title2).weight(.regular)
    static let displayXS  = Font.custom("InstrumentSerif-Regular", size: 22, relativeTo: .title3).weight(.regular)

    // Display italic
    static let displayItalicXL = Font.custom("InstrumentSerif-Italic", size: 56, relativeTo: .largeTitle).weight(.regular)
    static let displayItalicMD = Font.custom("InstrumentSerif-Italic", size: 40, relativeTo: .largeTitle).weight(.regular)

    // Body — system sans (Dynamic Type tarafından zaten ölçeklenir)
    static let bodyLG  = Font.system(.body)
    static let bodyMD  = Font.system(.callout)
    static let bodySM  = Font.system(.footnote)

    // Heading — semibold
    static let headingLG = Font.system(.body).weight(.semibold)
    static let headingMD = Font.system(.callout).weight(.semibold)
    static let headingSM = Font.system(.footnote).weight(.semibold)

    // Label — monospace caption
    static let labelLG = Font.system(.caption).weight(.medium).monospaced()
    static let labelMD = Font.system(.caption2).weight(.medium).monospaced()
    static let labelSM = Font.system(.caption2).weight(.medium).monospaced()
}

// MARK: - Spacing
enum Spacing {
    static let xs   : CGFloat = 4
    static let sm   : CGFloat = 8
    static let md   : CGFloat = 12
    static let lg   : CGFloat = 16
    static let xl   : CGFloat = 20
    static let xxl  : CGFloat = 24
    static let xxxl : CGFloat = 32
    static let huge : CGFloat = 48
}

// MARK: - Radius
enum Radius {
    static let xs  : CGFloat = 6
    static let sm  : CGFloat = 10
    static let md  : CGFloat = 14
    static let lg  : CGFloat = 18
    static let xl  : CGFloat = 22
    static let xxl : CGFloat = 24
    static let full: CGFloat = 999
}
