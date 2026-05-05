import SwiftUI

struct Topic: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let description: String

    var color: Color {
        switch id {
        case "llms":         return .topicLLMs
        case "robotics":     return .topicRobotics
        case "research":     return .topicResearch
        case "safety":       return .topicSafety
        case "vision":       return .topicVision
        case "tools":        return .topicTools
        case "business":     return .topicBusiness
        case "policy":       return .topicPolicy
        case "generative":   return .topicGenerative
        case "healthcare":   return .topicHealthcare
        default:             return .brandPrimary
        }
    }
}

extension Topic {
    static let all: [Topic] = [
        Topic(id: "llms",        name: "LLM'ler",        emoji: "🧠", description: "Büyük dil modelleri, GPT, Claude, Gemini"),
        Topic(id: "robotics",    name: "Robotik",        emoji: "🤖", description: "Yapay zekâ destekli robotlar ve otomasyon"),
        Topic(id: "research",    name: "Araştırma",      emoji: "🔬", description: "Akademik makaleler ve gelişmeler"),
        Topic(id: "safety",      name: "AI Güvenliği",   emoji: "🛡️", description: "Hizalama, etik ve sorumlu yapay zekâ"),
        Topic(id: "vision",      name: "Görsel AI",      emoji: "👁️", description: "Görüntü tanıma ve video anlama"),
        Topic(id: "tools",       name: "AI Araçları",    emoji: "⚡",  description: "Yeni AI ürünleri ve geliştirici araçları"),
        Topic(id: "business",    name: "AI Ekonomisi",   emoji: "💼", description: "Yatırım, satın alma, pazar haberleri"),
        Topic(id: "policy",      name: "AI Politikası",  emoji: "⚖️", description: "Düzenleme, mevzuat, yönetişim"),
        Topic(id: "generative",  name: "Üretken AI",     emoji: "🎨", description: "Görsel, video, ses üretimi"),
        Topic(id: "healthcare",  name: "AI Sağlık",      emoji: "🏥", description: "Tıbbi yapay zekâ, ilaç keşfi, tanı"),
    ]
}
