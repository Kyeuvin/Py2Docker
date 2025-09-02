#!/bin/bash

# =================================
# 状态查看脚本
# 功能：显示容器和定时任务的详细状态
# =================================

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
echo -e "Docker定时任务容器状态查看"
echo -e "========================================${NC}"

# 1. 检查容器状态
echo -e "${BLUE}=== 容器状态 ===${NC}"
if docker ps --filter "name=cron-tasks" | grep -q cron-tasks; then
    log_info "容器正在运行"
    docker ps --filter "name=cron-tasks" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
elif docker ps -a --filter "name=cron-tasks" | grep -q cron-tasks; then
    log_warn "容器存在但未运行"
    docker ps -a --filter "name=cron-tasks" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
else
    log_error "容器不存在"
fi

echo ""

# 2. 检查健康状态
echo -e "${BLUE}=== 健康检查 ===${NC}"
if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
    # 获取健康状态
    HEALTH_STATUS=$(docker inspect cron-tasks --format='{{.State.Health.Status}}' 2>/dev/null || echo "无健康检查")
    
    case $HEALTH_STATUS in
        "healthy")
            echo -e "${GREEN}✓ 健康状态: 正常${NC}"
            ;;
        "unhealthy")
            echo -e "${RED}✗ 健康状态: 异常${NC}"
            ;;
        "starting")
            echo -e "${YELLOW}⏳ 健康状态: 启动中${NC}"
            ;;
        *)
            echo -e "${YELLOW}? 健康状态: $HEALTH_STATUS${NC}"
            ;;
    esac
    
    # 运行健康检查脚本
    echo ""
    log_info "执行详细健康检查..."
    docker exec cron-tasks /app/scripts/health_check.sh 2>/dev/null || log_warn "健康检查脚本执行失败"
else
    log_warn "容器未运行，无法检查健康状态"
fi

echo ""

# 3. 显示定时任务
echo -e "${BLUE}=== 定时任务列表 ===${NC}"
if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
    docker exec cron-tasks crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" || log_warn "没有找到活动的定时任务"
else
    log_warn "容器未运行，无法查看定时任务"
fi

echo ""

# 4. 显示资源使用情况
echo -e "${BLUE}=== 资源使用情况 ===${NC}"
if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
    docker stats cron-tasks --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
else
    log_warn "容器未运行，无法查看资源使用情况"
fi

echo ""

# 5. 显示日志文件状态
echo -e "${BLUE}=== 日志文件状态 ===${NC}"
if [ -d "./logs" ]; then
    for log_file in ./logs/*.log; do
        if [ -f "$log_file" ]; then
            SIZE=$(du -h "$log_file" 2>/dev/null | cut -f1)
            LINES=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            LAST_MODIFIED=$(stat -c %y "$log_file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1 || echo "未知")
            echo "$(basename $log_file): ${SIZE}, ${LINES} 行, 最后修改: ${LAST_MODIFIED}"
        fi
    done
else
    log_warn "日志目录不存在: ./logs"
fi

echo ""

# 6. 显示最近的日志条目
echo -e "${BLUE}=== 最近的任务执行记录 ===${NC}"
for task in task1 task2 task3; do
    log_file="./logs/${task}.log"
    if [ -f "$log_file" ] && [ -s "$log_file" ]; then
        echo -e "${GREEN}${task}${NC} (最后3行):"
        tail -n 3 "$log_file" 2>/dev/null | sed 's/^/  /' || echo "  无法读取日志"
    else
        echo -e "${YELLOW}${task}${NC}: 日志文件为空或不存在"
    fi
done

echo ""

# 7. 显示容器日志摘要
echo -e "${BLUE}=== 容器日志摘要 ===${NC}"
if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
    log_info "容器日志 (最后10行):"
    docker logs cron-tasks --tail 10 2>/dev/null | sed 's/^/  /' || log_warn "无法获取容器日志"
else
    log_warn "容器未运行，无法查看容器日志"
fi

echo ""

# 8. 显示实用命令
echo -e "${BLUE}=== 实用命令 ===${NC}"
echo "容器管理:"
echo "  启动: ./start.sh"
echo "  停止: ./stop.sh"
echo "  重启: ./restart.sh"
echo ""
echo "日志查看:"
echo "  实时日志: docker logs -f cron-tasks"
echo "  任务日志: tail -f ./logs/task1.log"
echo "  健康日志: tail -f ./logs/health.log"
echo ""
echo "容器操作:"
echo "  进入容器: docker exec -it cron-tasks bash"
echo "  查看定时任务: docker exec cron-tasks crontab -l"
echo "  管理任务: docker exec cron-tasks /app/scripts/setup_cron.sh"

echo ""
echo -e "${BLUE}========================================"
echo -e "状态查看完成"
echo -e "========================================${NC}"