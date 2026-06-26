import SwiftUI

struct AITaskView: View {
    @EnvironmentObject var categoryStore: CategoryStore
    @EnvironmentObject var historyStore: HistoryStore
    @StateObject private var aiService = AIService.shared
    @State private var selectedCategoryID: UUID?
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isStreaming: Bool = false
    @State private var showHistory: Bool = false
    @State private var showCategoryMenu: Bool = false
    
    // 固定显示的类别数量（不含动态槽位）
    private let pinnedCount = 3
    @State private var lastOverflowCategory: Category?

    private var pinnedCategories: [Category] {
        let base = Array(categoryStore.categories.prefix(pinnedCount))
        if let overflow = lastOverflowCategory {
            return base + [overflow]
        }
        return base
    }

    private var overflowCategories: [Category] {
        let all = categoryStore.categories
        let pinnedIDs = Set(pinnedCategories.map(\.id))
        return all.filter { !pinnedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryBar
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    inputSection
                    actionButtons
                    outputSection
                }
                .padding(12)
            }
            Divider()
            footer
        }
        .frame(width: 380)
        .onChange(of: inputText) { _, newValue in
            if newValue.hasSuffix("\n") {
                inputText = String(newValue.dropLast())
                if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    executeTask()
                }
            } else {
                outputText = ""
                aiService.lastError = nil
            }
        }
        .onAppear {
            if selectedCategoryID == nil {
                selectedCategoryID = categoryStore.categories.first?.id
            }
        }
    }

    private var categoryBar: some View {
        HStack(spacing: 4) {
            // 固定显示的类别
            ForEach(pinnedCategories) { category in
                CategoryChip(
                    category: category,
                    isSelected: category.id == selectedCategoryID
                ) {
                    selectedCategoryID = category.id
                }
            }
            
            // 下拉菜单（如果有更多类别）
            if !overflowCategories.isEmpty {
                Menu {
                    ForEach(overflowCategories) { category in
                        Button {
                            selectedCategoryID = category.id
                            lastOverflowCategory = category
                        } label: {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.name)
                                if category.id == selectedCategoryID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(overflowCategories.contains(where: { $0.id == selectedCategoryID }) 
                                  ? Color.accentColor.opacity(0.15) 
                                  : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(overflowCategories.contains(where: { $0.id == selectedCategoryID })
                                    ? Color.accentColor 
                                    : Color.secondary.opacity(0.3), 
                                    lineWidth: overflowCategories.contains(where: { $0.id == selectedCategoryID }) ? 1.5 : 1)
                    )
                    .foregroundColor(overflowCategories.contains(where: { $0.id == selectedCategoryID }) 
                                     ? .accentColor 
                                     : .primary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("输入").font(.caption).foregroundColor(.secondary)
                Spacer()
                if !inputText.isEmpty {
                    Button { inputText = "" } label: {
                        Label("清空", systemImage: "xmark.circle").font(.caption)
                    }.buttonStyle(.plain)
                }
            }
            TextEditor(text: $inputText)
                .font(.system(size: 13))
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
        }
    }

    private var actionButtons: some View {
        Button { executeTask() } label: {
            HStack(spacing: 4) {
                if aiService.isProcessing { ProgressView().controlSize(.small) }
                else { Image(systemName: "play.fill") }
                Text("执行")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isProcessing)
        .keyboardShortcut(.return, modifiers: .command)
    }

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("输出").font(.caption).foregroundColor(.secondary)
                Spacer()
                if !outputText.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(outputText, forType: .string)
                    } label: {
                        Label("复制", systemImage: "doc.on.doc").font(.caption)
                    }.buttonStyle(.plain)
                }
            }
            if let error = aiService.lastError {
                Text(error).font(.caption).foregroundColor(.red)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.red.opacity(0.1)))
            } else if !outputText.isEmpty || isStreaming {
                ScrollView {
                    Text(outputText.isEmpty ? "..." : outputText)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 60, maxHeight: 160)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
            }
        }
    }

    private var footer: some View {
        HStack {
            Menu {
                ForEach(aiService.profiles) { profile in
                    Button {
                        aiService.switchProfile(to: profile.id)
                    } label: {
                        HStack {
                            Text(profile.displayName)
                            if profile.id == aiService.config.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(aiService.config.displayName).font(.caption2)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("切换模型")
            Spacer()
            Button { showHistory.toggle() } label: {
                Label("历史", systemImage: "clock").font(.caption)
            }.buttonStyle(.plain)
            .popover(isPresented: $showHistory) {
                HistoryView().environmentObject(historyStore)
            }
            Button {
                FloatingWindowManager.shared.show(initialInput: inputText, categoryID: selectedCategoryID)
                // Small delay to ensure floating window is visible before closing popover
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    PopoverManager.shared.close()
                }
            } label: {
                Label("浮窗", systemImage: "pin").font(.caption)
            }.buttonStyle(.plain)
            .help("切换到浮窗模式")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func executeTask() {
        guard let categoryID = selectedCategoryID,
              let category = categoryStore.categories.first(where: { $0.id == categoryID }) else { return }
        outputText = ""
        isStreaming = true
        aiService.send(
            systemPrompt: category.systemPrompt,
            userMessage: inputText,
            onToken: { token in outputText += token },
            onComplete: {
                isStreaming = false
                if !outputText.isEmpty {
                    let item = HistoryItem(categoryID: category.id, categoryName: category.name, input: inputText, output: outputText)
                    historyStore.addItem(item)
                }
            }
        )
    }
}

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: category.icon).font(.caption)
                Text(category.name).font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 1.5 : 1))
            .foregroundColor(isSelected ? .accentColor : .primary)
        }.buttonStyle(.plain)
    }
}

struct HistoryView: View {
    @EnvironmentObject var historyStore: HistoryStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("历史记录").font(.headline)
                Spacer()
                if !historyStore.items.isEmpty {
                    Button("清空") { historyStore.clearAll() }.font(.caption).foregroundColor(.red)
                }
            }.padding(12)
            Divider()
            if historyStore.items.isEmpty {
                Text("暂无历史记录").foregroundColor(.secondary).frame(maxWidth: .infinity, minHeight: 100)
            } else {
                List(historyStore.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.categoryName).font(.caption.bold())
                            Spacer()
                            Text(item.timestamp.formatted(.relative(presentation: .named))).font(.caption2).foregroundColor(.secondary)
                        }
                        Text(item.input.prefix(50)).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }.padding(.vertical, 2)
                }.frame(minHeight: 200)
            }
        }.frame(width: 320)
    }
}
