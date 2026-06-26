import Foundation

@MainActor
final class AIService: ObservableObject {

    static let shared = AIService()

    @Published var config: AIConfig
    @Published var profiles: [AIConfig] = []
    @Published var isProcessing = false
    @Published var lastError: String?

    private static let profilesKey = "ai_profiles"
    private static let activeIDKey = "ai_active_profile_id"
    private static let legacyConfigKey = "ai_config"

    private init() {
        let loadedProfiles = AIService.loadProfiles()
        if let loadedProfiles, !loadedProfiles.isEmpty {
            self.profiles = loadedProfiles
            let activeID = AIService.loadActiveID()
            self.config = loadedProfiles.first(where: { $0.id == activeID }) ?? loadedProfiles[0]
        } else if let legacy = AIService.loadLegacyConfig() {
            // 从旧版单一配置迁移
            self.profiles = [legacy]
            self.config = legacy
        } else {
            let def = AIConfig(provider: .dashScope)
            self.profiles = [def]
            self.config = def
        }

        // Auto-fill API key from QWEN_API_KEY env var if not set
        if config.apiKey.isEmpty, let envKey = ProcessInfo.processInfo.environment["QWEN_API_KEY"], !envKey.isEmpty {
            config.apiKey = envKey
            config.provider = .dashScope
            config.endpoint = AIProvider.dashScope.defaultEndpoint
            config.model = "qwen3.7-max"
        }
        persist()
    }

    func send(
        systemPrompt: String,
        userMessage: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        guard !config.apiKey.isEmpty || config.provider == .ollama else {
            lastError = "请先在设置中配置 API Key"
            onComplete()
            return
        }
        isProcessing = true
        lastError = nil
        Task {
            do {
                try await streamChat(systemPrompt: systemPrompt, userMessage: userMessage, onToken: onToken)
            } catch {
                lastError = error.localizedDescription
            }
            isProcessing = false
            onComplete()
        }
    }

    func saveConfig() {
        // 把当前编辑中的配置同步回 profiles 列表，并持久化
        if let idx = profiles.firstIndex(where: { $0.id == config.id }) {
            profiles[idx] = config
        } else {
            profiles.append(config)
        }
        persist()
    }

    /// 切换到已保存的模型配置（无需重新输入）。
    func switchProfile(to id: UUID) {
        guard let target = profiles.first(where: { $0.id == id }) else { return }
        // 先保存当前编辑内容，避免丢失
        if let idx = profiles.firstIndex(where: { $0.id == config.id }) {
            profiles[idx] = config
        }
        config = target
        lastError = nil
        persist()
    }

    /// 新增一个模型配置并切换过去。
    @discardableResult
    func addProfile() -> AIConfig {
        if let idx = profiles.firstIndex(where: { $0.id == config.id }) {
            profiles[idx] = config
        }
        var new = AIConfig(provider: config.provider)
        new.name = "新模型"
        profiles.append(new)
        config = new
        persist()
        return new
    }

    /// 删除一个模型配置。
    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        if profiles.isEmpty {
            profiles = [AIConfig(provider: .dashScope)]
        }
        if config.id == id {
            config = profiles[0]
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.profilesKey)
        }
        UserDefaults.standard.set(config.id.uuidString, forKey: Self.activeIDKey)
    }

    private static func loadProfiles() -> [AIConfig]? {
        guard let data = UserDefaults.standard.data(forKey: profilesKey),
              let profiles = try? JSONDecoder().decode([AIConfig].self, from: data) else { return nil }
        return profiles
    }

    private static func loadActiveID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: activeIDKey) else { return nil }
        return UUID(uuidString: raw)
    }

    private static func loadLegacyConfig() -> AIConfig? {
        guard let data = UserDefaults.standard.data(forKey: legacyConfigKey),
              let config = try? JSONDecoder().decode(AIConfig.self, from: data) else { return nil }
        return config
    }

    private func streamChat(
        systemPrompt: String,
        userMessage: String,
        onToken: @escaping (String) -> Void
    ) async throws {
        let url = URL(string: "\(config.endpoint)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": config.model,
            "stream": true,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw AIError.invalidResponse }
        guard httpResponse.statusCode == 200 else {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            throw AIError.httpError(httpResponse.statusCode, errorBody)
        }
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))
            if data == "[DONE]" { break }
            guard let jsonData = data.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }
            await MainActor.run { onToken(content) }
        }
    }
}

enum AIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "无效的服务器响应"
        case .httpError(let code, let body): return "HTTP \(code): \(body.prefix(200))"
        }
    }
}
