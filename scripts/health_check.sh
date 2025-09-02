#!/bin/bash

# =================================
# Docker容器健康检查脚本
# 功能：检查cron服务状态、日志文件、磁盘空间等
# =================================

set -e

# 健康检查日志文件
HEALTH_LOG="/app/logs/health.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
log_health() {
    echo "[$TIMESTAMP] $1" >> "$HEALTH_LOG"
    echo -e "$1"
}

# 检查结果变量
HEALTH_STATUS="healthy"
ISSUES=()

# =================================
# 1. 检查cron服务状态
# =================================
log_health "开始健康检查..."

if pgrep cron > /dev/null; then
    log_health "${GREEN}✓${NC} cron服务正在运行"
else
    log_health "${RED}✗${NC} cron服务未运行"
    ISSUES+=("cron服务未运行")
    HEALTH_STATUS="unhealthy"
fi

# =================================
# 2. 检查日志文件可写性
# =================================
for log_file in "/app/logs/task1.log" "/app/logs/task2.log" "/app/logs/task3.log"; do
    if [ -w "$log_file" ]; then
        log_health "${GREEN}✓${NC} 日志文件可写: $(basename $log_file)"
    else
        log_health "${RED}✗${NC} 日志文件不可写: $(basename $log_file)"
        ISSUES+=("日志文件不可写: $(basename $log_file)")
        HEALTH_STATUS="unhealthy"
    fi
done

# =================================
# 3. 检查磁盘空间
# =================================
DISK_USAGE=$(df /app | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 90 ]; then
    log_health "${GREEN}✓${NC} 磁盘空间正常 (使用率: ${DISK_USAGE}%)"
else
    log_health "${YELLOW}⚠${NC} 磁盘空间不足 (使用率: ${DISK_USAGE}%)"
    ISSUES+=("磁盘空间不足")
    if [ "$DISK_USAGE" -gt 95 ]; then
        HEALTH_STATUS="unhealthy"
    fi
fi

# =================================
# 4. 检查Python环境
# =================================
if python --version > /dev/null 2>&1; then
    PYTHON_VERSION=$(python --version 2>&1)
    log_health "${GREEN}✓${NC} Python环境正常: $PYTHON_VERSION"
else
    log_health "${RED}✗${NC} Python环境异常"
    ISSUES+=("Python环境异常")
    HEALTH_STATUS="unhealthy"
fi

# =================================
# 5. 检查定时任务配置
# =================================
CRON_COUNT=$(crontab -l 2>/dev/null | grep -c "python main.py" || echo "0")
if [ "$CRON_COUNT" -ge 3 ]; then
    log_health "${GREEN}✓${NC} 定时任务配置正常 (找到 $CRON_COUNT 个任务)"
else
    log_health "${YELLOW}⚠${NC} 定时任务配置可能有问题 (找到 $CRON_COUNT 个任务，期望 3 个)"
    ISSUES+=("定时任务配置异常")
fi

# =================================
# 6. 检查最近的任务执行记录
# =================================
check_recent_logs() {
    local log_file=$1
    local task_name=$2
    
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        # 检查最近24小时内是否有日志记录
        local recent_log=$(find "$log_file" -mtime -1 2>/dev/null)
        if [ -n "$recent_log" ]; then
            log_health "${GREEN}✓${NC} $task_name 最近有执行记录"
        else
            log_health "${YELLOW}⚠${NC} $task_name 24小时内无执行记录"
        fi
    else
        log_health "${YELLOW}⚠${NC} $task_name 日志文件为空或不存在"
    fi
}

check_recent_logs "/app/logs/task1.log" "任务1"
check_recent_logs "/app/logs/task2.log" "任务2" 
check_recent_logs "/app/logs/task3.log" "任务3"

# =================================
# 7. 检查任务脚本文件存在性
# =================================
for task_dir in "/app/task1" "/app/task2" "/app/task3"; do
    if [ -f "$task_dir/main.py" ]; then
        log_health "${GREEN}✓${NC} 脚本文件存在: $task_dir/main.py"
    else
        log_health "${RED}✗${NC} 脚本文件缺失: $task_dir/main.py"
        ISSUES+=("脚本文件缺失: $task_dir/main.py")
        HEALTH_STATUS="unhealthy"
    fi
done

# =================================
# 8. 生成健康检查报告
# =================================
log_health "========================================"
if [ "$HEALTH_STATUS" = "healthy" ]; then
    log_health "${GREEN}✓ 健康检查通过${NC}"
    if [ ${#ISSUES[@]} -gt 0 ]; then
        log_health "${YELLOW}警告信息:${NC}"
        for issue in "${ISSUES[@]}"; do
            log_health "  - $issue"
        done
    fi
    exit 0
else
    log_health "${RED}✗ 健康检查失败${NC}"
    log_health "${RED}发现问题:${NC}"
    for issue in "${ISSUES[@]}"; do
        log_health "  - $issue"
    done
    exit 1
fi