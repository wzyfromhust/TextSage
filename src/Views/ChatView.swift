import SwiftUI
import Foundation

// 会话数据模型
struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    var timestamp: Date
    
    init(id: UUID = UUID(), title: String = "新对话", messages: [Message] = [], timestamp: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.timestamp = timestamp
    }
    
    // 更新标题摘要 (自动从第一条信息生成)
    mutating func updateTitle() {
        if let firstUserMessage = messages.first(where: { $0.isUser }), !firstUserMessage.content.isEmpty {
            // 截取用户第一条消息作为对话标题
            let content = firstUserMessage.content
            self.title = content.count > 20 ? content.prefix(20) + "..." : content
        }
    }
}

// 消息结构体
struct Message: Identifiable, Codable {
    let id: UUID
    var content: String
    let isUser: Bool
    let timestamp: Date
    var status: MessageStatus = .completed
    
    init(id: UUID = UUID(), content: String, isUser: Bool, timestamp: Date = Date(), status: MessageStatus = .completed) {
        self.id = id
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
        self.status = status
    }
}

// 消息状态枚举
enum MessageStatus: String, Codable {
    case loading   // 加载中
    case streaming // 正在流式接收
    case completed // 已完成
    case error     // 出错
}

// 会话管理器 - 改为应用级单例模式
class ConversationManager: ObservableObject {
    // 单例实例
    static let shared = ConversationManager()
    
    @Published var conversations: [Conversation] = []
    @Published var currentConversationID: UUID?
    
    var historyLimit: Int = 50
    
    // 存储和加载的键
    private let storageKey = "textcraft_conversations"
    private let storageKeyFilePath = "textcraft_conversations_filePath"
    
    // 日志文件路径
    private let logFileURL: URL = {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("textcraft_log.txt")
    }()
    
    // 私有初始化方法，强制使用单例
    private init(historyLimit: Int = 50) {
        self.historyLimit = historyLimit
        logMessage("初始化ConversationManager单例")
        
        // 设置应用生命周期通知
        setupNotifications()
        
        // 加载对话
        loadConversations()
    }
    
    // 日志记录功能
    func logMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logEntry = "[\(timestamp)] \(message)\n"
        
        print(logEntry)
        
        // 将日志写入文件
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("无法写入日志文件: \(error.localizedDescription)")
        }
    }
    
    // 获取当前对话
    var currentConversation: Conversation? {
        get {
            if let id = currentConversationID {
                return conversations.first { $0.id == id }
            }
            return nil
        }
    }
    
    // 创建新对话
    func createNewConversation() -> UUID {
        let newConversation = Conversation()
        conversations.insert(newConversation, at: 0)
        currentConversationID = newConversation.id
        logMessage("创建新对话: \(newConversation.id)")
        saveConversations()
        return newConversation.id
    }
    
    // 切换到指定对话
    func switchToConversation(id: UUID) {
        currentConversationID = id
        logMessage("切换到对话: \(id)")
    }
    
    // 添加消息到当前对话
    func addMessage(_ message: Message) {
        guard let currentID = currentConversationID,
              let index = conversations.firstIndex(where: { $0.id == currentID }) else {
            // 如果没有当前对话，创建新对话
            logMessage("没有当前对话，创建新对话并添加消息")
            _ = createNewConversation()
            addMessage(message)
            return
        }
        
        // 添加消息
        conversations[index].messages.append(message)
        logMessage("添加消息到对话 \(currentID)：\(message.isUser ? "用户" : "AI")")
        
        // 如果是用户消息且只有一条，更新标题
        if message.isUser && conversations[index].messages.filter({ $0.isUser }).count == 1 {
            conversations[index].updateTitle()
            logMessage("更新对话标题为：\(conversations[index].title)")
        }
        
        // 更新时间戳并移动到列表最前
        conversations[index].timestamp = Date()
        if index != 0 {
            let conversation = conversations.remove(at: index)
            conversations.insert(conversation, at: 0)
            logMessage("将对话移到顶部")
        }
        
        saveConversations()
    }
    
    // 删除对话
    func deleteConversation(id: UUID) {
        conversations.removeAll { $0.id == id }
        logMessage("删除对话：\(id)")
        
        // 如果删除的是当前对话，切换到第一个对话或创建新对话
        if currentConversationID == id {
            if let firstID = conversations.first?.id {
                currentConversationID = firstID
                logMessage("切换到第一个对话：\(firstID)")
            } else {
                _ = createNewConversation()
                logMessage("创建新对话替代被删除的当前对话")
            }
        }
        
        saveConversations()
    }
    
    // 清空当前对话
    func clearCurrentConversation() {
        guard let currentID = currentConversationID,
              let index = conversations.firstIndex(where: { $0.id == currentID }) else {
            logMessage("找不到当前对话，无法清空")
            return
        }
        
        conversations[index].messages.removeAll()
        logMessage("清空对话：\(currentID)")
        saveConversations()
    }
    
    // 持久化保存对话
    public func saveConversations() {
        // 限制保存的历史记录数量
        if conversations.count > historyLimit {
            let removed = conversations.count - historyLimit
            conversations = Array(conversations.prefix(historyLimit))
            logMessage("限制历史记录，移除了\(removed)条旧对话")
        }
        
        // 1. 编码数据到UserDefaults（作为备份）
        do {
            let encoded = try JSONEncoder().encode(conversations)
            UserDefaults.standard.set(encoded, forKey: storageKey)
            logMessage("成功保存对话到UserDefaults")
        } catch {
            logMessage("保存对话到UserDefaults失败: \(error.localizedDescription)")
        }
        
        // 2. 编码数据到本地文件（主要存储）
        saveConversationsToFile()
    }
    
    // 保存到文件
    private func saveConversationsToFile() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(conversations)
            
            // 获取文件路径
            let fileURL = getSaveFileURL()
            
            // 确保目录存在
            let directoryURL = fileURL.deletingLastPathComponent()
            
            if !FileManager.default.fileExists(atPath: directoryURL.path) {
                try FileManager.default.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true
                )
                logMessage("创建目录：\(directoryURL.path)")
            }
            
            // 保存文件
            try data.write(to: fileURL, options: .atomic)
            logMessage("成功保存对话到文件：\(fileURL.path)")
            
            // 存储文件路径到UserDefaults
            UserDefaults.standard.set(fileURL.path, forKey: storageKeyFilePath)
        } catch {
            logMessage("保存对话到文件失败: \(error.localizedDescription)")
            // 显示错误弹窗
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "保存对话失败"
                alert.informativeText = "无法保存对话数据：\(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        }
    }
    
    // 加载保存的对话
    private func loadConversations() {
        // 首先尝试从文件加载
        if !loadConversationsFromFile() {
            // 如果文件加载失败，尝试从UserDefaults加载
            logMessage("从文件加载失败，尝试从UserDefaults加载")
            loadConversationsFromUserDefaults()
        }
        
        // 如果仍然没有对话，创建一个新对话
        if conversations.isEmpty {
            logMessage("没有找到保存的对话，创建新对话")
            _ = createNewConversation()
        } else {
            logMessage("成功加载了\(conversations.count)个对话")
        }
    }
    
    // 从文件加载
    private func loadConversationsFromFile() -> Bool {
        // 获取保存的文件路径
        guard let filePath = UserDefaults.standard.string(forKey: storageKeyFilePath) else {
            logMessage("找不到对话文件路径")
            return false
        }
        
        // 创建文件URL - 使用fileURLWithPath来确保路径正确处理
        let fileURL = URL(fileURLWithPath: filePath)
        logMessage("尝试从文件加载对话：\(fileURL.path)")
        
        do {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                logMessage("对话文件不存在：\(fileURL.path)")
                return false
            }
            
            // 读取文件数据
            let data = try Data(contentsOf: fileURL)
            logMessage("成功读取文件数据，大小：\(data.count)字节")
            
            // 解码数据
            conversations = try JSONDecoder().decode([Conversation].self, from: data)
            logMessage("从文件成功加载了\(conversations.count)个对话")
            
            // 设置当前对话
            if let firstID = conversations.first?.id {
                currentConversationID = firstID
                logMessage("设置当前对话为：\(firstID)")
            }
            
            return true
        } catch {
            logMessage("从文件加载对话失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // 从UserDefaults加载
    private func loadConversationsFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
            print("从UserDefaults加载了\(conversations.count)个对话")
            
            // 如果有对话，设置第一个为当前对话
            if let firstID = conversations.first?.id {
                currentConversationID = firstID
            }
        } else {
            print("从UserDefaults加载对话失败或没有保存的对话")
        }
    }
    
    // 获取保存文件的URL
    private func getSaveFileURL() -> URL {
        // 使用应用程序支持目录
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportDirectory.appendingPathComponent("TextCraft")
        let fileURL = appDirectory.appendingPathComponent("conversations.json")
        
        // 记录路径
        logMessage("使用保存路径：\(fileURL.path)")
        
        return fileURL
    }
    
    // 设置应用程序生命周期通知
    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveBeforeExit),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // 当进入后台时保存
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveBeforeExit),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
        
        logMessage("已设置应用生命周期通知监听")
    }
    
    // 保存所有对话到文件
    @objc func saveBeforeExit() {
        logMessage("收到应用程序生命周期通知，执行保存...")
        saveConversations()
    }
}

// MARK: - AI服务相关
// OpenAI聊天完成请求结构
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let stream: Bool?
}

// 聊天消息结构
struct ChatMessage: Codable {
    let role: String
    let content: String
    
    // 添加字典转换属性
    var dictionary: [String: String] {
        return [
            "role": role,
            "content": content
        ]
    }
}

// 聊天完成响应结构
struct ChatCompletionResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Decodable {
        let index: Int
        let message: ChatMessage
        let finish_reason: String?
    }
}

// 流式输出响应结构 (SSE)
struct ChatCompletionChunk: Decodable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChunkChoice]
    
    struct ChunkChoice: Decodable {
        let index: Int
        let delta: ChunkDelta
        let finish_reason: String?
        
        struct ChunkDelta: Decodable {
            let content: String?
            let role: String?
        }
    }
}

// AI服务类 - 负责与AI API通信
class AIService {
    // 单例模式
    static let shared = AIService()
    
    // 默认模型参数
    var apiKey: String = UserDefaults.standard.string(forKey: "apiKey") ?? "ffbf403d-6005-4c80-9d3d-54d006fa77c4"
    var modelId: String = UserDefaults.standard.string(forKey: "modelId") ?? "ep-20250425224304-5j9mj"
    var useStreamingOutput: Bool = UserDefaults.standard.bool(forKey: "useStreamOutput")
    
    // API基础URL
    public let baseURL = "https://ark.cn-beijing.volces.com/api/v3"
    
    // 私有初始化方法
    private init() {
        // 从UserDefaults加载设置
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? "ffbf403d-6005-4c80-9d3d-54d006fa77c4"
        self.modelId = UserDefaults.standard.string(forKey: "modelId") ?? "ep-20250425224304-5j9mj"
        self.useStreamingOutput = UserDefaults.standard.bool(forKey: "useStreamOutput")
        
        // 日志记录
        ConversationManager.shared.logMessage("初始化AIService单例，模型ID: \(modelId), 流式输出: \(useStreamingOutput)")
    }
    
    // 简化错误类型
    enum AIServiceError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case serverError(Int, String?)
        case decodingError(Error, String?)
        case noMessageInResponse
        case streamError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效的API URL"
            case .networkError(let error): return "网络错误: \(error.localizedDescription)"
            case .serverError(let code, _): return "服务器错误 (状态码: \(code))"
            case .decodingError(let error, _): return "解码错误: \(error.localizedDescription)"
            case .noMessageInResponse: return "响应中没有消息"
            case .streamError(let message): return "流式输出错误: \(message)"
            }
        }
        
        var failureReason: String? {
            switch self {
            case .serverError(_, let body): return body
            case .decodingError(_, let body): return body
            default: return nil
            }
        }
    }
    
    // 发送聊天请求 - 非流式
    func sendChatRequest(messages: [ChatMessage], completion: @escaping (Result<String, Error>) -> Void) {
        // 使用正确的URL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        // 2. 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 3. 添加API密钥 - 使用测试中成功的Authorization头部
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 4. 创建请求体 - 使用与测试文件相同的结构
        let requestBody = ChatCompletionRequest(
            model: modelId,
            messages: messages,
            stream: false
        )
        
        // 5. 编码请求体
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
            ConversationManager.shared.logMessage("API请求体: \(String(data: request.httpBody!, encoding: .utf8) ?? "无法读取")")
        } catch {
            completion(.failure(AIServiceError.decodingError(error, nil)))
            return
        }
        
        // 6. 发送请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            // 处理网络错误
            if let error = error {
                completion(.failure(AIServiceError.networkError(error)))
                return
            }
            
            // 记录响应信息
            let responseString = data.flatMap { String(data: $0, encoding: .utf8) }
            ConversationManager.shared.logMessage("API响应: \(responseString ?? "无响应体")")
            
            // 处理HTTP错误
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(AIServiceError.serverError(0, "无效的HTTP响应")))
                return
            }
            
            ConversationManager.shared.logMessage("HTTP状态码: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(AIServiceError.serverError(httpResponse.statusCode, responseString)))
                return
            }
            
            // 确保有响应数据
            guard let data = data else {
                completion(.failure(AIServiceError.serverError(httpResponse.statusCode, "没有响应数据")))
                return
            }
            
            // 解析响应
            do {
                let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
                
                if let message = response.choices.first?.message {
                    DispatchQueue.main.async {
                        completion(.success(message.content))
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(AIServiceError.noMessageInResponse))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.decodingError(error, responseString)))
                }
            }
        }.resume()
    }
    
    // 流式发送聊天请求
    func sendChatRequestStream(messages: [ChatMessage], onChunk: @escaping (String) -> Void, onComplete: @escaping (Result<String, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            onComplete(.failure(NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API密钥为空"])))
            return
        }
        
        // 使用正确的URL
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            onComplete(.failure(AIServiceError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // 创建请求体 - 使用与测试文件相同的结构
        let requestBody = ChatCompletionRequest(
            model: modelId,
            messages: messages,
            stream: true
        )
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
            
            // 记录请求数据
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                ConversationManager.shared.logMessage("流式API请求: \(bodyString)")
            }
        } catch {
            onComplete(.failure(error))
            return
        }
        
        // 创建会话任务
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                ConversationManager.shared.logMessage("流式请求错误: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    onComplete(.failure(error))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                ConversationManager.shared.logMessage("无效的HTTP响应")
                DispatchQueue.main.async {
                    onComplete(.failure(NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])))
                }
                return
            }
            
            // 记录HTTP状态码
            ConversationManager.shared.logMessage("API响应状态码: \(httpResponse.statusCode)")
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errorMessage: String
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    errorMessage = "HTTP状态码 \(httpResponse.statusCode): \(responseString)"
                    ConversationManager.shared.logMessage("API错误响应: \(responseString)")
                } else {
                    errorMessage = "HTTP状态码 \(httpResponse.statusCode)"
                }
                
                DispatchQueue.main.async {
                    onComplete(.failure(NSError(domain: "AIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                }
                return
            }
            
            guard let data = data else {
                ConversationManager.shared.logMessage("没有返回数据")
                DispatchQueue.main.async {
                    onComplete(.failure(NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "没有返回数据"])))
                }
                return
            }
            
            // 将数据转换为字符串
            guard let stringData = String(data: data, encoding: .utf8) else {
                ConversationManager.shared.logMessage("无法解码数据")
                DispatchQueue.main.async {
                    onComplete(.failure(NSError(domain: "AIService", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解码数据"])))
                }
                return
            }
            
            // 处理流式数据
            var fullResponse = ""
            let lines = stringData.components(separatedBy: "\n")
            
            for line in lines {
                if line.hasPrefix("data: ") {
                    let dataContent = line.dropFirst(6)  // 删除"data: "前缀
                    
                    // 忽略 [DONE] 消息
                    if dataContent == "[DONE]" {
                        ConversationManager.shared.logMessage("流式响应结束")
                        continue
                    }
                    
                    // 解析JSON数据
                    do {
                        if let data = dataContent.data(using: .utf8),
                           let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let firstChoice = choices.first {
                            
                            // 处理delta或消息内容
                            if let delta = firstChoice["delta"] as? [String: Any],
                               let content = delta["content"] as? String {
                                
                                // 追加到完整响应
                                fullResponse += content
                                
                                // 发送块到回调
                                DispatchQueue.main.async {
                                    onChunk(content)
                                }
                            } else if let message = firstChoice["message"] as? [String: Any],
                                      let content = message["content"] as? String {
                                
                                // 非流式响应格式（完整消息）
                                fullResponse = content
                                
                                // 发送完整消息
                                DispatchQueue.main.async {
                                    onChunk(content)
                                }
                            }
                        }
                    } catch {
                        ConversationManager.shared.logMessage("解析SSE数据失败: \(error.localizedDescription)")
                    }
                }
            }
            
            // 流处理完成，返回完整响应
            ConversationManager.shared.logMessage("流式请求完成，总计接收: \(fullResponse.count)字符")
            DispatchQueue.main.async {
                onComplete(.success(fullResponse))
            }
        }
        
        task.resume()
    }
    
    // 测试API连接
    func testAPIConnection(completion: @escaping (Bool, String) -> Void) {
        let testMessage = ChatMessage(role: "user", content: "测试连接，请回复一句简短的话")
        
        sendChatRequest(messages: [testMessage]) { result in
            switch result {
            case .success(let response):
                completion(true, "API连接成功: \(response)")
            case .failure(let error):
                completion(false, "API连接失败: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - 应用颜色主题
struct AppColors {
    static let primary = Color(red: 0.2, green: 0.5, blue: 0.9)
    static let secondary = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let userBubble = Color(red: 0.2, green: 0.5, blue: 0.9)
    static let aiBubble = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let bgDark = Color(white: 0.15)
    static let bgLight = Color.white
    static let shadow = Color.black.opacity(0.15)
    static let errorRed = Color.red.opacity(0.8)
}

// 聊天视图
struct ChatView: View {
    // 使用共享的单例
    @ObservedObject var conversationManager = ConversationManager.shared
    @State private var newMessage: String = ""
    @State private var isProcessing: Bool = false
    @State private var selectedText: String = ""
    @State private var showingSelectedText: Bool = false
    @State private var showingSidebar: Bool = false
    @State private var sidebarOffset: CGFloat = -300
    
    // 流式输出相关
    @State private var streamedResponse: String = ""
    @State private var isStreamingResponse: Bool = false
    
    // 弹窗相关状态
    @State private var showFullTextAlert: Bool = false
    @State private var fullTextToShow: String = ""
    
    // 环境变量获取色彩方案
    @Environment(\.colorScheme) var colorScheme
    
    // 从 AppStorage 获取用户设置
    @AppStorage("fontSize") private var fontSize: Double = 14.0
    @AppStorage("maxHistoryItems") private var maxHistoryItems: Int = 50
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 280.0
    @AppStorage("useStreamOutput") private var useStreamOutput: Bool = true
    
    // 背景颜色
    private var backgroundColor: Color {
        colorScheme == .dark ? AppColors.bgDark : AppColors.bgLight
    }
    
    var body: some View {
        ZStack {
            // 主聊天区域
            GeometryReader { geometry in
                chatArea(geometry: geometry)
            }
            
            // 半透明背景遮罩 - 当侧边栏显示时
            if showingSidebar {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .opacity(showingSidebar ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: showingSidebar)
                    .onTapGesture {
                        closeSidebar()
                    }
            }
            
            // 侧边栏 - 浮动面板
            GeometryReader { geometry in
                sidebarView(geometry: geometry)
                    .frame(width: min(sidebarWidth, geometry.size.width * 0.85))
                    .background(backgroundColor)
                    .cornerRadius(12, corners: [.topRight, .bottomRight])
                    .shadow(color: AppColors.shadow, radius: 10, x: 5, y: 0)
                    .offset(x: showingSidebar ? 0 : -sidebarWidth)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingSidebar)
                    .edgesIgnoringSafeArea(.vertical)
                    .zIndex(1)
            }
        }
        .onAppear {
            // 从全局状态获取选中文本
            updateSelectedTextFromAppState()
            
            // 注册选中文本变化的通知
            NotificationCenter.default.addObserver(
                forName: .selectedTextDidChange,
                object: nil,
                queue: .main
            ) { notification in
                if let text = notification.userInfo?["text"] as? String {
                    updateSelectedText(text)
                }
            }
            
            // 更新历史记录限制
            conversationManager.historyLimit = maxHistoryItems
            
            // 如果有选中文本，自动展开文本区域
            if !selectedText.isEmpty {
                showingSelectedText = true
                
                // 如果这是一个新会话，先创建欢迎消息
                if conversationManager.currentConversation?.messages.isEmpty ?? true {
                    // 使用短暂延迟后添加欢迎消息，以便UI先加载完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let welcomeMessage = Message(
                            content: "你好！我是你的AI助手。我看到你选择了一段文本，有什么问题想问我吗？",
                            isUser: false
                        )
                        conversationManager.addMessage(welcomeMessage)
                    }
                }
            }
            
            // 确保useStreamOutput设置正确保存
            UserDefaults.standard.set(useStreamOutput, forKey: "useStreamOutput")
            
            print("当前流式输出设置: \(useStreamOutput ? "开启" : "关闭")")
        }
        .onDisappear {
            // 移除通知观察者
            NotificationCenter.default.removeObserver(self, name: .selectedTextDidChange, object: nil)
        }
        // 完整文本查看弹窗
        .alert(isPresented: $showFullTextAlert) {
            Alert(
                title: Text("选中的文本"),
                message: Text(fullTextToShow),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    // 从AppState获取选中文本
    private func updateSelectedTextFromAppState() {
        let text = AppState.shared.selectedText
        updateSelectedText(text)
    }
    
    // 更新选中文本并处理相关状态
    private func updateSelectedText(_ text: String) {
        // 只有当文本实际变化时才更新，以避免不必要的UI刷新
        if self.selectedText != text {
            self.selectedText = text
            
            // 当文本为空时，直接隐藏
            if text.isEmpty {
                self.showingSelectedText = false
            } else {
                // 当有文本时，显示
                self.showingSelectedText = true
            }
            
            print("📝 ChatView: 选中文本已更新 [\(text.count) 字符]")
        } else if text.isEmpty && self.showingSelectedText {
            // 确保当文本为空时始终隐藏
            self.showingSelectedText = false
        }
    }
    
    private func openSidebar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingSidebar = true
        }
    }
    
    private func closeSidebar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showingSidebar = false
        }
    }
    
    // 侧边栏视图
    @ViewBuilder
    private func sidebarView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // 边栏头部 - 标题和关闭按钮
            HStack {
                Text("对话列表")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: closeSidebar) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                        .font(.system(size: 14, weight: .medium))
                        .padding(6)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(backgroundColor)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            
            // 新对话按钮
            Button(action: {
                _ = conversationManager.createNewConversation()
                closeSidebar()
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppColors.primary)
                    Text("新对话")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // 对话列表
            SidebarConversationsList(
                conversations: conversationManager.conversations,
                currentID: conversationManager.currentConversationID,
                onSelect: { id in
                    conversationManager.switchToConversation(id: id)
                    if geometry.size.width < 600 {
                        closeSidebar()
                    }
                },
                onDelete: { id in
                    conversationManager.deleteConversation(id: id)
                }
            )
        }
    }
    
    // 聊天区域视图
    @ViewBuilder
    private func chatArea(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                // 侧边栏按钮
                Button(action: {
                    if showingSidebar {
                        closeSidebar()
                    } else {
                        openSidebar()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(AppColors.primary)
                        Text(conversationManager.currentConversation?.title ?? "新对话")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.05))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            
            // 消息列表
            ScrollViewReader { scrollView in
                ScrollView {
                    if let conversation = conversationManager.currentConversation {
                        LazyVStack(spacing: 16) {
                            ForEach(conversation.messages) { message in
                                MessageBubble(message: message)
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.9)), removal: .opacity))
                                    .id(message.id) // 确保ID正确设置
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .animation(.spring(), value: conversation.messages.count)
                    } else {
                        // 如果没有当前对话显示空状态
                        VStack(spacing: 20) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("开始新的对话")
                                .font(.title3)
                                .foregroundColor(.gray)
                            
                            Button("新对话") {
                                _ = conversationManager.createNewConversation()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .onChange(of: conversationManager.currentConversation?.messages.count) { oldValue, newValue in
                    DispatchQueue.main.async {
                        if let conversation = conversationManager.currentConversation,
                           let lastMessage = conversation.messages.last {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(colorScheme == .dark ? Color.black.opacity(0.1) : Color(NSColor.textBackgroundColor))
            }
            
            // 输入区域 - 包含上下文和输入框
            VStack(spacing: 12) {
                // 选中的文本直接显示（无需点击）
                if !selectedText.isEmpty && showingSelectedText {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 4) {
                            Image(systemName: "text.quote")
                                .font(.caption)
                                .foregroundColor(AppColors.primary)
                            
                            Text("已选中的文本")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            // 添加关闭按钮
                            Button(action: {
                                showingSelectedText = false
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Text(selectedText.count > 100 ? String(selectedText.prefix(100)) + "..." : selectedText)
                            .font(.callout)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    .onTapGesture {
                        // 恢复点击显示完整文本功能
                        fullTextToShow = selectedText
                        showFullTextAlert = true
                    }
                }
                
                // 输入框部分
                HStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        if newMessage.isEmpty {
                            Text(!selectedText.isEmpty ? "对选中的文本提问..." : "请输入消息...")
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.leading, 16)
                                .padding(.vertical, 8)
                        }
                        
                        HStack {
                            TextField("", text: $newMessage)
                                .disabled(isProcessing)
                                .font(.system(size: CGFloat(fontSize)))
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            
                            Spacer()
                            
                            // 发送按钮
                            if !newMessage.isEmpty {
                                Button(action: sendMessage) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppColors.primary)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .disabled(isProcessing)
                                .padding(.trailing, 12)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .frame(height: 40)
                    .background(
                        Capsule()
                            .fill(colorScheme == .dark ? Color.black.opacity(0.3) : Color.gray.opacity(0.05))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    
                    // 悬浮发送按钮 - 只有在输入为空或处理中时显示
                    if newMessage.isEmpty {
                        Button(action: sendMessage) {
                            ZStack {
                                Circle()
                                    .fill(isProcessing ? Color.gray.opacity(0.3) : AppColors.primary)
                                    .frame(width: 40, height: 40)
                                
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    // 将麦克风图标改为发送图标
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isProcessing || (selectedText.isEmpty && newMessage.isEmpty))
                        .animation(.spring(), value: isProcessing)
                        .shadow(color: AppColors.shadow, radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: -1)
            )
        }
    }
    
    // MARK: - 发送消息
    func sendMessage() {
        // 如果没有输入，不发送消息
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedText.isEmpty else {
            return
        }
        
        // 1. 保存当前状态并清空输入框
        let userMessage = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentSelectedText = selectedText // 保存当前选中的文本
        let isShowingSelectedText = showingSelectedText // 保存当前显示状态
        
        newMessage = ""
        isProcessing = true
        
        // 2. 显示用户消息，如果有选中文本则添加引用
        var userContent = userMessage
        if !currentSelectedText.isEmpty && isShowingSelectedText {
            userContent = "参考如下内容：\n\"\(currentSelectedText)\"\n\n\(userMessage)"
        }
        let message = Message(content: userContent, isUser: true)
        conversationManager.addMessage(message)
        
        // 发送消息后隐藏已选中的文本
        selectedText = ""
        showingSelectedText = false
        
        // 3. 准备要发送给AI API的消息列表
        var messagesForAPI: [ChatMessage] = [
            ChatMessage(role: "system", content: "你是一个有帮助的AI助手，擅长回答用户问题。")
        ]
        
        // 添加上下文（如果有）
        if !currentSelectedText.isEmpty && isShowingSelectedText {
            messagesForAPI.append(ChatMessage(role: "system", content: "以下是用户提供的上下文信息：\n\n\(currentSelectedText)"))
        }
        
        // 4. 添加用户消息
        messagesForAPI.append(ChatMessage(role: "user", content: userMessage))
        
        // 5. 发送请求到AI服务
        AIService.shared.useStreamingOutput = UserDefaults.standard.bool(forKey: "useStreamOutput")
        
        // 准备AI消息响应
        let aiResponseContent = ""
        let aiMessage = Message(content: aiResponseContent, isUser: false, status: .loading)
        conversationManager.addMessage(aiMessage)
        
        if AIService.shared.useStreamingOutput {
            // 使用流式API
            AIService.shared.sendChatRequestStream(messages: messagesForAPI, onChunk: { chunk in
                // 更新UI上的消息
                if let index = conversationManager.currentConversation?.messages.firstIndex(where: { $0.id == aiMessage.id }) {
                    conversationManager.conversations[0].messages[index].content += chunk
                    conversationManager.conversations[0].messages[index].status = .streaming
                }
            }, onComplete: { result in
                switch result {
                case .success(_):
                    // 更新最终状态
                    if let index = conversationManager.currentConversation?.messages.firstIndex(where: { $0.id == aiMessage.id }) {
                        conversationManager.conversations[0].messages[index].status = .completed
                    }
                    conversationManager.saveConversations()
                    
                case .failure(let error):
                    // 显示错误
                    if let index = conversationManager.currentConversation?.messages.firstIndex(where: { $0.id == aiMessage.id }) {
                        conversationManager.conversations[0].messages[index].content = "获取AI回复失败: \(error.localizedDescription)"
                        conversationManager.conversations[0].messages[index].status = .error
                    }
                }
                
                isProcessing = false
            })
        } else {
            // 使用非流式API
            AIService.shared.sendChatRequest(messages: messagesForAPI) { result in
                switch result {
                case .success(let content):
                    // 更新消息内容和状态
                    if let index = conversationManager.currentConversation?.messages.firstIndex(where: { $0.id == aiMessage.id }) {
                        conversationManager.conversations[0].messages[index].content = content
                        conversationManager.conversations[0].messages[index].status = .completed
                    }
                    conversationManager.saveConversations()
                    
                case .failure(let error):
                    // 显示错误
                    if let index = conversationManager.currentConversation?.messages.firstIndex(where: { $0.id == aiMessage.id }) {
                        conversationManager.conversations[0].messages[index].content = "获取AI回复失败: \(error.localizedDescription)"
                        conversationManager.conversations[0].messages[index].status = .error
                    }
                }
                
                isProcessing = false
            }
        }
    }
}

// 侧边栏对话列表组件
struct SidebarConversationsList: View {
    let conversations: [Conversation]
    let currentID: UUID?
    let onSelect: (UUID) -> Void
    let onDelete: (UUID) -> Void
    
    @State private var editMode: Bool = false
    @State private var searchText: String = ""
    @Environment(\.colorScheme) var colorScheme
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("历史对话")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editMode.toggle()
                    }
                }) {
                    Text(editMode ? "完成" : "编辑")
                        .font(.subheadline)
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索对话", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if filteredConversations.isEmpty {
                VStack {
                    if searchText.isEmpty {
                        Text("没有历史对话")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        Text("没有匹配的对话")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: conversation.id == currentID,
                                editMode: editMode,
                                onSelect: { onSelect(conversation.id) },
                                onDelete: { onDelete(conversation.id) }
                            )
                            
                            if conversation.id != filteredConversations.last?.id {
                                Divider()
                                    .padding(.leading, 40)
                            }
                        }
                    }
                }
            }
        }
    }
}

// 对话行项目
struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let editMode: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.fill")
                        .foregroundColor(isSelected ? AppColors.primary : .gray.opacity(0.7))
                        .font(.system(size: 14))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.title)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .foregroundColor(isSelected ? AppColors.primary : .primary)
                            .lineLimit(1)
                        
                        Text(formattedDate(conversation.timestamp))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(AppColors.primary)
                            .font(.system(size: 12))
                    }
                    
                    if editMode || isHovering {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .foregroundColor(AppColors.errorRed)
                                .font(.system(size: 13))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
                .padding(.vertical, 10)
                .padding(.horizontal)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected 
                              ? (colorScheme == .dark ? Color.primary.opacity(0.15) : Color.primary.opacity(0.08))
                              : (isHovering ? Color.primary.opacity(0.03) : Color.clear)
                        )
                        .padding(.horizontal, 4)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        // 今天的日期只显示时间
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: date)
        }
        
        // 昨天的日期显示"昨天"和时间
        if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: date)
        }
        
        // 本周的其他日期显示星期几和时间
        let components = Calendar.current.dateComponents([.day], from: date, to: Date())
        if let days = components.day, days < 7 {
            formatter.dateFormat = "EEEE HH:mm"
            return formatter.string(from: date)
        }
        
        // 其他日期显示完整日期
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// 消息气泡组件
struct MessageBubble: View {
    let message: Message
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer()
            } else {
                // AI头像
                Avatar(isUser: false)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Text(message.content)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            message.isUser ? 
                                AppColors.userBubble :
                                (colorScheme == .dark ? Color.gray.opacity(0.3) : AppColors.aiBubble)
                        )
                        .foregroundColor(message.isUser ? .white : .primary)
                        .cornerRadius(20)
                        .cornerRadius(message.isUser ? 20 : 4, corners: message.isUser ? [.topLeft, .bottomLeft, .bottomRight] : [.topRight, .bottomLeft, .bottomRight])
                    
                    // 只有在非用户消息上显示复制按钮
                    if !message.isUser && isHovering {
                        Button(action: {
                            copyToClipboard(message.content)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 12))
                                .padding(6)
                                .background(Circle().fill(Color.white.opacity(0.9)))
                                .foregroundColor(AppColors.primary)
                                .shadow(color: Color.black.opacity(0.1), radius: 1)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .offset(x: 8, y: -8)
                        .transition(.opacity)
                    }
                }
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
            }
            
            if !message.isUser {
                Spacer()
            } else {
                // 用户头像
                Avatar(isUser: true)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // 复制到剪贴板功能
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

// 头像组件
struct Avatar: View {
    let isUser: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isUser ? AppColors.primary.opacity(0.2) : Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
            
            Image(systemName: isUser ? "person.fill" : "brain")
                .font(.system(size: 14))
                .foregroundColor(isUser ? AppColors.primary : .gray)
        }
    }
}

// 为指定角添加圆角功能的扩展
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = CGPoint(x: rect.minX, y: rect.minY)
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        
        // 顶部边
        if corners.contains(.topLeft) {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        } else {
            path.move(to: topLeft)
        }
        
        // 右上角
        if corners.contains(.topRight) {
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
        } else {
            path.addLine(to: topRight)
        }
        
        // 右边
        if corners.contains(.bottomRight) {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
        } else {
            path.addLine(to: bottomRight)
        }
        
        // 底部
        if corners.contains(.bottomLeft) {
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
        } else {
            path.addLine(to: bottomLeft)
        }
        
        // 左边和左上角
        if corners.contains(.topLeft) {
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
        } else {
            path.addLine(to: topLeft)
        }
        
        return path
    }
}

// 定义圆角类型
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomRight = RectCorner(rawValue: 1 << 2)
    static let bottomLeft = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomRight, .bottomLeft]
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// 预览
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
    }
} 