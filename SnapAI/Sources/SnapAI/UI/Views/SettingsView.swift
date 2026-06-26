import SwiftUI

struct SettingsView: View {
    @StateObject private var aiService = AIService.shared
    @StateObject private var categoryStore = CategoryStore.shared
    @StateObject private var historyStore = HistoryStore.shared
    @State private var showAddCategoryAlert = false
    @State private var showApiKey = false
    @State private var saveIndicator = ""

    var body: some View {
        Form {
            Section("AI 服务") {
                // 已保存的模型配置，可快速切换
                HStack {
                    Picker("当前模型", selection: Binding(
                        get: { aiService.config.id },
                        set: { aiService.switchProfile(to: $0) }
                    )) {
                        ForEach(aiService.profiles) { profile in
                            Text(profile.displayName).tag(profile.id)
                        }
                    }
                    Button {
                        aiService.addProfile()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("新增模型配置")
                    Button {
                        aiService.deleteProfile(id: aiService.config.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .disabled(aiService.profiles.count <= 1)
                    .help("删除当前模型配置")
                }
                TextField("配置名称", text: $aiService.config.name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: aiService.config.name) { _, _ in saveAndFlash() }
                Picker("服务商", selection: $aiService.config.provider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .onChange(of: aiService.config.provider) { _, newProvider in
                    aiService.config.endpoint = newProvider.defaultEndpoint
                    aiService.config.model = newProvider.defaultModel
                    saveAndFlash()
                }
                TextField("API 端点", text: $aiService.config.endpoint)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: aiService.config.endpoint) { _, _ in saveAndFlash() }
                if aiService.config.provider != .ollama {
                    HStack {
                        if showApiKey {
                            SecureField("API Key", text: $aiService.config.apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            TextField("API Key", text: $aiService.config.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        Button {
                            showApiKey.toggle()
                        } label: {
                            Image(systemName: showApiKey ? "eye" : "eye.slash")
                        }
                        .buttonStyle(.borderless)
                        .help(showApiKey ? "隐藏 Key" : "显示 Key")
                    }
                    .onChange(of: aiService.config.apiKey) { _, _ in saveAndFlash() }
                }
                TextField("模型名称", text: $aiService.config.model)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: aiService.config.model) { _, _ in saveAndFlash() }

                if !saveIndicator.isEmpty {
                    Text(saveIndicator)
                        .font(.caption)
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }
            Section("自定义类别") {
                List {
                    ForEach(categoryStore.categories) { category in
                        HStack {
                            Image(systemName: category.icon).frame(width: 20)
                            Text(category.name)
                            Spacer()
                            if category.isBuiltin {
                                Text("内置").font(.caption).foregroundColor(.secondary)
                            } else {
                                Button { categoryStore.removeCategory(id: category.id) } label: {
                                    Image(systemName: "trash").foregroundColor(.red)
                                }.buttonStyle(.borderless)
                            }
                        }
                    }
                }.frame(height: 150)
                Button("添加自定义类别") { showAddCategoryAlert = true }
            }
            Section("数据") {
                HStack { Text("历史记录"); Spacer(); Text("\(historyStore.items.count) 条").foregroundStyle(.secondary) }
                Button("清除所有历史") { historyStore.clearAll() }.disabled(historyStore.items.isEmpty)
            }
            Section("关于") {
                HStack { Text("SnapAI"); Spacer(); Text("v1.0").foregroundStyle(.secondary) }
                HStack { Text("macOS"); Spacer(); Text(ProcessInfo.processInfo.operatingSystemVersionString).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .frame(minHeight: 500)
        .padding()
        .sheet(isPresented: $showAddCategoryAlert) { AddCategoryView(categoryStore: categoryStore) }
    }

    private func saveAndFlash() {
        aiService.saveConfig()
        withAnimation { saveIndicator = "✓ 已保存" }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { saveIndicator = "" }
        }
    }
}

struct AddCategoryView: View {
    @ObservedObject var categoryStore: CategoryStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var icon = "star"
    @State private var systemPrompt = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("添加自定义类别").font(.headline)
            TextField("名称", text: $name).textFieldStyle(.roundedBorder)
            TextField("图标 (SF Symbol)", text: $icon).textFieldStyle(.roundedBorder)
            TextEditor(text: $systemPrompt).frame(height: 120).border(.secondary.opacity(0.3))
            HStack {
                Button("取消") { dismiss() }
                Spacer()
                Button("添加") {
                    categoryStore.addCategory(Category(name: name, icon: icon, systemPrompt: systemPrompt, isBuiltin: false))
                    dismiss()
                }.disabled(name.isEmpty || systemPrompt.isEmpty).keyboardShortcut(.defaultAction)
            }
        }.padding().frame(width: 400)
    }
}

@MainActor
final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?
    private init() {}

    func showSettings() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hostingController)
        window.isReleasedWhenClosed = false
        window.title = "SnapAI 偏好设置"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
