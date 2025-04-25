import Cocoa

// 获取文本时可能的错误
enum TextExtractorError: Error {
    case accessibilityFailed(String)
    case clipboardFailed(String)
    case noTextSelected
    
    var localizedDescription: String {
        switch self {
        case .accessibilityFailed(let reason):
            return "无法通过辅助功能获取文本: \(reason)"
        case .clipboardFailed(let reason):
            return "无法通过剪贴板获取文本: \(reason)"
        case .noTextSelected:
            return "未选中任何文本"
        }
    }
}

// 文本提取器，负责获取用户选中的文本
class TextExtractor {
    
    // 获取选中文本
    func getSelectedText(completion: @escaping (Result<String, TextExtractorError>) -> Void) {
        // 首先尝试通过 Accessibility API 获取
        if let text = getSelectedTextViaAccessibility() {
            completion(.success(text))
            return
        }
        
        print("🔄 通过辅助功能无法获取文本，尝试剪贴板方法...")
        
        // 备选：通过模拟复制获取文本
        getSelectedTextViaClipboard { result in
            switch result {
            case .success(let text):
                if !text.isEmpty {
                    completion(.success(text))
                } else {
                    completion(.failure(.noTextSelected))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // 使用 Accessibility API 获取选中文本
    private func getSelectedTextViaAccessibility() -> String? {
        print("🔍 正在通过 Accessibility API 获取选中文本...")
        
        // 创建系统级元素
        let systemWideElement = AXUIElementCreateSystemWide()
        
        // 获取当前聚焦的应用
        var focusedApp: AnyObject?
        let focusedAppResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )
        
        guard focusedAppResult == .success, let focusedApp = focusedApp else {
            print("❌ 无法获取当前应用: \(focusedAppResult.rawValue)")
            return nil
        }
        
        // 获取当前聚焦的元素
        var focusedElement: AnyObject?
        let focusedElementResult = AXUIElementCopyAttributeValue(
            focusedApp as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard focusedElementResult == .success, let focusedElement = focusedElement else {
            print("❌ 无法获取当前聚焦元素: \(focusedElementResult.rawValue)")
            return nil
        }
        
        // 获取选中的文本
        var selectedText: AnyObject?
        let selectedTextResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        
        if selectedTextResult == .success, let selectedText = selectedText as? String, !selectedText.isEmpty {
            print("✅ 成功获取选中文本！")
            return selectedText
        } else {
            print("❌ 无法获取选中文本: \(selectedTextResult.rawValue)")
            return nil
        }
    }
    
    // 通过模拟 Cmd+C 和剪贴板获取选中文本
    private func getSelectedTextViaClipboard(completion: @escaping (Result<String, TextExtractorError>) -> Void) {
        print("📎 正在通过剪贴板方法获取文本...")
        
        // 保存当前剪贴板内容
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.string(forType: .string)
        
        // 模拟 Cmd+C
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            completion(.failure(.clipboardFailed("无法创建事件源")))
            return
        }
        
        // 创建键盘事件 - 'c' 键的虚拟键码是 0x08
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        
        guard let keyDown = keyDown, let keyUp = keyUp else {
            completion(.failure(.clipboardFailed("无法创建键盘事件")))
            return
        }
        
        // 添加命令键修饰符
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        
        // 发送按键事件
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        
        // 等待剪贴板更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // 获取新的剪贴板内容
            let newContents = pasteboard.string(forType: .string)
            
            // 恢复原始剪贴板内容
            if let oldContents = oldContents {
                pasteboard.clearContents()
                pasteboard.setString(oldContents, forType: .string)
            }
            
            // 检查是否成功获取文本
            if let newContents = newContents, !newContents.isEmpty {
                // 如果剪贴板内容与原始内容相同，可能未选择新内容
                if newContents == oldContents {
                    print("⚠️ 剪贴板内容未变化，可能未选择新文本")
                    // 如果原始内容不为空，则返回它
                    if let oldContents = oldContents, !oldContents.isEmpty {
                        completion(.success(oldContents))
                    } else {
                        completion(.failure(.noTextSelected))
                    }
                } else {
                    print("✅ 通过剪贴板获取到文本")
                    completion(.success(newContents))
                }
            } else {
                completion(.failure(.clipboardFailed("复制到剪贴板失败")))
            }
        }
    }
} 
 
 