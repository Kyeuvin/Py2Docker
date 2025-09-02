#!/bin/bash

# 定时任务诊断脚本

echo "=== 定时任务诊断报告 ==="
echo "时间: $(date)"
echo

echo "1. Cron服务状态："
if pgrep cron > /dev/null; then
    echo "  ✓ Cron服务正在运行 (PID: $(pgrep cron))"
else
    echo "  ✗ Cron服务未运行"
fi
echo

echo "2. 当前Crontab配置："
if crontab -l 2>/dev/null | wc -l | grep -q "^0$"; then
    echo "  ✗ 没有配置任何定时任务"
else
    echo "  ✓ 发现 $(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l) 个定时任务"
    echo "  详细配置:"
    crontab -l 2>/dev/null | nl -ba
fi
echo

echo "3. 项目状态检查："
for project_dir in /app/*/; do
    if [[ -d "$project_dir" ]]; then
        project_name=$(basename "$project_dir")
        
        # 跳过系统目录
        if [[ "$project_name" =~ ^(logs|scripts|data|backup)$ ]]; then
            continue
        fi
        
        echo "  项目: $project_name"
        
        # 检查setup.sh
        if [[ -f "$project_dir/setup.sh" ]]; then
            echo "    ✓ setup.sh 存在"
            
            # 检查主程序文件
            if [[ -f "$project_dir/main.py" ]]; then
                echo "    ✓ main.py 存在"
            else
                echo "    ✗ main.py 不存在"
            fi
            
            # 检查是否在crontab中
            if crontab -l 2>/dev/null | grep -q "# PROJECT: $project_name"; then
                echo "    ✓ 已注册到crontab"
                # 显示具体的cron条目
                echo "    配置: $(crontab -l 2>/dev/null | grep -A1 "# PROJECT: $project_name" | tail -1)"
            else
                echo "    ✗ 未注册到crontab"
            fi
        else
            echo "    ✗ setup.sh 不存在"
        fi
        echo
    fi
done

echo "4. 最近的日志检查："
if [[ -d "/app/logs/projects" ]]; then
    echo "  项目日志目录存在"
    for log_file in /app/logs/projects/*.log; do
        if [[ -f "$log_file" ]]; then
            log_name=$(basename "$log_file" .log)
            echo "    $log_name: $(wc -l < "$log_file") 行"
            echo "      最后更新: $(stat -c %y "$log_file")"
            if [[ -s "$log_file" ]]; then
                echo "      最后几行:"
                tail -3 "$log_file" | sed 's/^/        /'
            fi
            echo
        fi
    done
else
    echo "  ✗ 项目日志目录不存在"
fi

echo "5. 建议操作："
echo "  - 如果cron服务未运行: service cron start"
echo "  - 如果项目未注册: ./project_manager.sh add <project_name>"
echo "  - 查看项目日志: tail -f /app/logs/projects/<project_name>.log"
echo "  - 手动测试脚本: cd /app/<project_name> && python3 main.py"

echo
echo "=== 诊断完成 ==="