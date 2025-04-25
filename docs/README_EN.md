# TextSage

<p align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/Icon-256.png" width="128" alt="TextSage Logo">
</p>

<p align="center">
  <strong>Select, Ask, Understand</strong><br>
  Intelligent Text Analysis & Conversation Assistant for macOS
</p>

<p align="center">
  <a href="#introduction">Introduction</a> •
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#technical-architecture">Technical Architecture</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

## Introduction

TextSage (formerly TextCraftSwift) is a macOS AI assistant designed to help you analyze and understand text from any application. Simply select text, press a hotkey, and instantly get AI insights and answers without switching contexts or copying and pasting.

Built with modern Swift and SwiftUI, TextSage provides a seamless, native experience with real-time streaming responses, conversation history, and context-aware answers powered by large language models.

## Key Features

- **Select & Ask**: Select any text in any app, press a hotkey, and ask questions about it
- **Context-Aware**: AI considers your selected text as context for more relevant answers
- **Multi-Conversation**: Support for multiple conversations with easy management
- **Streaming Output**: Real-time display of AI responses with typewriter effect
- **Elegant Interface**: Clean UI focused on content and conversation
- **Local Persistence**: Automatically saves conversation history for future reference
- **Dark Mode**: Native support for macOS dark mode
- **Global Hotkeys**: Customizable shortcuts to trigger the app from anywhere

## Installation

### Download from GitHub Releases

1. Go to the [GitHub Releases page](https://github.com/yourusername/textsage/releases)
2. Download the latest `TextSage.dmg` file
3. Open the DMG and drag TextSage to your Applications folder
4. When first running, you may need to allow the app to run in System Preferences → Security & Privacy

### Building from Source

1. Clone the repository: `git clone https://github.com/yourusername/textsage.git`
2. Open the project in Xcode
3. Build and run the app (⌘+R)

## Usage

### Basic Workflow

1. **Grant Accessibility Permissions**: On first launch, the app will request accessibility permissions (required to capture selected text)
2. **Set API Key**: Enter your API key in Settings (Ark API is supported by default)
3. **Select Text**: Select text in any application
4. **Trigger Hotkey**: Press the default hotkey (Option+Command+A)
5. **Ask**: Enter your question in the chat window that appears
6. **Get Answers**: The AI will provide answers based on your selected text and question

### Keyboard Shortcuts

- **Option+Command+A**: Trigger the main functionality (customizable in Settings)
- **Escape**: Close the current chat window
- **Command+N**: Create a new conversation
- **Command+,**: Open Settings

## Technical Architecture

TextSage is built with a modern Swift technology stack optimized for macOS:

- **SwiftUI**: For building fluid, responsive user interfaces
- **Combine**: For handling asynchronous events and data flows
- **UserDefaults & FileManager**: For local data persistence
- **URLSession**: For API communication
- **Accessibility API**: For capturing globally selected text
- **NSStatusItem**: For system status bar integration
- **Swift Concurrency**: For efficient asynchronous task handling

API Integration:
- Ark API (default, with streaming support)
- Extensible to support other LLM providers

## Roadmap

We plan to add the following features in future versions:

### Markdown Rendering (2024 Roadmap)

We're planning to add comprehensive Markdown rendering to better display structured content in AI responses:

#### Phase 1: Basic Markdown (2024 Q2)
- Integration with lightweight Markdown parsers (like [Down](https://github.com/johnxnguyen/Down) or [Splash](https://github.com/JohnSundell/Splash))
- Support for basic syntax: headings, bold, italic, lists, links
- Dark/light theme adaptive styling

#### Phase 2: Code Highlighting (2024 Q2-Q3)
- Multi-language code block syntax highlighting
- Code block copy functionality
- Line numbering

#### Phase 3: Advanced Formatting (2024 Q3)
- Table rendering
- Image embedding
- Block quote styling enhancements
- Interactive checkbox support

#### Phase 4: Math Formulas (2024 Q4)
- LaTeX rendering engine integration
- Support for inline and block-level equations

### Other Planned Features

- **Multi-Model Support**: Integration with more LLM options
- **Image Understanding**: Support for selecting and analyzing images
- **Export Functionality**: Export conversations as Markdown, PDF, or plain text
- **Local Vector Database**: Document indexing and semantic search
- **Plugin System**: User-extensible functionality
- **Sync**: Conversation history synchronization via iCloud

## Contributing

We welcome contributions of all forms, including feature requests, bug reports, and code contributions.

### Submitting Issues

1. Use the issue templates to report bugs or request features
2. Provide detailed reproduction steps and environment information
3. Include screenshots or videos if possible

### Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Coding Standards

- Follow Swift style guidelines
- Add appropriate comments and documentation
- Write unit tests where applicable

## License

TextSage is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

---

<p align="center">
  &copy; 2024 TextSage. All rights reserved.
</p> 