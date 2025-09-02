#!/bin/bash

# =================================
# 项目快速添加工具
# 功能：交互式创建新项目和setup.sh配置
# 作者：Qoder AI
# 版本：1.0.1
# =================================

set -e

# 调试模式
DEBUG_MODE=${DEBUG_MODE:-false}

# 调试输出函数
debug_log() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "[DEBUG] $1" >&2
    fi
}

# 检查终端环境
check_terminal() {
    debug_log "检查终端环境..."
    debug_log "TTY: $(tty 2>/dev/null || echo 'not available')"
    debug_log "TERM: ${TERM:-not set}"
    debug_log "Interactive: $([[ -t 0 ]] && echo 'yes' || echo 'no')"
    
    # 检查是否在交互式终端中
    if [[ ! -t 0 ]]; then
        log_warn "警告：检测到非交互式终端，可能影响用户输入"
        log_info "建议使用: docker exec -it <container> bash"
    fi
}

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_question() {
    echo -e "${CYAN}[?]${NC} $1"
}

# 配置路径
PROJECTS_ROOT="/app"
TEMPLATE_PATH="/app/scripts/setup_template.sh"

# 检查项目状态
check_project_status() {
    local project_name="$1"
    local project_dir="$PROJECTS_ROOT/$project_name"
    local setup_file="$project_dir/setup.sh"
    
    debug_log "检查项目 $project_name 的状态"
    debug_log "项目目录: $project_dir"
    debug_log "setup文件: $setup_file"
    
    if [[ ! -d "$project_dir" ]]; then
        debug_log "项目目录不存在"
        echo "not_exists"  # 目录不存在
        return 0
    fi
    
    if [[ ! -f "$setup_file" ]]; then
        debug_log "setup.sh文件不存在"
        echo "unconfigured"  # 目录存在但未配置
        return 0
    fi
    
    # 检查是否已注册到系统（检查crontab）
    if crontab -l 2>/dev/null | grep -q "# PROJECT: $project_name"; then
        debug_log "在crontab中找到项目 $project_name"
        echo "registered"  # 已注册
    else
        debug_log "在crontab中未找到项目 $project_name"
        echo "configured"  # 已配置但未注册
    fi
}

# 验证项目名称
validate_project_name() {
    local project_name="$1"
    
    # 检查是否为空
    if [[ -z "$project_name" ]]; then
        return 1
    fi
    
    # 检查是否包含无效字符
    if [[ ! "$project_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    
    # 检查是否为系统保留名称
    local reserved_names=("logs" "scripts" "data" "backup" "system" "config")
    for reserved in "${reserved_names[@]}"; do
        if [[ "$project_name" == "$reserved" ]]; then
            return 1
        fi
    done
    
    return 0
}

# 交互式获取项目信息
get_project_info() {
    local project_name project_type cron_schedule cron_command service_command restart_policy
    
    # 检查终端环境
    check_terminal
    
    echo
    log_info "=== 项目快速添加向导 ==="
    echo
    
    # 获取项目名称
    while true; do
        debug_log "准备读取项目名称输入"
        log_question "请输入项目名称 (只能包含字母、数字、下划线和短横线):"
        
        # 尝试多种读取方式
        if [[ -t 0 ]]; then
            # 交互式终端
            read -p "项目名称: " -r project_name
        else
            # 非交互式，使用 echo 提示
            echo -n "项目名称: "
            read -r project_name
        fi
        
        debug_log "读取到的项目名称: '$project_name'"
        
        # 处理空输入
        if [[ -z "$project_name" ]]; then
            log_warn "项目名称不能为空，请重新输入"
            continue
        fi
        
        if validate_project_name "$project_name"; then
            # 检查项目状态
            local project_status=$(check_project_status "$project_name")
            debug_log "项目 $project_name 状态: $project_status"
            
            case "$project_status" in
                "not_exists")
                    log_info "项目 '$project_name' 不存在，将创建新项目"
                    break
                    ;;
                "unconfigured")
                    log_warn "目录 '$project_name' 已存在但未配置，将为其添加配置文件"
                    break
                    ;;
                "configured")
                    log_warn "项目 '$project_name' 已配置但未注册，将重新配置"
                    break
                    ;;
                "registered")
                    log_error "项目 '$project_name' 已存在并已注册，请选择其他名称"
                    continue
                    ;;
            esac
        else
            log_error "无效的项目名称，请重新输入"
        fi
    done
    
    # 获取项目类型
    echo
    log_question "请选择项目类型:"
    echo "  1) cron    - 定时任务"
    echo "  2) service - 后台服务"
    while true; do
        debug_log "准备读取项目类型选择"
        
        if [[ -t 0 ]]; then
            read -p "选择 (1/2): " -r choice
        else
            echo -n "选择 (1/2): "
            read -r choice
        fi
        
        debug_log "读取到的选择: '$choice'"
        
        case "$choice" in
            1|"cron")
                project_type="cron"
                debug_log "设置项目类型为: cron"
                break
                ;;
            2|"service")
                project_type="service"
                debug_log "设置项目类型为: service"
                break
                ;;
            "")
                log_warn "请输入选择"
                ;;
            *)
                log_error "无效选项，请输入 1 或 2"
                ;;
        esac
    done
    
    # 根据项目类型获取相应配置
    if [[ "$project_type" == "cron" ]]; then
        echo
        log_info "定时任务调度示例："
        echo "  */5 * * * *     - 每5分钟执行"
        echo "  0 */2 * * *     - 每2小时执行"
        echo "  0 9 * * 1-5     - 周一到周五上午9点"
        echo "  30 2 * * 0      - 每周日凌晨2:30"
        echo
        log_question "请输入cron调度表达式 (默认: 0 */2 * * *):"
        echo -n "cron表达式: "
        read -r cron_schedule
        cron_schedule="${cron_schedule:-"0 */2 * * *"}"
        
        echo
        log_question "请输入执行命令 (默认: cd /app/$project_name && python3 main.py):"
        echo -n "执行命令: "
        read -r cron_command
        cron_command="${cron_command:-"cd /app/$project_name && python3 main.py"}"
        
    elif [[ "$project_type" == "service" ]]; then
        echo
        log_question "请输入服务启动命令 (默认: cd /app/$project_name && python3 service.py):"
        echo -n "启动命令: "
        read -r service_command
        service_command="${service_command:-"cd /app/$project_name && python3 service.py"}"
        
        echo
        log_question "请选择重启策略:"
        echo "  1) always     - 总是重启"
        echo "  2) on-failure - 仅异常时重启"
        echo "  3) never      - 不自动重启"
        while true; do
            log_question "请输入选项 (1、2 或 3，默认: 1):"
            echo -n "重启策略 (1/2/3): "
            read -r restart_choice
            restart_choice="${restart_choice:-1}"
            case "$restart_choice" in
                1|"always")
                    restart_policy="always"
                    break
                    ;;
                2|"on-failure")
                    restart_policy="on-failure"
                    break
                    ;;
                3|"never")
                    restart_policy="never"
                    break
                    ;;
                *)
                    log_error "无效选项，请输入 1、2 或 3"
                    ;;
            esac
        done
    fi
    
    # 设置全局变量而不是返回字符串
    INTERACTIVE_PROJECT_NAME="$project_name"
    INTERACTIVE_PROJECT_TYPE="$project_type"
    INTERACTIVE_CRON_SCHEDULE="$cron_schedule"
    INTERACTIVE_CRON_COMMAND="$cron_command"
    INTERACTIVE_SERVICE_COMMAND="$service_command"
    INTERACTIVE_SERVICE_RESTART_POLICY="$restart_policy"
}

# 创建项目目录和文件
create_project() {
    local project_config="$1"
    
    # 解析配置
    local PROJECT_NAME PROJECT_TYPE CRON_SCHEDULE CRON_COMMAND SERVICE_COMMAND SERVICE_RESTART_POLICY
    eval "$project_config"
    
    local project_dir="$PROJECTS_ROOT/$PROJECT_NAME"
    
    # 检查目录是否已存在
    if [[ -d "$project_dir" ]]; then
        log_info "使用现有项目: $project_dir"
    else
        log_info "创建项目目录: $project_dir"
        mkdir -p "$project_dir"
    fi
    
    # 创建setup.sh文件
    local setup_file="$project_dir/setup.sh"
    log_info "生成setup.sh配置文件..."
    
    cat > "$setup_file" << EOF
#!/bin/bash

# =================================
# 项目配置脚本: $PROJECT_NAME
# 生成时间: $(date)
# 项目类型: $PROJECT_TYPE
# =================================

# 基本项目信息
PROJECT_NAME="$PROJECT_NAME"
PROJECT_TYPE="$PROJECT_TYPE"
EOF
    
    # 根据项目类型添加相应配置
    if [[ "$PROJECT_TYPE" == "cron" ]]; then
        cat >> "$setup_file" << EOF

# 定时任务配置
CRON_SCHEDULE="$CRON_SCHEDULE"
CRON_COMMAND="$CRON_COMMAND"
EOF
    elif [[ "$PROJECT_TYPE" == "service" ]]; then
        cat >> "$setup_file" << EOF

# 后台服务配置
SERVICE_COMMAND="$SERVICE_COMMAND"
SERVICE_RESTART_POLICY="$SERVICE_RESTART_POLICY"
EOF
    fi
    
    # 添加可选函数模板
    cat >> "$setup_file" << 'EOF'

# 依赖检查函数 (可选)
check_dependencies() {
    echo "检查项目依赖..."
    
    # 示例：检查主程序文件
    if [[ ! -f "main.py" ]] && [[ ! -f "service.py" ]] && [[ ! -f "app.py" ]]; then
        echo "警告：未找到主程序文件 (main.py, service.py, app.py)"
    fi
    
    # 示例：检查Python包依赖
    # python3 -c "import requests" 2>/dev/null || {
    #     echo "错误：缺少 requests 包"
    #     return 1
    # }
    
    echo "依赖检查通过"
    return 0
}

# 项目初始化函数 (可选)
initialize() {
    echo "初始化项目: $PROJECT_NAME"
    
    # 示例：创建必要目录
    mkdir -p data logs temp 2>/dev/null || true
    
    # 示例：设置权限
    chmod 755 . 2>/dev/null || true
    
    echo "初始化完成"
    return 0
}

# 项目清理函数 (可选)
cleanup() {
    echo "清理项目: $PROJECT_NAME"
    
    # 示例：清理临时文件
    rm -rf temp/* 2>/dev/null || true
    
    echo "清理完成"
    return 0
}
EOF
    
    # 设置执行权限
    chmod +x "$setup_file"
    
    # 创建示例程序文件
    if [[ "$PROJECT_TYPE" == "cron" ]]; then
        create_example_cron_script "$project_dir" "$PROJECT_NAME"
    elif [[ "$PROJECT_TYPE" == "service" ]]; then
        create_example_service_script "$project_dir" "$PROJECT_NAME"
    fi
    
    log_success "项目 '$PROJECT_NAME' 创建完成"
    echo "  项目目录: $project_dir"
    echo "  配置文件: $setup_file"
    
    return 0
}

# 创建示例定时任务脚本
create_example_cron_script() {
    local project_dir="$1"
    local project_name="$2"
    local main_file="$project_dir/main.py"
    
    log_info "创建示例Python脚本: main.py"
    
    cat > "$main_file" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
示例定时任务脚本: $project_name
生成时间: $(date)
"""

import os
import sys
import time
from datetime import datetime

def main():
    """主执行函数"""
    print(f"[{datetime.now()}] $project_name 定时任务开始执行")
    
    try:
        # 在此处添加你的业务逻辑
        print("执行业务逻辑...")
        
        # 示例：处理一些数据
        process_data()
        
        print(f"[{datetime.now()}] $project_name 定时任务执行完成")
        
    except Exception as e:
        print(f"[{datetime.now()}] 错误：{e}")
        sys.exit(1)

def process_data():
    """示例数据处理函数"""
    # 模拟一些处理时间
    time.sleep(2)
    
    # 示例：写入一些数据到文件
    data_dir = "data"
    os.makedirs(data_dir, exist_ok=True)
    
    with open(f"{data_dir}/output.txt", "a", encoding="utf-8") as f:
        f.write(f"{datetime.now()}: $project_name 任务执行记录\\n")
    
    print("数据处理完成")

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "$main_file"
}

# 创建示例后台服务脚本
create_example_service_script() {
    local project_dir="$1"
    local project_name="$2"
    local service_file="$project_dir/service.py"
    
    log_info "创建示例Python服务: service.py"
    
    cat > "$service_file" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
示例后台服务脚本: $project_name
生成时间: $(date)
"""

import os
import sys
import time
import signal
from datetime import datetime

class ServiceManager:
    """服务管理器"""
    
    def __init__(self):
        self.running = True
        self.setup_signal_handlers()
    
    def setup_signal_handlers(self):
        """设置信号处理器"""
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        """信号处理函数"""
        print(f"[{datetime.now()}] 收到信号 {signum}，准备优雅关闭...")
        self.running = False
    
    def run(self):
        """主服务循环"""
        print(f"[{datetime.now()}] $project_name 后台服务启动")
        
        try:
            while self.running:
                # 在此处添加你的服务逻辑
                self.process_task()
                
                # 休眠一段时间
                time.sleep(10)
            
        except Exception as e:
            print(f"[{datetime.now()}] 服务异常：{e}")
            sys.exit(1)
        
        print(f"[{datetime.now()}] $project_name 后台服务已关闭")
    
    def process_task(self):
        """处理任务"""
        print(f"[{datetime.now()}] 处理任务中...")
        
        # 示例：写入心跳记录
        log_dir = "logs"
        os.makedirs(log_dir, exist_ok=True)
        
        with open(f"{log_dir}/heartbeat.log", "a", encoding="utf-8") as f:
            f.write(f"{datetime.now()}: $project_name 服务心跳\\n")

def main():
    """主函数"""
    service = ServiceManager()
    service.run()

if __name__ == "__main__":
    main()
EOF
    
    chmod +x "$service_file"
}

# 注册项目到系统
register_project() {
    local project_name="$1"
    
    log_info "注册项目到系统..."
    
    # 使用项目管理器注册
    if [[ -f "/app/scripts/project_manager.sh" ]]; then
        if /app/scripts/project_manager.sh add "$project_name"; then
            log_success "项目注册成功"
            return 0
        else
            log_error "项目注册失败"
            return 1
        fi
    else
        log_error "项目管理器脚本不存在"
        return 1
    fi
}

# 快速添加项目 (非交互式)
quick_add() {
    local project_name="$1"
    local project_type="$2"
    local schedule_or_command="$3"
    
    if [[ -z "$project_name" ]]; then
        log_error "请提供项目名称"
        return 1
    fi
    
    if ! validate_project_name "$project_name"; then
        log_error "无效的项目名称: $project_name"
        return 1
    fi
    
    # 检查项目状态
    if [[ -d "$PROJECTS_ROOT/$project_name" ]]; then
        if [[ -f "$PROJECTS_ROOT/$project_name/setup.sh" ]]; then
            log_error "项目 '$project_name' 已存在并已配置"
            return 1
        else
            log_warn "目录 '$project_name' 已存在但未配置，将为其添加配置文件"
        fi
    fi
    
    # 设置默认值
    project_type="${project_type:-cron}"
    
    local project_config
    if [[ "$project_type" == "cron" ]]; then
        local cron_schedule="${schedule_or_command:-"0 */2 * * *"}"
        local cron_command="cd /app/$project_name && python3 main.py"
        project_config="PROJECT_NAME='$project_name'
PROJECT_TYPE='cron'
CRON_SCHEDULE='$cron_schedule'
CRON_COMMAND='$cron_command'"
    elif [[ "$project_type" == "service" ]]; then
        local service_command="${schedule_or_command:-"cd /app/$project_name && python3 service.py"}"
        project_config="PROJECT_NAME='$project_name'
PROJECT_TYPE='service'
SERVICE_COMMAND='$service_command'
SERVICE_RESTART_POLICY='always'"
    else
        log_error "不支持的项目类型: $project_type"
        return 1
    fi
    
    # 创建项目
    if create_project "$project_config"; then
        # 注册项目
        if register_project "$project_name"; then
            log_success "项目 '$project_name' 快速添加完成"
        else
            log_warn "项目创建成功，但注册失败，请手动注册"
        fi
    else
        log_error "项目创建失败"
        return 1
    fi
}

# 列出项目及状态
list_projects_status() {
    log_info "项目状态列表:"
    echo
    
    local found_projects=false
    for project_dir in "$PROJECTS_ROOT"/*/; do
        if [[ -d "$project_dir" ]]; then
            local project_name=$(basename "$project_dir")
            
            # 跳过系统目录
            if [[ "$project_name" =~ ^(logs|scripts|data|backup)$ ]]; then
                continue
            fi
            
            local status=$(check_project_status "$project_name")
            local status_desc
            
            case "$status" in
                "not_exists")
                    status_desc="不存在"
                    ;;
                "unconfigured")
                    status_desc="未配置 (可以添加配置)"
                    ;;
                "configured")
                    status_desc="已配置 (未注册)"
                    ;;
                "registered")
                    status_desc="已注册 (正常运行)"
                    ;;
            esac
            
            echo "  - $project_name: $status_desc"
            found_projects=true
        fi
    done
    
    if [[ "$found_projects" == "false" ]]; then
        echo "  (暂无项目)"
    fi
    
    echo
    log_info "说明:"
    echo "  - 未配置: 可以使用 add_project.sh 添加配置"
    echo "  - 已配置: 可以使用 project_manager.sh add <name> 注册"
    echo "  - 已注册: 项目正在系统中运行"
}

# 显示帮助信息
show_help() {
    cat << EOF
项目快速添加工具 v1.0.1

用法: $0 <command> [options]

命令:
  interactive                          交互式添加项目
  quick <name> [type] [schedule/cmd]   快速添加项目
  list                                 列出现有项目状态
  help                                 显示帮助信息

交互式添加:
  $0 interactive
  DEBUG_MODE=true $0 interactive       # 开启调试模式

快速添加示例:
  $0 quick task5                              # 创建默认定时任务
  $0 quick task6 cron "*/10 * * * *"          # 创建每10分钟执行的定时任务
  $0 quick monitor service                     # 创建后台服务
  $0 quick api_service service "cd /app/api_service && python3 server.py"

调试模式:
  如果交互式模式没有响应，请使用:
  DEBUG_MODE=true $0 interactive

说明:
  - 项目名称只能包含字母、数字、下划线和短横线
  - 避免使用系统保留名称: logs, scripts, data, backup
  - 创建后会自动生成示例代码和setup.sh配置文件
  - 项目会自动注册到系统中

更多信息请查看项目文档。
EOF
}

# 主函数
main() {
    local command="$1"
    shift || true
    
    case "$command" in
        "interactive"|"")
            # 交互式添加
            debug_log "开始交互式模式"
            
            # 调用交互式获取信息
            get_project_info
            
            # 使用全局变量构建配置
            local project_config="PROJECT_NAME='$INTERACTIVE_PROJECT_NAME'
PROJECT_TYPE='$INTERACTIVE_PROJECT_TYPE'
CRON_SCHEDULE='$INTERACTIVE_CRON_SCHEDULE'
CRON_COMMAND='$INTERACTIVE_CRON_COMMAND'
SERVICE_COMMAND='$INTERACTIVE_SERVICE_COMMAND'
SERVICE_RESTART_POLICY='$INTERACTIVE_SERVICE_RESTART_POLICY'"
            
            echo
            log_info "=== 项目配置确认 ==="
            
            echo "项目名称: $INTERACTIVE_PROJECT_NAME"
            echo "项目类型: $INTERACTIVE_PROJECT_TYPE"
            
            if [[ "$INTERACTIVE_PROJECT_TYPE" == "cron" ]]; then
                echo "调度规则: $INTERACTIVE_CRON_SCHEDULE"
                echo "执行命令: $INTERACTIVE_CRON_COMMAND"
            elif [[ "$INTERACTIVE_PROJECT_TYPE" == "service" ]]; then
                echo "启动命令: $INTERACTIVE_SERVICE_COMMAND"
                echo "重启策略: $INTERACTIVE_SERVICE_RESTART_POLICY"
            fi
            
            echo
            log_question "确认创建项目? (y/N):"
            echo -n "确认 (y/N): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                if create_project "$project_config"; then
                    echo
                    log_question "是否立即注册项目到系统? (Y/n):"
                    echo -n "注册 (Y/n): "
                    read -r register_now
                    if [[ ! "$register_now" =~ ^[Nn]$ ]]; then
                        register_project "$INTERACTIVE_PROJECT_NAME"
                    fi
                fi
            else
                log_info "操作已取消"
            fi
            ;;
        "quick")
            local project_name="$1"
            local project_type="$2"
            local schedule_or_command="$3"
            quick_add "$project_name" "$project_type" "$schedule_or_command"
            ;;
        "list")
            list_projects_status
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            echo
            show_help
            return 1
            ;;
    esac
}

# 执行主函数
main "$@"