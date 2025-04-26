# TextSage AI 助手应用构建脚本

.PHONY: all clean run app

# 基础路径
SRC_DIR = ../src
BUILD_DIR = ../build

# 编译命令
SWIFT = swiftc
APP_NAME = TextSage
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app

# 代理配置
PROXY = export https_proxy=http://127.0.0.1:7890; export http_proxy=http://127.0.0.1:7890; export all_proxy=socks5://127.0.0.1:7890;

# 源文件
SOURCES = $(SRC_DIR)/App/main.swift \
          $(SRC_DIR)/Services/TextExtractor.swift \
          $(SRC_DIR)/Services/WindowManager.swift \
          $(SRC_DIR)/Views/ChatView.swift \
          $(SRC_DIR)/Views/SettingsView.swift \
          $(SRC_DIR)/Views/ContentView.swift

# Swift 编译标记
SWIFT_FLAGS = -O -framework Cocoa -framework SwiftUI

# 默认构建目标是创建 .app 包
all: app

# 编译可执行文件
$(BUILD_DIR)/$(APP_NAME): $(SOURCES)
	@echo "📦 开始编译可执行文件 $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	@$(PROXY) $(SWIFT) $(SWIFT_FLAGS) -o $(BUILD_DIR)/$(APP_NAME) $(SOURCES)
	@echo "✅ 可执行文件编译完成"

# 创建 .app 包
app: $(BUILD_DIR)/$(APP_NAME)
	@echo "🏗️ 创建应用程序包 $(APP_BUNDLE)..."
	@rm -rf $(APP_BUNDLE) # 清理旧包
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp -r ../resources/Assets.xcassets $(APP_BUNDLE)/Contents/Resources/ # 复制资源文件
	@cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME) # 复制可执行文件并重命名
	@cp $(SRC_DIR)/App/Info.plist $(APP_BUNDLE)/Contents/ # 复制 Info.plist
	@echo "✅ 应用程序包创建完成: $(APP_BUNDLE)"

# 运行 .app 包
run: app
	@echo "🚀 启动应用 $(APP_BUNDLE)... (请确保已授予辅助功能权限)"
	@open $(APP_BUNDLE)

# 清理
clean:
	@echo "🧹 清理编译文件和应用包..."
	@rm -f $(BUILD_DIR)/$(APP_NAME)
	@rm -rf $(APP_BUNDLE)
	@echo "清理完成" 