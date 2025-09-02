#!/bin/bash

# =================================
# 定时任务动态配置脚本
# 功能：在容器运行时动态添加、删除、查看定时任务
# =================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 帮助函数
show_usage() {
    echo -e "${BLUE}定时任务管理脚本${NC}"
    echo ""
    echo "用法: $0 <命令> [参数]"
    echo ""
    echo "命令:"
    echo -e "  ${GREEN}list${NC}                    显示当前所有定时任务"
    echo -e "  ${GREEN}status${NC}                  显示cron服务状态"
    echo -e "  ${GREEN}logs${NC} <task>             查看指定任务的日志 (task1|task2|task3|cron|health)"
    echo -e "  ${GREEN}add${NC} <schedule> <task>   添加新的定时任务"
    echo -e "  ${GREEN}remove${NC} <task>           删除指定任务"
    echo -e "  ${GREEN}restart${NC}                 重启cron服务"
    echo -e "  ${GREEN}edit${NC}                    编辑crontab配置"
    echo -e "  ${GREEN}backup${NC}                  备份当前crontab配置"
    echo -e "  ${GREEN}restore${NC}                 恢复crontab配置"
    echo ""
    echo "示例:"
    echo "  $0 list"
    echo "  $0 logs task1"
    echo "  $0 add '*/5 * * * *' 'cd /app/task1 && python main.py >> /app/logs/task1.log 2>&1'"
    echo "  $0 remove task1"
    echo ""
    echo "Cron时间格式: 分钟 小时 日期 月份 星期"
    echo "  */5 * * * *   每5分钟"
    echo "  0 */2 * * *   每2小时"
    echo "  0 9 * * 1     每周一9点"
}

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查cron服务状态
check_cron_service() {
    if pgrep cron > /dev/null; then
        return 0
    else
        return 1
    fi
}

# 显示定时任务列表
list_tasks() {
    log_info "当前定时任务列表:"
    echo "========================================"
    
    if crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$"; then
        echo "========================================"
    else
        log_warn "没有找到活动的定时任务"
    fi
    
    echo ""
    log_info "cron服务状态:"
    if check_cron_service; then
        echo -e "${GREEN}✓ 运行中${NC}"
    else
        echo -e "${RED}✗ 已停止${NC}"
    fi
}

# 显示服务状态
show_status() {
    echo -e "${BLUE}=== 定时任务服务状态 ===${NC}"
    
    # Cron服务状态
    echo -n "Cron服务: "
    if check_cron_service; then
        echo -e "${GREEN}运行中${NC}"
    else
        echo -e "${RED}已停止${NC}"
    fi
    
    # 任务数量
    TASK_COUNT=$(crontab -l 2>/dev/null | grep -c "python main.py" || echo "0")
    echo "定时任务数量: $TASK_COUNT"
    
    # 日志文件状态
    echo ""
    echo -e "${BLUE}=== 日志文件状态 ===${NC}"
    for log_file in /app/logs/*.log; do
        if [ -f "$log_file" ]; then
            SIZE=$(du -h "$log_file" | cut -f1)
            LINES=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            echo "$(basename $log_file): ${SIZE}, ${LINES} 行"
        fi
    done
    
    # 磁盘使用情况
    echo ""
    echo -e "${BLUE}=== 磁盘使用情况 ===${NC}"
    df -h /app | tail -1
}

# 查看日志
view_logs() {
    local task=$1
    local log_file=""
    
    case $task in
        "task1"|"task2"|"task3")
            log_file="/app/logs/${task}.log"
            ;;
        "cron")
            log_file="/var/log/cron.log"
            ;;
        "health")
            log_file="/app/logs/health.log"
            ;;
        *)
            log_error "未知的任务名称: $task"
            echo "可用的任务: task1, task2, task3, cron, health"
            return 1
            ;;
    esac
    
    if [ -f "$log_file" ]; then
        log_info "显示 $task 的日志 (最后50行):"
        echo "========================================"
        tail -n 50 "$log_file"
        echo "========================================"
        echo ""
        echo "实时监控日志请使用: tail -f $log_file"
    else
        log_warn "日志文件不存在: $log_file"
    fi
}

# 添加定时任务
add_task() {
    local schedule="$1"
    local command="$2"
    
    if [ -z "$schedule" ] || [ -z "$command" ]; then
        log_error "请提供调度时间和命令"
        echo "用法: $0 add '<schedule>' '<command>'"
        return 1
    fi
    
    # 获取当前crontab
    crontab -l 2>/dev/null > /tmp/current_crontab || touch /tmp/current_crontab
    
    # 添加新任务
    echo "$schedule $command" >> /tmp/current_crontab
    
    # 安装新的crontab
    if crontab /tmp/current_crontab; then
        log_info "定时任务添加成功:"
        log_info "  调度: $schedule"
        log_info "  命令: $command"
    else
        log_error "定时任务添加失败"
        return 1
    fi
    
    rm -f /tmp/current_crontab
}

# 删除定时任务
remove_task() {
    local task=$1
    
    if [ -z "$task" ]; then
        log_error "请指定要删除的任务"
        echo "用法: $0 remove <task1|task2|task3>"
        return 1
    fi
    
    case $task in
        "task1"|"task2"|"task3")
            # 获取当前crontab并删除指定任务
            crontab -l 2>/dev/null | grep -v "$task" > /tmp/new_crontab || touch /tmp/new_crontab
            
            if crontab /tmp/new_crontab; then
                log_info "任务 $task 删除成功"
            else
                log_error "任务删除失败"
                return 1
            fi
            
            rm -f /tmp/new_crontab
            ;;
        *)
            log_error "未知的任务名称: $task"
            echo "可用的任务: task1, task2, task3"
            return 1
            ;;
    esac
}

# 重启cron服务
restart_cron() {
    log_info "重启cron服务..."
    
    if service cron restart; then
        sleep 2
        if check_cron_service; then
            log_info "cron服务重启成功"
        else
            log_error "cron服务重启后未能正常运行"
            return 1
        fi
    else
        log_error "cron服务重启失败"
        return 1
    fi
}

# 编辑crontab
edit_crontab() {
    log_info "当前crontab配置:"
    crontab -l 2>/dev/null || echo "# 空的crontab"
    echo ""
    log_warn "在容器环境中，建议使用其他命令来管理定时任务"
    echo "或者直接编辑宿主机上的docker-compose.yml文件"
}

# 备份crontab
backup_crontab() {
    local backup_file="/app/logs/crontab_backup_$(date +%Y%m%d_%H%M%S).txt"
    
    if crontab -l > "$backup_file" 2>/dev/null; then
        log_info "crontab配置已备份到: $backup_file"
    else
        log_warn "没有crontab配置需要备份"
    fi
}

# 恢复crontab
restore_crontab() {
    log_info "可用的备份文件:"
    ls -la /app/logs/crontab_backup_*.txt 2>/dev/null || {
        log_warn "没有找到备份文件"
        return 1
    }
    
    echo ""
    log_warn "请手动选择要恢复的备份文件并使用以下命令:"
    echo "  crontab /app/logs/crontab_backup_YYYYMMDD_HHMMSS.txt"
}

# 主程序
case "${1:-}" in
    "list")
        list_tasks
        ;;
    "status")
        show_status
        ;;
    "logs")
        view_logs "$2"
        ;;
    "add")
        add_task "$2" "$3"
        ;;
    "remove")
        remove_task "$2"
        ;;
    "restart")
        restart_cron
        ;;
    "edit")
        edit_crontab
        ;;
    "backup")
        backup_crontab
        ;;
    "restore")
        restore_crontab
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        log_error "未知命令: ${1:-}"
        echo ""
        show_usage
        exit 1
        ;;
esac