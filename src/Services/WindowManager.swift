import Cocoa
import SwiftUI
import ObjectiveC

// 定义一个关联对象的 key
private var delegateKey: UInt8 = 0
private var settingsDelegateKey: UInt8 = 0

// 窗口管理器：负责创建和管理应用窗口
class WindowManager {
    // 单例模式
    static let shared = WindowManager()
    
    // 私有构造函数，防止外部创建实例
    private init() {}
    
    // 存储所有聊天窗口
    private var chatWindows: [NSWindow] = []
    private var settingsWindow: NSWindow?
    private var settingsCloseDelegate: WindowCloseDelegate?
    
    // 显示设置窗口
    func showSettingsWindow() {
        // 如果已经有设置窗口，则激活它
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // 创建设置窗口
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口属性
        window.title = "TextCraft 设置"
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        
        // 使用 SwiftUI 视图作为内容
        let settingsView = SettingsView()
        let hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView
        
        // 配置窗口关闭委托
        settingsCloseDelegate = WindowCloseDelegate(handler: { [weak self] closedWindow in
            self?.settingsWindow = nil
        })
        window.delegate = settingsCloseDelegate
        objc_setAssociatedObject(window, &settingsDelegateKey, settingsCloseDelegate, .OBJC_ASSOCIATION_RETAIN)
        
        // 显示窗口
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 保存窗口引用
        self.settingsWindow = window
    }
    
    // 显示聊天窗口
    func showChatWindow() {
        // 获取鼠标位置
        let mouseLocation = NSEvent.mouseLocation
        
        // 创建窗口
        let window = createWindowNearPosition(mouseLocation)
        
        // 创建并设置内容视图
        let chatView = ChatView()
        // 不需要为每个ChatView创建新的ConversationManager，现在使用单例
        
        // 不再需要直接设置选中的文本，ChatView将从AppState获取
        let hostingView = NSHostingView(rootView: chatView)
        window.contentView = hostingView
        
        // 显示窗口，使用淡入动画
        window.alphaValue = 0.0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 应用淡入动画
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1.0
        }
        
        // 存储窗口引用
        chatWindows.append(window)
        
        // 窗口关闭回调
        let closeDelegate = WindowCloseDelegate(handler: { [weak self] closedWindow in
            // 关闭窗口前确保对话已保存
            ConversationManager.shared.saveConversations()
            self?.removeWindow(closedWindow)
        })
        // 保持对 delegate 的强引用，以防止立即被销毁
        window.delegate = closeDelegate
        // 使用关联对象保持对 delegate 的强引用
        objc_setAssociatedObject(window, &delegateKey, closeDelegate, .OBJC_ASSOCIATION_RETAIN)
    }
    
    // 为了向后兼容，保留老方法但在内部调用新方法
    @available(*, deprecated, message: "Use showChatWindow() instead")
    func showChatWindowWithText(_ text: String) {
        print("⚠️ 警告：使用了过时的API showChatWindowWithText，请改用showChatWindow()")
        showChatWindow()
    }
    
    // 在指定位置附近创建窗口
    private func createWindowNearPosition(_ position: NSPoint) -> NSWindow {
        // 计算窗口位置，避免超出屏幕边界
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 700)
        let windowSize = NSSize(width: 650, height: 500)
        
        var windowOrigin = NSPoint(
            x: min(max(position.x - windowSize.width / 2, screenFrame.minX), screenFrame.maxX - windowSize.width),
            y: min(max(position.y - windowSize.height / 2, screenFrame.minY), screenFrame.maxY - windowSize.height)
        )
        
        // 确保窗口在当前屏幕上
        for screen in NSScreen.screens {
            if NSPointInRect(position, screen.frame) {
                let screenVisibleFrame = screen.visibleFrame
                
                if windowOrigin.x + windowSize.width > screenVisibleFrame.maxX {
                    windowOrigin.x = screenVisibleFrame.maxX - windowSize.width
                }
                
                if windowOrigin.y + windowSize.height > screenVisibleFrame.maxY {
                    windowOrigin.y = screenVisibleFrame.maxY - windowSize.height
                }
                
                break
            }
        }
        
        // 创建窗口
        let window = NSWindow(
            contentRect: NSRect(origin: windowOrigin, size: windowSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // 配置窗口
        window.title = "TextCraft AI"
        window.isReleasedWhenClosed = false
        
        // 设置窗口背景色，支持深色/浅色模式
        window.backgroundColor = NSColor(name: nil, dynamicProvider: { appearance in
            return appearance.name.rawValue.contains("Dark") 
                ? NSColor(white: 0.2, alpha: 1.0) 
                : NSColor(white: 0.95, alpha: 1.0)
        })
        
        // 设置窗口动画
        window.animationBehavior = .documentWindow
        
        // 半透明标题栏
        window.titlebarAppearsTransparent = true
        window.hasShadow = true
        
        return window
    }
    
    // 从列表中移除关闭的窗口
    private func removeWindow(_ window: NSWindow) {
        if window == settingsWindow {
            settingsWindow = nil
        } else {
            chatWindows.removeAll { $0 == window }
        }
    }
    
    // 关闭所有窗口
    func closeAllWindows() {
        // 关闭聊天窗口
        for window in chatWindows {
            window.close()
        }
        chatWindows.removeAll()
        
        // 关闭设置窗口
        settingsWindow?.close()
        settingsWindow = nil
    }
}

// 窗口关闭委托
class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let closeHandler: (NSWindow) -> Void
    
    init(handler: @escaping (NSWindow) -> Void) {
        self.closeHandler = handler
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            closeHandler(window)
        }
    }
} 
 