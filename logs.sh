#!/bin/bash

# =================================
# 日志查看脚本
# 功能：方便查看各种日志文件
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

show_usage() {
    echo -e "${BLUE}日志查看脚本${NC}"
    echo ""
    echo "用法: $0 [选项] [任务名称]"
    echo ""
    echo "任务名称:"
    echo -e "  ${GREEN}task1${NC}      查看任务1日志"
    echo -e "  ${GREEN}task2${NC}      查看任务2日志"
    echo -e "  ${GREEN}task3${NC}      查看任务3日志"
    echo -e "  ${GREEN}health${NC}     查看健康检查日志"
    echo -e "  ${GREEN}container${NC}  查看容器日志"
    echo -e "  ${GREEN}all${NC}        查看所有日志摘要"
    echo ""
    echo "选项:"
    echo -e "  ${GREEN}-f, --follow${NC}   实时跟踪日志"
    echo -e "  ${GREEN}-n, --lines${NC}    显示最后N行 (默认50)"
    echo -e "  ${GREEN}-h, --help${NC}     显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 task1           # 查看任务1最后50行日志"
    echo "  $0 -f task2        # 实时跟踪任务2日志"
    echo "  $0 -n 100 task3    # 查看任务3最后100行日志"
    echo "  $0 all             # 查看所有日志摘要"
}

# 参数解析
FOLLOW=false
LINES=50
TASK=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            TASK="$1"
            shift
            ;;
    esac
done

# 如果没有指定任务，显示菜单
if [ -z "$TASK" ]; then
    echo -e "${BLUE}请选择要查看的日志:${NC}"
    echo "1) task1 - 任务1日志"
    echo "2) task2 - 任务2日志"
    echo "3) task3 - 任务3日志"
    echo "4) health - 健康检查日志"
    echo "5) container - 容器日志"
    echo "6) all - 所有日志摘要"
    echo ""
    read -p "请输入选择 (1-6): " choice
    
    case $choice in
        1) TASK="task1" ;;
        2) TASK="task2" ;;
        3) TASK="task3" ;;
        4) TASK="health" ;;
        5) TASK="container" ;;
        6) TASK="all" ;;
        *) log_error "无效选择"; exit 1 ;;
    esac
fi

# 显示所有日志摘要
show_all_logs() {
    echo -e "${BLUE}========================================"
    echo -e "所有日志摘要"
    echo -e "========================================${NC}"
    
    # 任务日志
    for task in task1 task2 task3; do
        log_file="./logs/${task}.log"
        echo -e "${GREEN}=== ${task} 日志 (最后5行) ===${NC}"
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            tail -n 5 "$log_file" | sed 's/^/  /'
        else
            echo "  日志文件为空或不存在"
        fi
        echo ""
    done
    
    # 健康检查日志
    echo -e "${GREEN}=== 健康检查日志 (最后5行) ===${NC}"
    health_log="./logs/health.log"
    if [ -f "$health_log" ] && [ -s "$health_log" ]; then
        tail -n 5 "$health_log" | sed 's/^/  /'
    else
        echo "  健康检查日志为空或不存在"
    fi
    echo ""
    
    # 容器日志
    echo -e "${GREEN}=== 容器日志 (最后5行) ===${NC}"
    if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
        docker logs cron-tasks --tail 5 2>/dev/null | sed 's/^/  /' || echo "  无法获取容器日志"
    else
        echo "  容器未运行"
    fi
}

# 查看单个日志
view_single_log() {
    local task=$1
    local log_file=""
    local log_name=""
    
    case $task in
        "task1"|"task2"|"task3")
            log_file="./logs/${task}.log"
            log_name="任务 $task"
            ;;
        "health")
            log_file="./logs/health.log"
            log_name="健康检查"
            ;;
        "container")
            # 容器日志特殊处理
            if docker ps --filter "name=cron-tasks" --filter "status=running" | grep -q cron-tasks; then
                if [ "$FOLLOW" = true ]; then
                    log_info "实时跟踪容器日志 (Ctrl+C 退出)..."
                    docker logs -f cron-tasks
                else
                    log_info "容器日志 (最后 $LINES 行):"
                    docker logs cron-tasks --tail "$LINES"
                fi
            else
                log_error "容器未运行"
                exit 1
            fi
            return
            ;;
        *)
            log_error "未知的任务名称: $task"
            show_usage
            exit 1
            ;;
    esac
    
    # 检查日志文件
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        exit 1
    fi
    
    if [ ! -s "$log_file" ]; then
        log_warn "日志文件为空: $log_file"
        exit 0
    fi
    
    # 显示日志
    if [ "$FOLLOW" = true ]; then
        log_info "实时跟踪 $log_name 日志 (Ctrl+C 退出)..."
        tail -f "$log_file"
    else
        log_info "$log_name 日志 (最后 $LINES 行):"
        echo "========================================"
        tail -n "$LINES" "$log_file"
        echo "========================================"
        
        # 显示文件信息
        echo ""
        file_size=$(du -h "$log_file" | cut -f1)
        file_lines=$(wc -l < "$log_file")
        file_modified=$(stat -c %y "$log_file" 2>/dev/null | cut -d'.' -f1 || echo "未知")
        echo -e "${BLUE}文件信息:${NC}"
        echo "  大小: $file_size"
        echo "  行数: $file_lines"
        echo "  最后修改: $file_modified"
        echo ""
        echo -e "${BLUE}实时跟踪:${NC} $0 -f $task"
    fi
}

# 主逻辑
case $TASK in
    "all")
        show_all_logs
        ;;
    *)
        view_single_log "$TASK"
        ;;
esac