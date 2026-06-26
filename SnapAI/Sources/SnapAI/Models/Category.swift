import Foundation

struct Category: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var systemPrompt: String
    var isBuiltin: Bool

    init(id: UUID = UUID(), name: String, icon: String, systemPrompt: String, isBuiltin: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.isBuiltin = isBuiltin
    }
}

extension Category {
    static let builtins: [Category] = [
        Category(
            name: "常规", icon: "bubble.left",
            systemPrompt: "你是一个有帮助的AI助手，请准确回答用户的问题。",
            isBuiltin: true
        ),
        Category(
            name: "翻译", icon: "globe",
            systemPrompt: "你是专业翻译。自动检测输入语言，中文译为英文，其他语言译为中文。保持原文格式，只输出翻译结果。",
            isBuiltin: true
        ),
        Category(
            name: "润色", icon: "wand.and.stars",
            systemPrompt: "请优化以下文本的表达，使其更流畅自然，不改变原意。只输出优化后的文本。",
            isBuiltin: true
        ),
        Category(
            name: "改写", icon: "arrow.triangle.2.circlepath",
            systemPrompt: "请用不同的表达方式重写以下内容，保持意思一致。只输出改写后的文本。",
            isBuiltin: true
        ),
        Category(
            name: "总结", icon: "doc.text",
            systemPrompt: "请用3-5句话总结以下内容的核心要点。",
            isBuiltin: true
        ),
        Category(
            name: "代码", icon: "chevron.left.forwardslash.chevron.right",
            systemPrompt: "请为以下代码添加中文注释并简要解释其功能。",
            isBuiltin: true
        ),
        Category(
            name: "纠错", icon: "checkmark.circle",
            systemPrompt: "请检查以下文本的语法和拼写错误，给出修正建议和修正后的文本。",
            isBuiltin: true
        ),
    ]
}
