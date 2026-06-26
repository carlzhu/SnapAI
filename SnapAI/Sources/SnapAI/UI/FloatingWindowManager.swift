import AppKit
import SwiftUI
import MarkdownUI

// MARK: - Floating Window Manager

@MainActor
final class FloatingWindowManager: ObservableObject {
    static let shared = FloatingWindowManager()
    
    private var mainWindow: FloatingWindow?
    
    @Published var learningText: String = ""
    @Published var isLearningStreaming: Bool = false
    @Published var isLearningPanelShown: Bool = false
    /// 是否置顶（始终在最前）。默认置顶，可在浮窗上切换。
    @Published var isPinned: Bool = true
    /// 每次进入浮窗都会更新，用来通知已打开的浮窗重置为全新会话。
    @Published var sessionToken = UUID()
    /// 进入浮窗时带过去的输入内容与类别（来自当前输入框）。
    private(set) var requestedInput: String = ""
    private(set) var requestedCategoryID: UUID?
    
    private init() {}
    
    /// 切换窗口置顶状态。
    func togglePin() {
        isPinned.toggle()
        mainWindow?.level = isPinned ? .floating : .normal
    }
    
    func show(initialInput: String = "", categoryID: UUID? = nil) {
        // 每次进入浮窗都重置为全新会话，并把当前输入框的内容带过去，
        // 不保留上一次关闭前的输入/输出/学习内容。
        requestedInput = initialInput
        requestedCategoryID = categoryID
        learningText = ""
        isLearningStreaming = false
        isLearningPanelShown = false
        sessionToken = UUID()
        
        guard mainWindow == nil else {
            mainWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let categoryStore = CategoryStore.shared
        let historyStore = HistoryStore.shared
        
        let contentView = FloatingAITaskView(onClose: { [weak self] in
            self?.close()
        })
        .environmentObject(categoryStore)
        .environmentObject(historyStore)
        
        let window = FloatingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "SnapAI"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.level = isPinned ? .floating : .normal
        window.isOpaque = false
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 400)
        
        // 使用 NSHostingView 作为 contentView，确保 SwiftUI 内容始终撑满整个窗口
        // （NSHostingController + sizingOptions=[] 会让无固定理想高度的内容塌缩，
        //  导致窗口只显示标题栏，需要手动拉伸才出现内容）
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 420, height: 600)
        
        // 强制设置初始大小和位置
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 210
            let y = screenFrame.midY - 300
            window.setFrame(NSRect(x: x, y: y, width: 420, height: 600), display: true)
        }
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.mainWindow = window
    }
    
    func close() {
        isLearningPanelShown = false
        mainWindow?.orderOut(nil)
        mainWindow = nil
    }
    
    var isShown: Bool {
        mainWindow != nil
    }
}

// MARK: - Floating Window

final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - NSTextView Wrapper (fixes ⌘V)

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = NSFont.systemFont(ofSize: 13)
    /// 用户按下回车（非 Shift+回车）时触发。粘贴/普通输入不会触发，避免“粘贴即自动翻译”。
    var onSubmit: (() -> Void)? = nil
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = font
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        
        scrollView.documentView = textView
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onSubmit = onSubmit
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSubmit: (() -> Void)?
        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            _text = text
            self.onSubmit = onSubmit
        }
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Shift+回车：插入换行，便于多行输入
                if let event = NSApp.currentEvent, event.modifierFlags.contains(.shift) {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                }
                // 普通回车：提交执行，并且不插入换行
                onSubmit?()
                return true
            }
            return false
        }
    }
}

// MARK: - Custom Markdown Theme (dark/light mode friendly)

extension Theme {
    static let snapAI = Theme()
        .text {
            FontSize(12)
            ForegroundColor(.primary)
        }
        .link {
            ForegroundColor(.accentColor)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(16)
                    ForegroundColor(.primary)
                }
                .overlay(alignment: .bottom) {
                    Divider()
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 14, bottom: 6)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(14)
                    ForegroundColor(.primary)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 0.5)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 10, bottom: 4)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(13)
                    ForegroundColor(.primary)
                }
        }
        .strong {
            FontWeight(.bold)
            ForegroundColor(.primary)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(11)
            ForegroundColor(.orange)
            BackgroundColor(Color.secondary.opacity(0.1))
        }
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(11)
                    }
                    .padding(8)
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: 6, bottom: 6)
        }
        .blockquote { configuration in
            configuration.label
                .markdownTextStyle {
                    ForegroundColor(.secondary)
                    FontStyle(.italic)
                }
                .padding(.leading, 8)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 3)
                }
                .markdownMargin(top: 6, bottom: 6)
        }
        .table { configuration in
            configuration.label
                .markdownTableBorderStyle(
                    TableBorderStyle(color: Color.secondary.opacity(0.3), width: 0.5)
                )
                .markdownMargin(top: 6, bottom: 6)
        }
        .thematicBreak {
            Divider()
                .markdownMargin(top: 10, bottom: 10)
        }
        .paragraph { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(12)
                    ForegroundColor(.primary)
                }
                .markdownMargin(top: 0, bottom: 4)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2, bottom: 2)
        }
}

// MARK: - Floating AI Task View

struct FloatingAITaskView: View {
    @EnvironmentObject var categoryStore: CategoryStore
    @EnvironmentObject var historyStore: HistoryStore
    @StateObject private var aiService = AIService.shared
    @ObservedObject private var manager = FloatingWindowManager.shared
    @State private var selectedCategoryID: UUID?
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isStreaming: Bool = false
    @State private var showHistory: Bool = false
    @State private var lastOverflowCategory: Category?
    let onClose: () -> Void
    
    private let pinnedCount = 3
    private let collapsedWidth: CGFloat = 420
    private let expandedWidth: CGFloat = 840
    
    private var pinnedCategories: [Category] {
        let base = Array(categoryStore.categories.prefix(pinnedCount))
        if let overflow = lastOverflowCategory { return base + [overflow] }
        return base
    }
    
    private var overflowCategories: [Category] {
        let all = categoryStore.categories
        let pinnedIDs = Set(pinnedCategories.map(\.id))
        return all.filter { !pinnedIDs.contains($0.id) }
    }
    
    private var isTranslationCategory: Bool {
        guard let id = selectedCategoryID else { return false }
        return categoryStore.categories.first(where: { $0.id == id })?.name == "翻译"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 统一的顶部标题栏（横跨整个窗口宽度）：只有一个关闭按钮，
            // 也避免左右两个独立标题栏在标题栏区域留下中间那条白色竖缝。
            topBar
            Divider()
            HStack(spacing: 0) {
                // Main panel
                mainPanel
                    .frame(idealWidth: collapsedWidth, maxWidth: collapsedWidth, maxHeight: .infinity)
                
                // Learning panel (inline, slides in)
                if manager.isLearningPanelShown {
                    Divider()
                    learningPanel
                        .frame(idealWidth: collapsedWidth, maxWidth: collapsedWidth, maxHeight: .infinity)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.25), value: manager.isLearningPanelShown)
        .onChange(of: inputText) { _, _ in
            // 编辑输入时清掉上一次的结果/错误；不再因为结尾换行（如粘贴）自动翻译，
            // 翻译只在用户按回车（NativeTextEditor.onSubmit）或点击“执行”时触发。
            outputText = ""
            aiService.lastError = nil
        }
        .onChange(of: manager.isLearningPanelShown) { _, isShown in
            // Resize window when panel toggles — 用与内容动画一致的时长/曲线，避免生硬
            guard let window = NSApp.windows.first(where: { $0 is FloatingWindow }) else { return }
            let targetWidth = isShown ? expandedWidth : collapsedWidth
            let newFrame = NSRect(
                x: window.frame.origin.x,
                y: window.frame.origin.y,
                width: targetWidth,
                height: window.frame.height
            )
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }
        }
        .onChange(of: manager.sessionToken) { _, _ in
            // 浮窗已打开时再次进入：重置为全新会话并带入当前输入
            inputText = manager.requestedInput
            outputText = ""
            aiService.lastError = nil
            if let cat = manager.requestedCategoryID {
                selectedCategoryID = cat
            }
        }
        .onAppear {
            // 新建浮窗：带入当前输入框内容，输出从空开始
            inputText = manager.requestedInput
            outputText = ""
            aiService.lastError = nil
            if let cat = manager.requestedCategoryID {
                selectedCategoryID = cat
            } else if selectedCategoryID == nil {
                selectedCategoryID = categoryStore.categories.first?.id
            }
        }
    }
    
    // MARK: - Top Bar (unified, full-width)
    
    private var topBar: some View {
        HStack(spacing: 12) {
            Text("SnapAI")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
            // 翻译类别：学习面板切换按钮
            if isTranslationCategory {
                Button {
                    toggleLearning()
                } label: {
                    Image(systemName: "book.pages")
                        .font(.title3)
                        .foregroundColor(manager.isLearningPanelShown ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(manager.isLearningPanelShown ? "收起学习面板" : "展开学习面板")
            }
            // 置顶 / 取消置顶
            Button {
                manager.togglePin()
            } label: {
                Image(systemName: manager.isPinned ? "pin.fill" : "pin.slash")
                    .font(.title3)
                    .foregroundColor(manager.isPinned ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(manager.isPinned ? "取消置顶" : "置顶窗口")
            // 唯一的关闭按钮：关闭整个浮窗
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("关闭窗口")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }
    
    private func toggleLearning() {
        if manager.isLearningPanelShown {
            manager.isLearningPanelShown = false
        } else if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            executeTranslationWithLearning()
        } else {
            manager.isLearningPanelShown = true
        }
    }
    
    // MARK: - Main Panel
    
    private var mainPanel: some View {
        VStack(spacing: 0) {
            categoryBar
                .background(.ultraThinMaterial)
            
            Divider()
            
            VStack(spacing: 12) {
                inputSection
                actionButtons
                outputSection
            }
            .padding(12)
            .background(.regularMaterial)
            
            Divider()
            
            footer
                .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Learning Panel (inline side panel)
    
    private var learningPanel: some View {
        VStack(spacing: 0) {
            // Sub-header (no close button — 关闭由顶部统一的按钮/书本图标控制)
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.accentColor)
                Text("学习详情")
                    .font(.headline)
                Spacer()
                if !manager.learningText.isEmpty {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(manager.learningText, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("复制全部内容")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            
            Divider()
            
            if manager.isLearningStreaming || !manager.learningText.isEmpty {
                ScrollView {
                    Markdown(manager.learningText)
                        .markdownTheme(.snapAI)
                        .padding(12)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "graduationcap")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.3))
                    VStack(spacing: 8) {
                        Text("输入文本后执行翻译")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("将自动展示详细学习分析")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Category Bar
    
    private var categoryBar: some View {
        HStack(spacing: 4) {
            ForEach(pinnedCategories) { category in
                CategoryChip(
                    category: category,
                    isSelected: category.id == selectedCategoryID
                ) {
                    selectedCategoryID = category.id
                    // 切换离开翻译时关闭学习面板
                    if category.name != "翻译" && manager.isLearningPanelShown {
                        manager.isLearningPanelShown = false
                    }
                }
            }
            
            if !overflowCategories.isEmpty {
                Menu {
                    ForEach(overflowCategories) { category in
                        Button {
                            selectedCategoryID = category.id
                            lastOverflowCategory = category
                            if category.name != "翻译" && manager.isLearningPanelShown {
                                manager.isLearningPanelShown = false
                            }
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
                    .contentShape(Rectangle())
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(overflowCategories.contains(where: { $0.id == selectedCategoryID })
                                  ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(overflowCategories.contains(where: { $0.id == selectedCategoryID })
                                    ? Color.accentColor : Color.secondary.opacity(0.3),
                                    lineWidth: overflowCategories.contains(where: { $0.id == selectedCategoryID }) ? 1.5 : 1)
                    )
                    .foregroundColor(overflowCategories.contains(where: { $0.id == selectedCategoryID })
                                     ? .accentColor : .primary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Input Section
    
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
            NativeTextEditor(text: $inputText, onSubmit: { executeTask() })
                .frame(minHeight: 100)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.5)))
        }
    }
    
    // MARK: - Action Buttons
    
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
    
    // MARK: - Output Section (plain text, dynamic height)
    
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
            } else {
                ScrollView {
                    Text(outputText.isEmpty ? (isStreaming ? "..." : "") : outputText)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(minHeight: 80, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.3)))
            }
        }
    }
    
    // MARK: - Footer
    
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
    
    // MARK: - Execute Task (normal, no learning)
    
    private func executeTask() {
        guard let categoryID = selectedCategoryID,
              let category = categoryStore.categories.first(where: { $0.id == categoryID }) else { return }
        
        outputText = ""
        isStreaming = true
        
        // 翻译类别 + 学习面板已展开 → 用合并请求
        if isTranslationCategory && manager.isLearningPanelShown {
            manager.learningText = ""
            manager.isLearningStreaming = true
            executeCombinedTranslation(text: inputText, category: category)
            return
        }
        
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
    
    // MARK: - Translation with Learning (single combined request)
    
    private func executeTranslationWithLearning() {
        guard let categoryID = selectedCategoryID,
              let category = categoryStore.categories.first(where: { $0.id == categoryID }) else { return }
        
        outputText = ""
        manager.learningText = ""
        isStreaming = true
        manager.isLearningPanelShown = true
        manager.isLearningStreaming = true
        
        executeCombinedTranslation(text: inputText, category: category)
    }
    
    // MARK: - Combined Translation + Learning (single API call)
    
    private static let learnMarker = "---SNAP_LEARN---"

    /// 把单次流式返回拆成「翻译」和「学习」两部分。
    /// 不再要求严格的空行包裹，只要出现标记 `---SNAP_LEARN---` 即可拆分，
    /// 解决了之前学习面板（右侧）一直为空的问题。
    private func splitOutput(_ full: String) -> (translation: String, learning: String?) {
        if let range = full.range(of: Self.learnMarker) {
            let translation = String(full[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let learning = String(full[range.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (translation, learning)
        }
        // 还没收到完整标记：隐藏可能正在流入的部分标记（如 "---SNAP_LE"），避免闪现
        let marker = Self.learnMarker
        var translation = full
        let maxOverlap = min(marker.count, full.count)
        if maxOverlap > 0 {
            for i in stride(from: maxOverlap, through: 1, by: -1) {
                if marker.hasPrefix(String(full.suffix(i))) {
                    translation = String(full.dropLast(i))
                    break
                }
            }
        }
        return (translation.trimmingCharacters(in: .whitespacesAndNewlines), nil)
    }

    private func executeCombinedTranslation(text: String, category: Category) {
        let combinedPrompt = combinedTranslationPrompt(translatePrompt: category.systemPrompt)
        var fullOutput = ""
        
        aiService.send(
            systemPrompt: combinedPrompt,
            userMessage: text,
            onToken: { token in
                fullOutput += token
                let parts = self.splitOutput(fullOutput)
                outputText = parts.translation
                if let learning = parts.learning {
                    manager.learningText = learning
                }
            },
            onComplete: {
                isStreaming = false
                manager.isLearningStreaming = false
                let parts = self.splitOutput(fullOutput)
                outputText = parts.translation
                manager.learningText = parts.learning ?? ""
                if !outputText.isEmpty {
                    let item = HistoryItem(categoryID: category.id, categoryName: category.name, input: text, output: outputText)
                    historyStore.addItem(item)
                }
            }
        )
    }
    
    // MARK: - Combined Prompt
    
    private func combinedTranslationPrompt(translatePrompt: String) -> String {
        return """
        \(translatePrompt)

        请严格按下面两段输出，中间用单独一行的标记分隔：

        第一段：只给出最精简、直白的翻译结果本身，不要任何解释、注释、引号或前后缀。

        然后单独占一行输出这个标记：
        ---SNAP_LEARN---

        第二段（标记之后）：用简短的中文给出学习内容，严格按以下结构，不要寒暄、不要多余章节：

        ## 如何断句
        把原文按意群/从句拆成几段，每段一行：
        - `原文片段` → 对应译文（这段起什么作用，如主句、从句、状语）

        ## 重要词汇
        只挑 2-4 个关键或易错的词/短语，每个一行：
        - **词/短语**：含义，以及在本句中的用法或为什么这样译

        ## 示例
        针对上面的重点词汇或句型，给 1-2 个简短的例句（外文 + 中文翻译），帮助举一反三。

        整体保持精简，能省则省。
        """
    }
}
