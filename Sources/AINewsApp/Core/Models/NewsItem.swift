import Foundation

struct NewsItem: Identifiable, Codable, Hashable {
    let id: UUID
    let topicId: String
    let date: Date
    let title: String
    let summary: String
    let body: String
    let sourceUrls: [String]
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case topicId    = "topic_id"
        case date
        case title
        case summary
        case body
        case sourceUrls = "source_urls"
        case createdAt  = "created_at"
    }
}

extension NewsItem {
    var topic: Topic? {
        Topic.all.first { $0.id == topicId }
    }

    var readTime: String {
        let wordCount = body.split(separator: " ").count
        let minutes = max(1, wordCount / 200)
        return "\(minutes) min read"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Mock Data
extension NewsItem {
    static let mock = NewsItem(
        id: UUID(),
        topicId: "llms",
        date: Date(),
        title: "OpenAI Releases GPT-5 with Breakthrough Reasoning Capabilities",
        summary: "OpenAI has announced GPT-5, claiming significant improvements in reasoning, mathematics, and code generation. The model reportedly achieves human-expert level on several benchmarks.",
        body: """
        OpenAI has unveiled GPT-5, its most capable language model to date, featuring substantial improvements across reasoning, mathematics, and programming tasks.

        The new model achieves unprecedented scores on established benchmarks, surpassing human performance in several domains including advanced mathematics and scientific reasoning. Early testers report that the model can solve complex multi-step problems with remarkable accuracy.

        Perhaps most notably, GPT-5 demonstrates improved calibration — it's better at knowing when it doesn't know something, a persistent challenge in previous generations. The model also features enhanced instruction following and reduced hallucination rates.

        API access is being rolled out gradually, with enterprise customers gaining access first. Consumer products powered by GPT-5 are expected to arrive in the coming weeks.

        The release marks a significant milestone in AI development, with implications for education, software engineering, scientific research, and countless other fields.
        """,
        sourceUrls: ["https://openai.com/research/gpt-5"],
        createdAt: Date()
    )

    static let mockList: [NewsItem] = [
        NewsItem(
            id: UUID(), topicId: "llms", date: Date(),
            title: "OpenAI Releases GPT-5 with Breakthrough Reasoning",
            summary: "OpenAI has announced GPT-5, claiming significant improvements in reasoning, mathematics, and code generation.",
            body: "Full article body here...", sourceUrls: [], createdAt: Date()
        ),
        NewsItem(
            id: UUID(), topicId: "robotics", date: Date(),
            title: "Boston Dynamics Unveils New Autonomous Warehouse Robot",
            summary: "The company's latest robot can navigate complex warehouse environments without human guidance, a major step for industrial automation.",
            body: "Full article body here...", sourceUrls: [], createdAt: Date()
        ),
        NewsItem(
            id: UUID(), topicId: "research", date: Date(),
            title: "DeepMind Solves Long-Standing Protein Structure Problem",
            summary: "DeepMind's latest research tackles a major challenge in computational biology, with potential implications for drug discovery.",
            body: "Full article body here...", sourceUrls: [], createdAt: Date()
        ),
        NewsItem(
            id: UUID(), topicId: "tools", date: Date(),
            title: "Anthropic Launches Claude's New Code Editor Integration",
            summary: "The new tool deeply integrates Claude into popular IDEs, offering real-time code review and intelligent refactoring suggestions.",
            body: "Full article body here...", sourceUrls: [], createdAt: Date()
        ),
        NewsItem(
            id: UUID(), topicId: "generative", date: Date(),
            title: "Sora Competitor Generates Feature-Length Films in Minutes",
            summary: "A new video generation model from a startup claims to produce hour-long consistent video from simple text prompts.",
            body: "Full article body here...", sourceUrls: [], createdAt: Date()
        ),
    ]
}
