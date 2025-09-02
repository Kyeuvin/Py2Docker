#!/bin/bash

# =================================
# 一键启动脚本
# 功能：构建并启动Docker容器
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
echo -e "Docker定时任务容器启动脚本"
echo -e "========================================${NC}"

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    log_error "Docker未安装，请先安装Docker"
    exit 1
fi

# 检查Docker Compose是否安装
if ! command -v docker compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose未安装，请先安装Docker Compose"
    exit 1
fi

# 检查是否在项目根目录
if [ ! -f "docker-compose.yml" ]; then
    log_error "未找到docker-compose.yml文件，请在项目根目录运行此脚本"
    exit 1
fi

log_info "检查环境配置..."

# 检查.env文件
if [ ! -f ".env" ]; then
    log_warn ".env文件不存在，将使用默认配置"
fi

# 检查任务脚本
for task in task1 task2 task3; do
    if [ ! -f "$task/main.py" ]; then
        log_error "缺少任务脚本: $task/main.py"
        exit 1
    fi
done

log_info "环境检查通过"

# 停止现有容器（如果存在）
log_info "停止现有容器..."
if docker ps -q --filter "name=cron-tasks" | grep -q .; then
    docker stop cron-tasks || true
    docker rm cron-tasks || true
    log_info "已停止现有容器"
fi

# 构建镜像
log_info "构建Docker镜像..."
if docker compose build --no-cache; then
    log_info "镜像构建成功"
else
    log_error "镜像构建失败"
    exit 1
fi

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
else
    log_error "容器启动失败，查看日志："
    docker logs cron-tasks
    exit 1
fi

# 显示容器信息
echo -e "${BLUE}========================================"
echo -e "容器启动完成"
echo -e "========================================${NC}"

echo -e "${GREEN}容器名称:${NC} cron-tasks"
echo -e "${GREEN}容器ID:${NC} $(docker ps --filter "name=cron-tasks" --format "{{.ID}}")"
echo -e "${GREEN}启动时间:${NC} $(date)"

echo ""
echo -e "${BLUE}常用命令:${NC}"
echo "  查看容器状态: docker ps"
echo "  查看容器日志: docker logs cron-tasks"
echo "  进入容器: docker exec -it cron-tasks bash"
echo "  停止容器: ./stop.sh 或 docker compose down"
echo "  查看定时任务: docker exec cron-tasks crontab -l"
echo "  查看健康状态: docker exec cron-tasks /app/scripts/health_check.sh"

echo ""
echo -e "${BLUE}日志文件位置:${NC}"
echo "  任务1日志: ./logs/task1.log"
echo "  任务2日志: ./logs/task2.log"
echo "  任务3日志: ./logs/task3.log"
echo "  健康检查日志: ./logs/health.log"

echo ""
log_info "容器启动完成！"