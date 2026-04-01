import Foundation

struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
}

struct OpenAIChatChoice: Codable {
    let message: OpenAIChatMessage
}

struct OpenAIChatResponse: Codable {
    let choices: [OpenAIChatChoice]
}
