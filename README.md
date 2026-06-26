# SnapAI

macOS 菜单栏 AI 快捷助手 — 翻译、润色、改写、总结，不用离开当前窗口。

## 功能特性

- **菜单栏快速访问** — 点击菜单栏图标即可使用，支持 Popover 和浮窗两种模式
- **7 个内置类别** — 常规对话、翻译、润色、改写、总结、代码注释、纠错
- **自定义类别** — 可添加自定义 Prompt 模板
- **翻译学习模式** — 翻译时自动展开学习面板，显示逐句拆分和翻译要点
- **多 Provider 支持** — DashScope (通义千问)、DeepSeek、OpenAI、Ollama (本地)
- **流式输出** — 实时显示 AI 生成内容
- **历史记录** — 自动保存最近 100 条操作记录
- **键盘快捷键** — ⌘+Enter 执行，支持 ⌘V 粘贴

## 截图

<!-- TODO: 添加截图 -->

## 安装

### 从源码构建

需要 macOS 14+ (Sonoma) 和 Xcode 15+。

```bash
git clone https://github.com/carlzhu/SnapAI.git
cd SnapAI/SnapAI
swift build -c release
```

### 安装到 Applications

```bash
cd /Users/x/Documents/dev/code/ai-suit/SnapAI
cp .build/release/SnapAI /Applications/SnapAI.app/Contents/MacOS/SnapAI
codesign -f -s - /Applications/SnapAI.app
xattr -dr com.apple.quarantine /Applications/SnapAI.app
open /Applications/SnapAI.app
```

## 配置

### API Key

首次启动时，SnapAI 会自动读取环境变量：

- `QWEN_API_KEY` — DashScope (通义千问) API Key
- `DEEPSEEK_API_KEY` — DeepSeek API Key
- `OPENAI_API_KEY` — OpenAI API Key

也可以在"偏好设置"中手动配置。

### Provider 配置

| Provider | 默认端点 | 默认模型 |
|----------|---------|---------|
| DashScope | https://dashscope.aliyuncs.com/compatible-mode/v1 | qwen3.7-max |
| DeepSeek | https://api.deepseek.com | deepseek-v4-flash |
| OpenAI | https://api.openai.com/v1 | gpt-4o-mini |
| Ollama | http://localhost:11434/v1 | qwen2.5:7b |

## 使用方法

### 基本使用

1. 点击菜单栏图标打开面板
2. 选择任务类别（默认"常规"）
3. 输入文本
4. 按 ⌘+Enter 或点击"执行"
5. 查看结果并点击"复制"

### 翻译学习模式

在"翻译"类别下：

1. 输入要翻译的文本
2. 点击标题栏的 📖 图标展开学习面板
3. 左侧显示翻译结果，右侧显示逐句拆分和翻译要点

### 浮窗模式

点击面板底部的"浮窗"按钮切换到独立窗口模式：

- 窗口始终置顶，不会消失
- 可调整大小（最小 420×400）
- 翻译时可展开学习面板（宽度自动扩展到 840px）

## 技术栈

- Swift 5.9+ / SwiftUI
- Swift Package Manager
- 依赖：[swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1
- 参考：[mac-status](https://github.com/AF-lmf/mac-status) 的菜单栏和窗口管理

## 项目结构

```
SnapAI/
├── Package.swift                    # SPM 配置
├── Sources/SnapAI/
│   ├── App/                         # 应用入口
│   ├── Models/                      # 数据模型
│   ├── Services/                    # AI 服务
│   ├── Storage/                     # 本地存储
│   ├── UI/                          # 界面组件
│   └── Utils/                       # 工具函数
└── Tests/                           # 测试
```

## 开发

```bash
# Debug 构建
cd SnapAI
swift build

# 运行
.build/debug/SnapAI

# Release 构建
swift build -c release
```

## 许可证

MIT License

## 致谢

- [mac-status](https://github.com/AF-lmf/mac-status) — 菜单栏和窗口管理参考
- [swift-markdown-ui](https://github.com/gonzalezreal/swift-markdown-ui) — Markdown 渲染
