import Cocoa
import SwiftUI
import UserNotifications
import Security

// MARK: - 全局状态管理
class AppState {
    // 单例模式
    static let shared = AppState()
    
    // 私有构造函数
    private init() {}
    
    // 存储当前选中的文本
    private(set) var selectedText: String = ""
    
    // 更新选中的文本并通知订阅者
    func updateSelectedText(_ text: String) {
        self.selectedText = text
        NotificationCenter.default.post(name: .selectedTextDidChange, object: nil, userInfo: ["text": text])
    }
}

// MARK: - 添加通知名称扩展
extension Notification.Name {
    static let selectedTextDidChange = Notification.Name("selectedTextDidChange")
}

// MARK: - 程序入口点
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var globalHotkeyMonitor: Any?
    var textExtractor = TextExtractor()
    private var hasShownInitialSetup = false
    
    // 延迟加载菜单
    lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "设置", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "检查权限", action: #selector(checkPermissions), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        return menu
    }()
    
    // 定义支持的热键选项
    let hotkeyOptions: [String: (modifiers: NSEvent.ModifierFlags, keyCode: UInt16)] = [
        "Option+Command+A": (modifiers: [.option, .command], keyCode: 0),
        "Option+Command+S": (modifiers: [.option, .command], keyCode: 1),
        "Control+Shift+Space": (modifiers: [.control, .shift], keyCode: 49)
    ]
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("📱 TextCraft 应用已启动")
        
        // 先创建状态栏图标，这是用户看到的第一个UI元素
        setupStatusBar()
        
        // 检查深色模式设置并应用
        applyAppearanceSettings()
        
        // 在后台线程异步初始化应用其余部分
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 延迟权限检查，避免在启动时就显示对话框
            self.setupGlobalKeyMonitor()
            
            // 主线程处理UI相关操作
            DispatchQueue.main.async {
                // 检查是否第一次启动应用
                if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
                    self.hasShownInitialSetup = true
                    self.openSettings()
                    UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                    
                    // 仅在首次启动或权限明确被拒绝时请求权限
                    self.requestAccessibilityPermission()
                }
            }
        }
        
        // 监听用户默认值变化，当热键设置更改时重新设置监听器
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    // 用户默认值变化通知
    @objc private func userDefaultsDidChange() {
        // 检查热键是否改变，如果改变了就重新设置监听器
        let oldHotkey = UserDefaults.standard.string(forKey: "previousHotkey") ?? "Option+Command+A"
        let currentHotkey = UserDefaults.standard.string(forKey: "hotkey") ?? "Option+Command+A"
        
        if oldHotkey != currentHotkey {
            // 更新之前的热键记录
            UserDefaults.standard.set(currentHotkey, forKey: "previousHotkey")
            
            // 重新设置热键监听
            resetGlobalKeyMonitor()
        }
        
        // 应用深色模式设置
        applyAppearanceSettings()
    }
    
    // 应用外观设置
    private func applyAppearanceSettings() {
        let darkMode = UserDefaults.standard.bool(forKey: "darkMode")
        let appearance = darkMode ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        NSApp.appearance = appearance
    }
    
    // 设置状态栏图标 - 用户看到的第一个UI元素
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "选"
            
            // 设置菜单但在点击时才加载
            button.action = #selector(statusBarClicked)
            button.target = self
        }
    }
    
    // 状态栏图标点击事件 - 懒加载菜单
    @objc private func statusBarClicked() {
        if let statusItem = statusItem, statusItem.menu == nil {
            statusItem.menu = statusMenu
        }
        
        statusItem?.button?.performClick(nil)
    }
    
    // 打开设置窗口
    @objc private func openSettings() {
        WindowManager.shared.showSettingsWindow()
    }
    
    // 检查权限
    @objc private func checkPermissions() {
        requestAccessibilityPermission()
    }
    
    // 退出应用
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    // 请求辅助功能权限
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if accessibilityEnabled {
            print("✅ 已获得辅助功能权限")
        } else {
            print("⚠️ 应用需要辅助功能权限才能正常工作")
            
            // 显示提示窗口
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "请在系统设置的「隐私与安全性」→「辅助功能」中找到并授权此应用。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        }
    }
    
    // 重置全局热键监听
    private func resetGlobalKeyMonitor() {
        // 移除现有监听器
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }
        
        // 重新设置监听器
        setupGlobalKeyMonitor()
    }
    
    // 设置全局热键监听
    private func setupGlobalKeyMonitor() {
        print("🔑 设置全局键盘监听...")
        
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 从UserDefaults获取热键设置或使用默认值
            let hotkeyString = UserDefaults.standard.string(forKey: "hotkey") ?? "Option+Command+A"
            
            // 获取对应的热键配置
            guard let hotkeyConfig = self?.hotkeyOptions[hotkeyString] else {
                print("❌ 未知的热键配置: \(hotkeyString)")
                return
            }
            
            // 检查修饰键和键码是否匹配
            let matchesModifiers = event.modifierFlags.contains(hotkeyConfig.modifiers)
            let matchesKeyCode = event.keyCode == hotkeyConfig.keyCode
            
            if matchesModifiers && matchesKeyCode {
                print("🔥 全局热键触发: \(hotkeyString)")
                
                // 在主线程上处理，避免UI操作在后台线程
                DispatchQueue.main.async {
                    self?.handleHotkeyPressed()
                }
            }
        }
        
        if globalHotkeyMonitor == nil {
            print("⚠️ 无法设置全局键盘监听")
        } else {
            print("✅ 全局键盘监听已设置")
        }
    }
    
    // 处理热键按下事件
    private func handleHotkeyPressed() {
        // 获取选中文本
        textExtractor.getSelectedText { [weak self] result in
            switch result {
            case .success(let selectedText):
                guard !selectedText.isEmpty else {
                    self?.showNotification(title: "未能获取选中文本", message: "请先选择文本，然后再按快捷键")
                    return
                }
                
                print("📋 获取到选中文本: \(selectedText)")
                
                // 更新全局状态
                AppState.shared.updateSelectedText(selectedText)
                
                // 显示聊天窗口并处理选中文本
                DispatchQueue.main.async {
                    WindowManager.shared.showChatWindow()
                }
                
            case .failure(let error):
                print("❌ 获取选中文本失败: \(error.localizedDescription)")
                self?.showNotification(title: "获取文本失败", message: error.localizedDescription)
            }
        }
    }
    
    // 显示通知
    private func showNotification(title: String, message: String) {
        // 使用现代 UserNotifications 框架
        let center = UNUserNotificationCenter.current()
        
        // 请求通知权限
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted else {
                print("⚠️ 通知权限被拒绝")
                return
            }
            
            // 创建通知内容
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = message
            content.sound = UNNotificationSound.default
            
            // 创建立即触发的请求
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            
            // 添加通知请求
            center.add(request) { error in
                if let error = error {
                    print("❌ 发送通知失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 应用终止时清理
    func applicationWillTerminate(_ notification: Notification) {
        print("👋 应用即将退出")
        
        // 保存所有对话
        ConversationManager.shared.logMessage("应用程序即将终止，执行最终保存...")
        ConversationManager.shared.saveConversations()
        
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            globalHotkeyMonitor = nil
        }
        
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
    }
    
    // 应用进入后台时保存
    func applicationDidResignActive(_ notification: Notification) {
        // 保存所有对话
        ConversationManager.shared.logMessage("应用程序进入后台，执行保存...")
        ConversationManager.shared.saveConversations()
    }
}

// 主程序入口
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run() 