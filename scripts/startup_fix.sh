#!/bin/bash

# =================================
# 启动后验证和修复脚本
# 功能：检查容器启动后的定时任务状态并自动修复
# =================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

log_info "=== 容器启动后验证和修复 ==="

# 检查cron服务状态
log_info "检查cron服务状态..."
if pgrep cron > /dev/null; then
    log_info "✓ cron服务正在运行"
else
    log_error "✗ cron服务未运行，尝试启动..."
    service cron start
    sleep 2
    if pgrep cron > /dev/null; then
        log_info "✓ cron服务启动成功"
    else
        log_error "✗ cron服务启动失败"
        exit 1
    fi
fi

# 检查crontab配置
log_info "检查crontab配置..."
cron_count=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -v "^SHELL\|^PATH\|^HOME\|^PYTHON" | wc -l)

if [[ $cron_count -eq 0 ]]; then
    log_warn "✗ 没有发现任何定时任务，开始自动修复..."
    
    # 重新设置基础环境变量
    log_info "设置基础crontab环境变量..."
    cat > /tmp/crontab_base << EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
HOME=/root
PYTHONUNBUFFERED=1

EOF
    crontab /tmp/crontab_base
    
    # 扫描并注册所有项目
    log_info "扫描并注册项目..."
    if [[ -f "/app/scripts/project_manager.sh" ]]; then
        chmod +x /app/scripts/project_manager.sh
        /app/scripts/project_manager.sh scan
    else
        # 备用方案：直接注册发现的项目
        log_info "使用备用注册方案..."
        if [[ -f "/app/scripts/simple_register.sh" ]]; then
            chmod +x /app/scripts/simple_register.sh
            for project_dir in /app/*/; do
                if [[ -d "$project_dir" ]]; then
                    project_name=$(basename "$project_dir")
                    if [[ "$project_name" =~ ^(logs|scripts|data|backup)$ ]]; then
                        continue
                    fi
                    if [[ -f "$project_dir/setup.sh" ]]; then
                        log_info "注册项目: $project_name"
                        /app/scripts/simple_register.sh "$project_name" || log_warn "项目 $project_name 注册失败"
                    fi
                fi
            done
        fi
    fi
    
    # 重新检查
    new_cron_count=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | grep -v "^SHELL\|^PATH\|^HOME\|^PYTHON" | wc -l)
    if [[ $new_cron_count -gt 0 ]]; then
        log_info "✓ 修复成功，注册了 $new_cron_count 个定时任务"
    else
        log_warn "✗ 修复失败，未能注册任何定时任务"
    fi
else
    log_info "✓ 发现 $cron_count 个定时任务，配置正常"
fi

# 显示当前配置
log_info "当前crontab配置："
crontab -l 2>/dev/null || log_warn "无法读取crontab配置"

log_info "=== 验证和修复完成 ==="