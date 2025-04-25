import SwiftUI
import Cocoa

// 热键选项
struct HotkeyOption: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let modifiers: NSEvent.ModifierFlags
    let keyCode: UInt16
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: HotkeyOption, rhs: HotkeyOption) -> Bool {
        return lhs.id == rhs.id
    }
}

// 文本大小选项
struct FontSizeOption: Identifiable, Hashable {
    let id = UUID()
    let size: Double
    let title: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FontSizeOption, rhs: FontSizeOption) -> Bool {
        return lhs.id == rhs.id
    }
}

// 设置视图模型
class SettingsViewModel: ObservableObject {
    @AppStorage("apiKey") var apiKey: String = "ffbf403d-6005-4c80-9d3d-54d006fa77c4"
    @AppStorage("hotkey") var hotkeyPreference: String = "Option+Command+A"
    @AppStorage("maxHistoryItems") var maxHistoryItems: Int = 50
    @AppStorage("darkMode") var darkMode: Bool = false
    @AppStorage("fontSize") var fontSize: Double = 14.0
    @AppStorage("modelId") var modelId: String = "ep-20250425224304-5j9mj" // Deepseek-v3 默认
    @AppStorage("useStreamOutput") var useStreamOutput: Bool = true // 默认开启流式输出
    
    @Published var isTestingAPI: Bool = false
    @Published var apiTestResult: String = ""
    
    let hotkeyOptions: [HotkeyOption] = [
        HotkeyOption(title: "Option+Command+A", modifiers: [.option, .command], keyCode: 0),
        HotkeyOption(title: "Option+Command+S", modifiers: [.option, .command], keyCode: 1),
        HotkeyOption(title: "Control+Shift+Space", modifiers: [.control, .shift], keyCode: 49)
    ]
    
    let fontSizeOptions: [FontSizeOption] = [
        FontSizeOption(size: 12.0, title: "小"),
        FontSizeOption(size: 14.0, title: "中"),
        FontSizeOption(size: 16.0, title: "大"),
        FontSizeOption(size: 18.0, title: "特大")
    ]
    
    let modelOptions: [(title: String, id: String)] = [
        ("Deepseek-V3", "ep-20250425224304-5j9mj"),
        ("Deepseek-R1", "ep-20250426002451-sx44v")
    ]
    
    // 获取当前热键选项
    var currentHotkeyOption: HotkeyOption {
        hotkeyOptions.first { $0.title == hotkeyPreference } ?? hotkeyOptions[0]
    }
    
    // 获取当前字体大小选项
    var currentFontSizeOption: FontSizeOption {
        fontSizeOptions.first { $0.size == fontSize } ?? fontSizeOptions[1]
    }
    
    // 测试API连接
    func testAPIConnection() {
        isTestingAPI = true
        apiTestResult = "正在测试连接..."
        
        // 使用单例AIService进行测试
        AIService.shared.apiKey = apiKey
        AIService.shared.modelId = modelId
        
        AIService.shared.testAPIConnection { isSuccess, message in
            DispatchQueue.main.async {
                self.isTestingAPI = false
                self.apiTestResult = message
                
                // 记录测试结果到日志
                ConversationManager.shared.logMessage("API连接测试结果: \(isSuccess ? "成功" : "失败") - \(message)")
            }
        }
    }
    
    // 重置设置到默认值
    func resetToDefaults() {
        apiKey = "ffbf403d-6005-4c80-9d3d-54d006fa77c4"
        hotkeyPreference = "Option+Command+A"
        maxHistoryItems = 50
        darkMode = false
        fontSize = 14.0
        modelId = "ep-20250425224304-5j9mj"
        useStreamOutput = true
        apiTestResult = ""
        
        // 确保设置保存到UserDefaults
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        UserDefaults.standard.set(modelId, forKey: "modelId")
        UserDefaults.standard.set(useStreamOutput, forKey: "useStreamOutput")
        
        // 应用深色模式设置
        applyDarkModeSettings()
        
        print("所有设置已重置为默认值")
    }
    
    // 应用深色模式设置
    func applyDarkModeSettings() {
        let appearance = darkMode ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        NSApp.appearance = appearance
    }
    
    // 在初始化后应用深色模式设置
    func applySettings() {
        applyDarkModeSettings()
    }
}

// 设置视图
struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 10)
            
            GroupBox(label: Text("API 设置").font(.headline)) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("API Key")
                        .font(.subheadline)
                    
                    HStack {
                        SecureField("输入您的API密钥", text: $viewModel.apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(height: 30)
                        
                        Button(action: {
                            viewModel.testAPIConnection()
                        }) {
                            HStack {
                                if viewModel.isTestingAPI {
                                    ProgressView()
                                        .controlSize(.small)
                                        .scaleEffect(0.7)
                                }
                                Text(viewModel.isTestingAPI ? "测试中..." : "测试连接")
                            }
                            .frame(minWidth: 80)
                        }
                        .disabled(viewModel.apiKey.isEmpty || viewModel.isTestingAPI)
                    }
                    
                    if !viewModel.apiTestResult.isEmpty {
                        Text(viewModel.apiTestResult)
                            .font(.caption)
                            .foregroundColor(viewModel.apiTestResult.contains("成功") ? .green : .red)
                            .padding(.top, 5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
            }
            
            GroupBox(label: Text("AI 设置").font(.headline)) {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("选择模型")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("模型", selection: $viewModel.modelId) {
                            ForEach(viewModel.modelOptions, id: \.id) { option in
                                Text(option.title).tag(option.id)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: .infinity)
                        .onChange(of: viewModel.modelId) { oldValue, newValue in
                            // 确保模型ID保存到UserDefaults
                            UserDefaults.standard.set(newValue, forKey: "modelId")
                            print("模型已更改为: \(newValue)")
                        }
                    }
                    
                    Divider()
                    
                    Toggle("启用流式输出（打字机效果）", isOn: $viewModel.useStreamOutput)
                        .padding(.top, 5)
                        .onChange(of: viewModel.useStreamOutput) { oldValue, newValue in
                            // 确保流式输出设置保存到UserDefaults
                            UserDefaults.standard.set(newValue, forKey: "useStreamOutput")
                            print("流式输出设置已更改为: \(newValue ? "开启" : "关闭")")
                        }
                    
                    Text("流式输出可以实时显示AI的回复，但可能增加API调用的负担")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                    
                    HStack {
                        Button(action: {
                            viewModel.testAPIConnection()
                        }) {
                            if viewModel.isTestingAPI {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Label("测试连接", systemImage: "network")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isTestingAPI)
                        
                        Spacer()
                        
                        Button("重置为默认") {
                            viewModel.resetToDefaults()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 5)
                }
                .padding()
            }
            
            GroupBox(label: Text("通用设置").font(.headline)) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("全局热键")
                            .frame(width: 120, alignment: .leading)
                        
                        Picker("", selection: $viewModel.hotkeyPreference) {
                            ForEach(viewModel.hotkeyOptions, id: \.title) { option in
                                Text(option.title).tag(option.title)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(minWidth: 200)
                    }
                    
                    HStack {
                        Text("历史记录数量")
                            .frame(width: 120, alignment: .leading)
                        
                        Stepper("\(viewModel.maxHistoryItems)", value: $viewModel.maxHistoryItems, in: 10...200, step: 10)
                            .frame(minWidth: 120)
                    }
                    
                    HStack {
                        Text("深色模式")
                            .frame(width: 120, alignment: .leading)
                        
                        Toggle("", isOn: $viewModel.darkMode)
                            .onChange(of: viewModel.darkMode) { oldValue, newValue in
                                viewModel.applyDarkModeSettings()
                            }
                    }
                    
                    HStack {
                        Text("字体大小")
                            .frame(width: 120, alignment: .leading)
                        
                        Picker("", selection: $viewModel.fontSize) {
                            ForEach(viewModel.fontSizeOptions, id: \.size) { option in
                                Text(option.title).tag(option.size)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding()
            }
            
            if #available(macOS 12.0, *) {
                GroupBox(label: Text("关于").font(.headline)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TextCraft AI 版本 1.0.0")
                            .font(.subheadline)
                        
                        Text("一款现代化的AI文本处理助手")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            
            Spacer()
            
            HStack {
                Button("恢复默认设置") {
                    viewModel.resetToDefaults()
                }
                
                Spacer()
                
                Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 500, height: 550)
        .onAppear {
            viewModel.applySettings()
            
            // 确保从UserDefaults加载设置
            viewModel.modelId = UserDefaults.standard.string(forKey: "modelId") ?? "ep-20250425224304-5j9mj"
            viewModel.useStreamOutput = UserDefaults.standard.bool(forKey: "useStreamOutput")
            
            print("设置页面已加载 - 流式输出: \(viewModel.useStreamOutput ? "开启" : "关闭"), 模型: \(viewModel.modelId)")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
 