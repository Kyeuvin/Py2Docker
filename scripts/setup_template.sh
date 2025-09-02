#!/bin/bash

# =================================
# 项目配置脚本模板
# 说明：每个项目目录需要包含此文件以启用自动管理
# 文件名：setup.sh (必须)
# 权限：可执行 (chmod +x setup.sh)
# =================================

# ==============================
# 基本项目信息 (必需)
# ==============================

# 项目名称：用于标识和日志记录
PROJECT_NAME="项目名称"

# 项目类型：支持 "cron" (定时任务) 或 "service" (后台服务)
PROJECT_TYPE="cron"

# ==============================
# 定时任务配置 (当 PROJECT_TYPE=cron 时必需)
# ==============================

# cron调度表达式
# 格式：分钟 小时 日期 月份 星期
# 示例：
#   "*/5 * * * *"     - 每5分钟执行
#   "0 */2 * * *"     - 每2小时执行  
#   "0 9 * * 1-5"     - 周一到周五上午9点执行
#   "30 2 * * 0"      - 每周日凌晨2:30执行
CRON_SCHEDULE="0 */2 * * *"

# cron执行命令
# 注意：
# 1. 使用绝对路径或相对路径
# 2. Python脚本请使用 python3 命令
# 3. 命令会在项目目录下执行
CRON_COMMAND="cd /app/项目目录 && python3 main.py"

# ==============================
# 后台服务配置 (当 PROJECT_TYPE=service 时必需)
# ==============================

# 后台服务执行命令
SERVICE_COMMAND="cd /app/项目目录 && python3 service.py"

# 重启策略：支持 "always", "on-failure", "never"
SERVICE_RESTART_POLICY="always"

# ==============================
# 可选函数定义
# ==============================

# 依赖检查函数 (可选)
# 返回 0 表示检查通过，返回 1 表示检查失败
check_dependencies() {
    echo "检查项目依赖..."
    
    # 检查 Python 文件是否存在
    if [[ ! -f "main.py" ]]; then
        echo "错误：找不到 main.py 文件"
        return 1
    fi
    
    # 检查 Python 包依赖 (示例)
    # python3 -c "import requests" 2>/dev/null || {
    #     echo "错误：缺少 requests 包"
    #     return 1
    # }
    
    # 检查环境变量 (示例)
    # if [[ -z "${API_KEY:-}" ]]; then
    #     echo "错误：缺少 API_KEY 环境变量"
    #     return 1
    # fi
    
    echo "依赖检查通过"
    return 0
}

# 项目初始化函数 (可选)
# 在注册任务前执行，用于准备工作
initialize() {
    echo "初始化项目: $PROJECT_NAME"
    
    # 创建必要目录 (示例)
    # mkdir -p data temp
    
    # 初始化配置文件 (示例)
    # if [[ ! -f "config.json" ]]; then
    #     echo '{"version": "1.0"}' > config.json
    # fi
    
    # 设置权限 (示例)
    # chmod 755 scripts/*.sh
    
    echo "初始化完成"
    return 0
}

# 项目清理函数 (可选)
# 在移除项目时执行
cleanup() {
    echo "清理项目: $PROJECT_NAME"
    
    # 清理临时文件 (示例)
    # rm -rf temp/*
    
    # 关闭资源连接 (示例)
    # pkill -f "项目相关进程"
    
    echo "清理完成"
    return 0
}