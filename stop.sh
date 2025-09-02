#!/bin/bash

# =================================
# 停止脚本
# 功能：优雅停止Docker容器
# =================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo -e "${BLUE}========================================"
echo -e "Docker定时任务容器停止脚本"
echo -e "========================================${NC}"

# 检查容器是否运行
if ! docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
    log_warn "容器 cron-tasks 未运行"
    exit 0
fi

# 显示容器信息
log_info "当前运行的容器信息:"
docker ps --filter "name=cron-tasks" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
log_info "停止容器..."

# 优雅停止容器
if docker compose down; then
    log_info "容器已优雅停止"
else
    log_warn "优雅停止失败，尝试强制停止..."
    if docker stop cron-tasks; then
        docker rm cron-tasks
        log_info "容器已强制停止"
    else
        log_error "容器停止失败"
        exit 1
    fi
fi

# 检查是否完全停止
if docker ps -a --filter "name=cron-tasks" | grep -q cron-tasks; then
    log_warn "容器仍然存在（已停止状态）"
    echo "使用以下命令完全删除: docker rm cron-tasks"
else
    log_info "容器已完全移除"
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "容器停止完成"
echo -e "========================================${NC}"

echo -e "${GREEN}停止时间:${NC} $(date)"
echo ""
echo -e "${BLUE}重新启动容器:${NC}"
echo "  ./start.sh 或 docker compose up -d"

echo ""
log_info "容器停止完成！"
