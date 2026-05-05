import SwiftUI

// MARK: - Design tokens: marker. light theme
extension Color {
    static let bgPrimary      = Color(hex: "#FFFFFF")
    static let bgSecondary    = Color(hex: "#F2F4EC")
    static let bgCard         = Color(hex: "#F2F4EC")
    static let textPrimary    = Color(hex: "#0E0E0E")
    static let textSecondary  = Color(hex: "#666666")
    static let textTertiary   = Color(hex: "#888888")
    static let textDisabled   = Color(hex: "#AAAAAA")
    static let brandPrimary   = Color(hex: "#C8DC92")
    static let brandSecondary = Color(hex: "#C5D5B8")
    static let toneMint       = Color(hex: "#C8DC92")
    static let toneSage       = Color(hex: "#C5D5B8")
    static let toneCream      = Color(hex: "#EDE7D9")
    static let success        = Color(hex: "#5a8a3a")
    static let warning        = Color(hex: "#C8A030")
    static let error          = Color(hex: "#C0392B")
    static let borderDefault  = Color(hex: "#EEEEEE")
    static let borderSubtle   = Color(hex: "#F5F5F5")
    static let navBackground  = Color(hex: "#0E0E0E")

    // Per-topic (kept for topic chips/onboarding)
    static let topicLLMs       = Color(hex: "#C8DC92")
    static let topicRobotics   = Color(hex: "#C5D5B8")
    static let topicResearch   = Color(hex: "#EDE7D9")
    static let topicSafety     = Color(hex: "#C8DC92")
    static let topicVision     = Color(hex: "#C5D5B8")
    static let topicTools      = Color(hex: "#EDE7D9")
    static let topicBusiness   = Color(hex: "#C8DC92")
    static let topicPolicy     = Color(hex: "#C5D5B8")
    static let topicGenerative = Color(hex: "#EDE7D9")
    static let topicHealthcare = Color(hex: "#C8DC92")
}

extension LinearGradient {
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "#C8DC92"), Color(hex: "#C5D5B8")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Card tone
struct CardTone {
    let background: Color
    let text: Color
    let sub: Color

    static let mint  = CardTone(background: .toneMint,  text: Color(hex: "#1a1a1a"), sub: Color(hex: "#3a3f2a"))
    static let sage  = CardTone(background: .toneSage,  text: Color(hex: "#1a1a1a"), sub: Color(hex: "#3a443a"))
    static let cream = CardTone(background: .toneCream, text: Color(hex: "#1a1a1a"), sub: Color(hex: "#4a4538"))

    static func forTopicId(_ id: String) -> CardTone {
        switch id {
        case "llms", "safety", "business", "healthcare": return .mint
        case "robotics", "vision", "policy":             return .sage
        default:                                          return .cream
        }
    }
}

// MARK: - Hex init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}
