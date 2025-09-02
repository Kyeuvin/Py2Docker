#!/bin/bash

# =================================
# 项目配置脚本: task2
# 描述: 通用定时任务
# 项目类型: 定时任务
# =================================

# 基本项目信息
PROJECT_NAME="task2"
PROJECT_TYPE="cron"

# 定时任务配置
CRON_SCHEDULE="*/30 * * * *"  # 每30分钟执行一次
CRON_COMMAND="cd /app/task2 && python3 main.py"

# 依赖检查函数
check_dependencies() {
    echo "检查task2项目依赖..."
    
    # 检查主程序文件
    if [[ ! -f "main.py" ]]; then
        echo "错误：找不到 main.py 文件"
        return 1
    fi
    
    # 检查Python环境
    if ! command -v python3 &> /dev/null; then
        echo "错误：Python3 未安装"
        return 1
    fi
    
    echo "依赖检查通过"
    return 0
}

# 项目初始化函数
initialize() {
    echo "初始化task2项目..."
    
    # 创建必要目录
    mkdir -p data logs temp 2>/dev/null || true
    
    # 设置权限
    chmod 755 . 2>/dev/null || true
    chmod +x *.py 2>/dev/null || true
    
    echo "task2初始化完成"
    return 0
}

# 项目清理函数
cleanup() {
    echo "清理task2项目..."
    
    # 清理临时文件
    rm -rf temp/* 2>/dev/null || true
    
    echo "task2清理完成"
    return 0
}