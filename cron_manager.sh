#!/bin/bash

# 定时任务管理脚本
# 使用方法：
# ./cron_manager.sh [命令]
# 命令：
#   status    - 查看定时任务状态
#   list      - 列出所有定时任务
#   add       - 添加新的定时任务
#   remove    - 移除所有定时任务
#   logs      - 查看定时任务日志
#   restart   - 重启cron服务

case "$1" in
    "status")
        echo "=== 定时任务状态 ==="
        if pgrep -x "cron" > /dev/null; then
            echo "✓ cron服务正在运行"
        else
            echo "✗ cron服务未运行"
        fi
        
        echo -e "\n=== 当前定时任务 ==="
        crontab -l 2>/dev/null || echo "没有配置定时任务"
        ;;
        
    "list")
        echo "=== 所有定时任务 ==="
        crontab -l 2>/dev/null || echo "没有配置定时任务"
        ;;
        
    "add")
        echo "=== 添加定时任务 ==="
        echo "请输入定时任务表达式（格式：分钟 小时 日期 月份 星期）："
        echo "示例："
        echo "  0 2 * * *     - 每天凌晨2点"
        echo "  0 */2 * * *   - 每2小时"
        echo "  */30 * * * *  - 每30分钟"
        echo "  0 9 * * 1     - 每周一早上9点"
        echo ""
        read -p "请输入表达式: " schedule
        
        if [ -n "$schedule" ]; then
            # 添加到现有crontab
            (crontab -l 2>/dev/null; echo "$schedule cd /app/src && python main.py >> /app/data/cron.log 2>&1") | crontab -
            echo "定时任务已添加：$schedule"
        else
            echo "表达式不能为空"
        fi
        ;;
        
    "remove")
        echo "=== 移除所有定时任务 ==="
        read -p "确定要移除所有定时任务吗？(y/N): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            crontab -r
            echo "所有定时任务已移除"
        else
            echo "操作已取消"
        fi
        ;;
        
    "logs")
        echo "=== 定时任务日志 ==="
        if [ -f "/app/data/cron.log" ]; then
            tail -50 /app/data/cron.log
        else
            echo "日志文件不存在：/app/data/cron.log"
        fi
        ;;
        
    "restart")
        echo "=== 重启cron服务 ==="
        service cron restart
        echo "cron服务已重启"
        ;;
        
    *)
        echo "定时任务管理脚本"
        echo ""
        echo "使用方法："
        echo "  $0 [命令]"
        echo ""
        echo "可用命令："
        echo "  status    - 查看定时任务状态"
        echo "  list      - 列出所有定时任务"
        echo "  add       - 添加新的定时任务"
        echo "  remove    - 移除所有定时任务"
        echo "  logs      - 查看定时任务日志"
        echo "  restart   - 重启cron服务"
        echo ""
        echo "示例："
        echo "  $0 status    # 查看状态"
        echo "  $0 add       # 添加任务"
        echo "  $0 logs      # 查看日志"
        ;;
esac 