#!/bin/bash

# 显示编译信息
echo "🚀 开始构建 TextSage 应用..."

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_DIR"

# 确保build目录存在
mkdir -p build

# 执行make命令
if [ "$1" == "clean" ]; then
    cd scripts && make clean
    echo "🧹 清理完成"
elif [ "$1" == "run" ]; then
    cd scripts && make run
    echo "🚀 应用已启动"
else
    cd scripts && make
    echo "✅ 构建完成"
fi

# 返回脚本目录
cd "$SCRIPT_DIR"

echo "构建过程结束" 