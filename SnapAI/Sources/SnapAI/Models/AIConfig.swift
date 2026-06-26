import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case dashScope = "DashScope"
    case openAI = "OpenAI"
    case deepSeek = "DeepSeek"
    case ollama = "Ollama"

    var defaultEndpoint: String {
        switch self {
        case .dashScope: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .openAI:    return "https://api.openai.com/v1"
        case .deepSeek:  return "https://api.deepseek.com"
        case .ollama:    return "http://localhost:11434/v1"
        }
    }

    var defaultModel: String {
        switch self {
        case .dashScope: return "qwen3.7-max"
        case .openAI:    return "gpt-4o-mini"
        case .deepSeek:  return "deepseek-v4-flash"
        case .ollama:    return "qwen2.5:7b"
        }
    }
}

struct AIConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var provider: AIProvider
    var endpoint: String
    var apiKey: String
    var model: String

    init(id: UUID = UUID(), name: String = "", provider: AIProvider = .dashScope) {
        self.id = id
        self.provider = provider
        self.endpoint = provider.defaultEndpoint
        self.apiKey = ""
        self.model = provider.defaultModel
        self.name = name
    }

    /// 在 UI 上展示的名称：优先使用用户起的名字，否则用 "服务商 · 模型"。
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "\(provider.rawValue) · \(model)" : trimmed
    }

    // 兼容旧版本（只有 provider/endpoint/apiKey/model 字段）的存档。
    enum CodingKeys: String, CodingKey {
        case id, name, provider, endpoint, apiKey, model
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.provider = try c.decode(AIProvider.self, forKey: .provider)
        self.endpoint = try c.decode(String.self, forKey: .endpoint)
        self.apiKey = try c.decode(String.self, forKey: .apiKey)
        self.model = try c.decode(String.self, forKey: .model)
    }
}
