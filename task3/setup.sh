#!/bin/bash

# =================================
# 项目配置脚本: task3
# 描述: 周期性维护任务
# 项目类型: 定时任务
# =================================

# 基本项目信息
PROJECT_NAME="task3"
PROJECT_TYPE="cron"

# 定时任务配置
CRON_SCHEDULE="0 9 * * 1"  # 每周一上午9点执行
CRON_COMMAND="cd /app/task3 && python3 main.py"

# 依赖检查函数
check_dependencies() {
    echo "检查task3项目依赖..."
    
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
    echo "初始化task3项目..."
    
    # 创建必要目录
    mkdir -p data logs temp 2>/dev/null || true
    
    # 设置权限
    chmod 755 . 2>/dev/null || true
    chmod +x *.py 2>/dev/null || true
    
    echo "task3初始化完成"
    return 0
}

# 项目清理函数
cleanup() {
    echo "清理task3项目..."
    
    # 清理临时文件
    rm -rf temp/* 2>/dev/null || true
    
    echo "task3清理完成"
    return 0
}