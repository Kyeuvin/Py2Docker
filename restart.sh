#!/bin/bash

# =================================
# 重启脚本
# 功能：重启Docker容器
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
echo -e "Docker定时任务容器重启脚本"
echo -e "========================================${NC}"

# 检查是否在项目根目录
if [ ! -f "docker-compose.yml" ]; then
    log_error "未找到docker-compose.yml文件，请在项目根目录运行此脚本"
    exit 1
fi

log_info "开始重启容器..."

# 停止容器
log_info "停止现有容器..."
if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
    docker compose down
    log_info "容器已停止"
else
    log_warn "容器未运行"
fi

# 短暂等待
sleep 2

# 启动容器
log_info "启动容器..."
if docker compose up -d; then
    log_info "容器启动成功"
else
    log_error "容器启动失败"
    exit 1
fi

# 等待容器就绪
log_info "等待容器就绪..."
sleep 10

# 检查容器状态
if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
    log_info "容器运行正常"
    
    # 显示容器信息
    echo ""
    echo -e "${BLUE}容器信息:${NC}"
    docker ps --filter "name=cron-tasks" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # 执行健康检查
    echo ""
    log_info "执行健康检查..."
    sleep 5
    docker exec cron-tasks /app/scripts/health_check.sh || log_warn "健康检查失败"
    
else
    log_error "容器重启失败，查看日志："
    docker logs cron-tasks
    exit 1
fi

echo ""
echo -e "${BLUE}========================================"
echo -e "容器重启完成"
echo -e "========================================${NC}"

echo -e "${GREEN}重启时间:${NC} $(date)"
echo ""
echo -e "${BLUE}常用命令:${NC}"
echo "  查看状态: ./status.sh"
echo "  查看日志: docker logs -f cron-tasks"
echo "  进入容器: docker exec -it cron-tasks bash"

echo ""
log_info "容器重启完成！"