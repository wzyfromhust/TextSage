# TextSage

<p align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/Icon-256.png" width="128" alt="TextSage Logo">
</p>

<p align="center">
  <strong>AI-Powered Text Analysis & Conversation Assistant for macOS</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#license">License</a> •
  <a href="#chinese">中文说明</a>
</p>

## Features

- **Select & Ask**: Highlight any text, press a hotkey, get AI insights instantly
- **Contextual Intelligence**: AI responses consider your selected text
- **Streaming Output**: Real-time AI responses with typewriter effect
- **Multiple Conversations**: Easily manage different conversation topics
- **Persistence**: Automatic saving of conversation history
- **Dark Mode Support**: Native macOS dark mode compatibility
- **Global Hotkeys**: Customizable shortcuts for anywhere access

## Installation

1. Download from [GitHub Releases](https://github.com/yourusername/textsage/releases)
2. Or build manually: `git clone https://github.com/yourusername/textsage.git`

## Usage

1. Select text in any application
2. Press the hotkey (Option+Command+A by default)
3. Ask questions in the popup window
4. Get AI-generated insights based on your selected text

## Roadmap

- **Markdown Rendering**: Full Markdown support for better response formatting
- **Code Highlighting**: Syntax highlighting for code blocks
- **Multi-Model Support**: Integration with more LLM providers
- **Export Options**: Export conversations to Markdown/PDF/Text
- **iCloud Sync**: Sync conversations across devices

## License

[MIT License](LICENSE)

---

<a name="chinese"></a>

# TextSage（文本贤者）

<p align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/Icon-256.png" width="128" alt="TextSage Logo">
</p>

<p align="center">
  <strong>智能文本分析与对话助手</strong><br>
  选中文本，即刻获得AI洞察
</p>

<p align="center">
  <a href="#主要功能">主要功能</a> •
  <a href="#安装说明">安装说明</a> •
  <a href="#使用方法">使用方法</a> •
  <a href="#技术架构">技术架构</a> •
  <a href="#未来计划">未来计划</a> •
  <a href="#贡献指南">贡献指南</a> •
  <a href="#许可证">许可证</a>
</p>

## 项目介绍

TextSage（前身为TextCraftSwift）是一款专为macOS设计的AI辅助工具，让您能够轻松地对选中的文本进行提问和分析。无论是阅读文档、研究论文，还是浏览网页内容，只需选中文本，按下快捷键，即可立即获取AI的见解和解答。

TextSage利用先进的大语言模型技术，提供上下文感知的回答，帮助您更深入地理解和探索各种文本内容。无需复制粘贴，无需切换应用，即选即问，高效便捷。

## 主要功能

- **即选即问**：选中任何文本，按下快捷键，立即提问
- **智能上下文**：AI回答会考虑您选中的文本内容作为上下文
- **多会话管理**：支持多个对话，轻松切换和管理不同主题
- **流式输出**：实时展示AI回复，带有打字机效果
- **简洁界面**：优雅的用户界面，专注于内容与对话
- **本地持久化**：自动保存对话历史，随时查阅
- **深色模式**：原生支持macOS深色模式，保护您的眼睛
- **全局快捷键**：自定义快捷键，随时随地触发

## 安装说明

### 从GitHub发布页面下载

1. 前往[GitHub发布页面](https://github.com/yourusername/textsage/releases)
2. 下载最新的`TextSage.dmg`文件
3. 打开DMG文件并将TextSage拖到Applications文件夹
4. 首次运行时可能需要在系统偏好设置→安全性与隐私中允许应用运行

### 手动构建

1. 克隆仓库：`git clone https://github.com/yourusername/textsage.git`
2. 使用Xcode打开项目
3. 在Xcode中构建和运行应用（⌘+R）

## 使用方法

### 基本使用流程

1. **授权辅助功能**：首次启动时，应用会请求辅助功能权限，这是捕获选中文本所必需的
2. **设置API密钥**：在设置中输入您的API密钥（支持Ark API）
3. **选中文本**：在任何应用中选中一段文本
4. **触发快捷键**：按下默认快捷键（Option+Command+A）
5. **提问**：在打开的对话窗口中提问
6. **获取回答**：AI将基于选中文本和您的问题提供回答

### 快捷键

- **Option+Command+A**：触发主要功能（可在设置中自定义）
- **Escape**：关闭当前对话窗口
- **Command+N**：创建新对话
- **Command+,**：打开设置

## 技术架构

TextSage采用现代Swift技术栈开发，专为macOS平台优化：

- **SwiftUI**：构建流畅、响应式的用户界面
- **Combine**：处理异步事件和数据流
- **UserDefaults & FileManager**：本地数据持久化
- **URLSession**：API通信
- **Accessibility API**：捕获全局选中文本
- **NSStatusItem**：系统状态栏集成
- **Swift Concurrency**：高效的异步任务处理

API集成：
- Ark API（默认，支持流式输出）
- 可扩展支持其他LLM提供商

## 未来计划

我们计划在未来版本中添加以下功能：

### Markdown渲染（2024路线图）

我们计划为TextSage添加完整的Markdown渲染功能，以更好地展示AI回复中的结构化内容：

#### 第一阶段：基础Markdown (2024 Q2)
- 集成轻量级Markdown解析器（如[Down](https://github.com/johnxnguyen/Down)或[Splash](https://github.com/JohnSundell/Splash)）
- 实现基本语法：标题、加粗、斜体、列表、链接
- 支持暗色/亮色主题自适应样式

#### 第二阶段：代码高亮 (2024 Q2-Q3)
- 添加多语言代码块语法高亮
- 代码块复制功能
- 行号显示

#### 第三阶段：高级格式 (2024 Q3)
- 表格渲染
- 图片嵌入
- 引用块样式优化
- 复选框交互支持

#### 第四阶段：数学公式 (2024 Q4)
- 集成LaTeX渲染引擎
- 支持行内和块级数学公式

### 其他计划功能

- **多模型支持**：集成更多大语言模型选项
- **图像理解**：支持选中图像进行分析和提问
- **导出功能**：支持导出对话为Markdown、PDF或纯文本
- **本地向量数据库**：添加文档索引和语义搜索
- **插件系统**：支持用户扩展功能
- **同步功能**：通过iCloud同步对话历史

## 贡献指南

我们欢迎各种形式的贡献，包括功能请求、bug报告和代码贡献。

### 提交Issue

1. 使用Issue模板报告bug或请求新功能
2. 提供详细的复现步骤和环境信息
3. 如可能，附上截图或视频

### 代码贡献

1. Fork仓库
2. 创建功能分支(`git checkout -b feature/amazing-feature`)
3. 提交更改(`git commit -m 'Add some amazing feature'`)
4. 推送到分支(`git push origin feature/amazing-feature`)
5. 打开Pull Request

### 编码规范

- 遵循Swift风格指南
- 添加适当的注释和文档
- 编写单元测试（如适用）

## 许可证

TextSage采用MIT许可证 - 详情请查看[LICENSE](LICENSE)文件

---

<p align="center">
  &copy; 2024 TextSage. 保留所有权利。
</p> 