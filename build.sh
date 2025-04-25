#!/bin/bash

# 显示编译信息
echo "🚀 开始构建 TextSage 应用..."

# 进入脚本目录
cd "$(dirname "$0")/scripts"

# 执行make命令
if [ "$1" == "clean" ]; then
    make clean
    echo "🧹 清理完成"
elif [ "$1" == "run" ]; then
    make run
    echo "🚀 应用已启动"
else
    make
    echo "✅ 构建完成"
fi

# 返回上级目录
cd ..

echo "构建过程结束" 