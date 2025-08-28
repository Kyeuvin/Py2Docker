#!/bin/bash

# 动态配置定时任务的脚本
# 支持配置多个定时任务

# 默认单个任务配置（向后兼容）
DEFAULT_SCHEDULE="0 8 * * *"
DEFAULT_COMMAND="cd /app/src && python ckmovedataeveryday.py"

# 从环境变量获取配置
CRON_ENABLED=${CRON_ENABLED:-true}
# 移除可能存在的引号，使用sed更安全
CRON_SCHEDULE=$(echo "${CRON_SCHEDULE:-$DEFAULT_SCHEDULE}" | sed 's/"//g')
CRON_LOG_FILE=${CRON_LOG_FILE:-/app/data/cron.log}

# 多任务配置支持
# 格式: CRON_JOBS="job1_schedule|job1_command;job2_schedule|job2_command"
# 例如: CRON_JOBS="0 8 * * *|cd /app/src && python task1.py;0 14 * * *|cd /app/src && python task2.py"
CRON_JOBS=${CRON_JOBS:-""}

echo "定时任务配置信息："
echo "启用状态: $CRON_ENABLED"
echo "执行时间: $CRON_SCHEDULE"
echo "日志文件: $CRON_LOG_FILE"

if [ "$CRON_ENABLED" = "true" ]; then
    echo "配置定时任务..."
    
    # 创建日志目录
    mkdir -p $(dirname "$CRON_LOG_FILE")
    
    # 创建临时crontab文件
    cat > /tmp/dynamic-cron << EOF
# 动态配置的定时任务
# 配置时间: $(date)

EOF

    # 处理多任务配置
    if [ -n "$CRON_JOBS" ]; then
        echo "配置多个定时任务..."
        echo "CRON_JOBS: $CRON_JOBS"
        
        # 清理引号
        CLEAN_CRON_JOBS=$(echo "$CRON_JOBS" | sed 's/"//g')
        
        # 分割任务（用分号分隔）
        IFS=';' read -ra JOBS <<< "$CLEAN_CRON_JOBS"
        for job in "${JOBS[@]}"; do
            # 分割时间和命令（用管道符分隔）
            IFS='|' read -ra JOB_PARTS <<< "$job"
            if [ ${#JOB_PARTS[@]} -eq 2 ]; then
                job_schedule="${JOB_PARTS[0]}"
                job_command="${JOB_PARTS[1]}"
                
                echo "添加任务: $job_schedule -> $job_command"
                cat >> /tmp/dynamic-cron << EOF
# 任务: $job_command
$job_schedule $job_command >> $CRON_LOG_FILE 2>&1

EOF
            else
                echo "警告: 任务格式错误，跳过: $job"
            fi
        done
    else
        echo "配置单个定时任务（兼容模式）..."
        
        # 检查目标文件是否存在
        if [ ! -f "/app/src/ckmovedataeveryday.py" ]; then
            echo "警告: 目标文件 /app/src/ckmovedataeveryday.py 不存在"
            echo "将使用 main.py 作为替代"
            ACTUAL_COMMAND="cd /app/src && python main.py"
        else
            ACTUAL_COMMAND="$DEFAULT_COMMAND"
        fi
        
        cat >> /tmp/dynamic-cron << EOF
# 默认任务: $ACTUAL_COMMAND
# 执行时间: $CRON_SCHEDULE
$CRON_SCHEDULE $ACTUAL_COMMAND >> $CRON_LOG_FILE 2>&1

EOF
    fi

    echo ""
    echo "生成的crontab内容："
    cat /tmp/dynamic-cron
    
    # 确保cron服务运行
    service cron start || echo "cron服务启动失败，尝试其他方法"
    
    # 安装定时任务
    if crontab /tmp/dynamic-cron; then
        echo "✓ 定时任务安装成功"
    else
        echo "✗ 定时任务安装失败"
        exit 1
    fi
    
    rm /tmp/dynamic-cron
    
    echo "定时任务配置完成"
    echo "当前定时任务列表："
    crontab -l || echo "无法获取crontab列表"
    
    # 检查cron服务状态
    if service cron status > /dev/null 2>&1; then
        echo "✓ cron服务运行正常"
    else
        echo "✗ cron服务未运行，尝试重新启动"
        service cron restart
    fi
    
else
    echo "定时任务已禁用"
fi 