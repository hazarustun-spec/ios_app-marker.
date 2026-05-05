import SwiftUI

// MARK: - Typography scale (marker.)
extension Font {
    // Display — Instrument Serif
    static let displayXL  = Font.custom("InstrumentSerif-Regular", size: 56).weight(.regular)
    static let displayLG  = Font.custom("InstrumentSerif-Regular", size: 40).weight(.regular)
    static let displayMD  = Font.custom("InstrumentSerif-Regular", size: 36).weight(.regular)
    static let displaySM  = Font.custom("InstrumentSerif-Regular", size: 30).weight(.regular)
    static let displayXS  = Font.custom("InstrumentSerif-Regular", size: 22).weight(.regular)

    // Display italic
    static let displayItalicXL = Font.custom("InstrumentSerif-Italic", size: 56).weight(.regular)
    static let displayItalicMD = Font.custom("InstrumentSerif-Italic", size: 40).weight(.regular)

    // Body — system sans
    static let bodyLG  = Font.system(size: 16, weight: .regular)
    static let bodyMD  = Font.system(size: 14.5, weight: .regular)
    static let bodySM  = Font.system(size: 13, weight: .regular)

    // Heading — system sans semibold
    static let headingLG = Font.system(size: 16, weight: .semibold)
    static let headingMD = Font.system(size: 15, weight: .semibold)
    static let headingSM = Font.system(size: 13, weight: .semibold)

    // Label — monospace
    static let labelLG = Font.system(size: 12, weight: .medium).monospaced()
    static let labelMD = Font.system(size: 11, weight: .medium).monospaced()
    static let labelSM = Font.system(size: 10, weight: .medium).monospaced()
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
