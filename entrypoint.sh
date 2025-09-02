#!/bin/bash

# =================================
# Docker容器入口脚本
# 功能：启动cron服务并配置定时任务
# =================================

set -e

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 设置默认环境变量
export TASK1_SCHEDULE=${TASK1_SCHEDULE:-"0 */2 * * *"}
export TASK2_SCHEDULE=${TASK2_SCHEDULE:-"*/30 * * * *"}
export TASK3_SCHEDULE=${TASK3_SCHEDULE:-"0 9 * * 1"}
export TIMEZONE=${TIMEZONE:-"Asia/Shanghai"}
export LOG_LEVEL=${LOG_LEVEL:-"INFO"}

log_info "容器启动中..."
log_info "时区设置: $TIMEZONE"
log_info "日志级别: $LOG_LEVEL"

# 设置时区
if [ ! -z "$TIMEZONE" ]; then
    ln -snf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    echo $TIMEZONE > /etc/timezone
    log_info "时区已设置为: $TIMEZONE"
fi

# 创建必要的目录
mkdir -p /app/logs /app/data
chmod 755 /app/logs /app/data

# 确保日志文件存在
touch /app/logs/task1.log
touch /app/logs/task2.log
touch /app/logs/task3.log
touch /app/logs/cron.log
touch /app/logs/health.log

# 设置日志文件权限
chmod 666 /app/logs/*.log

log_info "初始化定时任务配置..."

# 生成crontab配置
cat > /tmp/crontab << EOF
# Docker容器定时任务配置
# 生成时间: $(date)
# 
# 格式: 分钟 小时 日期 月份 星期 命令
#
# 设置环境变量
SHELL=/bin/bash
PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
HOME=/root
PYTHONUNBUFFERED=1

# 任务1: $TASK1_SCHEDULE
$TASK1_SCHEDULE cd /app/task1 && python3 main.py >> /app/logs/task1.log 2>&1

# 任务2: $TASK2_SCHEDULE  
$TASK2_SCHEDULE cd /app/task2 && python3 main.py >> /app/logs/task2.log 2>&1

# 任务3: $TASK3_SCHEDULE
$TASK3_SCHEDULE cd /app/task3 && python3 main.py >> /app/logs/task3.log 2>&1

EOF

# 安装crontab
crontab /tmp/crontab

log_info "定时任务配置完成:"
log_info "  - 任务1: $TASK1_SCHEDULE"
log_info "  - 任务2: $TASK2_SCHEDULE" 
log_info "  - 任务3: $TASK3_SCHEDULE"

# 显示当前crontab
log_info "当前定时任务列表:"
crontab -l | grep -v "^#" | grep -v "^$" || log_warn "没有找到活动的定时任务"

# 启动cron服务
log_info "启动cron服务..."
service cron start

# 检查cron服务状态
if pgrep cron > /dev/null; then
    log_info "cron服务启动成功"
else
    log_error "cron服务启动失败"
    exit 1
fi

# 创建健康检查监听
log_info "启动健康检查监听..."
nohup bash -c 'while true; do echo -e "HTTP/1.1 200 OK\n\nHealthy" | nc -l -p 8080 -q 1; done' &

# 后台任务（不需定时）请在此处创建：

# 启动后台任务 task4（如果存在）
if [ -f "/app/task4/main.py" ]; then
    log_info "启动后台任务 task4..."
    nohup python3 /app/task4/main.py >> /app/logs/task4.log 2>&1 &
    TASK4_PID=$!
    log_info "Task4 已启动，PID: $TASK4_PID"
    echo $TASK4_PID > /app/logs/task4.pid
fi

# 输出启动信息
log_info "============================================"
log_info "定时任务容器启动完成"
log_info "容器名称: $HOSTNAME"
log_info "启动时间: $(date)"
log_info "Python版本: $(python3 --version 2>/dev/null || echo 'Python3 not found')"
log_info "============================================"

# 保持容器运行并监控cron服务
log_info "监控cron服务状态..."

# 定期检查cron服务并输出日志
while true; do
    if ! pgrep cron > /dev/null; then
        log_error "cron服务已停止，尝试重启..."
        service cron start
        sleep 5
        if pgrep cron > /dev/null; then
            log_info "cron服务重启成功"
        else
            log_error "cron服务重启失败，退出容器"
            exit 1
        fi
    fi
    
    # 检查 task4 是否还在运行（如果存在）
    if [ -f "/app/logs/task4.pid" ]; then
        TASK4_PID=$(cat /app/logs/task4.pid)
        if ! kill -0 $TASK4_PID 2>/dev/null; then
            log_warn "Task4 进程已停止，尝试重启..."
            nohup python3 /app/task4/main.py >> /app/logs/task4.log 2>&1 &
            NEW_PID=$!
            echo $NEW_PID > /app/logs/task4.pid
            log_info "Task4 已重启，新PID: $NEW_PID"
        fi
    fi
    
    # 每30秒检查一次
    sleep 30
done