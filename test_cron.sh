#!/bin/bash

# 定时任务测试和调试脚本

echo "=== 定时任务测试脚本 ==="
echo "当前时间: $(date)"
echo ""

# 1. 检查环境变量
echo "1. 检查环境变量..."
echo "CRON_ENABLED: $CRON_ENABLED"
echo "CRON_SCHEDULE: $CRON_SCHEDULE"
echo "CRON_LOG_FILE: $CRON_LOG_FILE"
echo ""

# 2. 检查cron服务状态
echo "2. 检查cron服务状态..."
if service cron status > /dev/null 2>&1; then
    echo "✓ cron服务正在运行"
    service cron status
else
    echo "✗ cron服务未运行"
    echo "尝试启动cron服务..."
    service cron start
fi
echo ""

# 3. 检查当前的crontab
echo "3. 检查当前的crontab..."
if crontab -l > /dev/null 2>&1; then
    echo "当前的crontab内容："
    crontab -l
else
    echo "当前没有配置crontab"
fi
echo ""

# 4. 重新配置定时任务
echo "4. 重新配置定时任务..."
/app/setup_cron.sh
echo ""

# 5. 验证配置结果
echo "5. 验证配置结果..."
echo "最终的crontab内容："
crontab -l || echo "crontab配置失败"
echo ""

# 6. 检查目标文件
echo "6. 检查目标执行文件..."
if [ -f "/app/src/ckmovedataeveryday.py" ]; then
    echo "✓ /app/src/ckmovedataeveryday.py 存在"
    echo "文件大小: $(stat -c%s "/app/src/ckmovedataeveryday.py") 字节"
else
    echo "✗ /app/src/ckmovedataeveryday.py 不存在"
fi

if [ -f "/app/src/main.py" ]; then
    echo "✓ /app/src/main.py 存在"
    echo "文件大小: $(stat -c%s "/app/src/main.py") 字节"
else
    echo "✗ /app/src/main.py 不存在"
fi
echo ""

# 7. 检查日志目录
echo "7. 检查日志目录..."
LOG_DIR=$(dirname "$CRON_LOG_FILE")
if [ -d "$LOG_DIR" ]; then
    echo "✓ 日志目录存在: $LOG_DIR"
    echo "目录权限: $(stat -c%a "$LOG_DIR")"
else
    echo "✗ 日志目录不存在: $LOG_DIR"
    echo "创建日志目录..."
    mkdir -p "$LOG_DIR"
fi
echo ""

# 8. 手动测试定时任务命令
echo "8. 手动测试定时任务命令..."
echo "测试命令: cd /app/src && python ckmovedataeveryday.py"
cd /app/src
if python ckmovedataeveryday.py --help > /dev/null 2>&1 || python ckmovedataeveryday.py > /dev/null 2>&1; then
    echo "✓ 命令可以执行"
else
    echo "⚠ 命令执行可能有问题，测试备用命令"
    echo "测试备用命令: cd /app/src && python main.py"
    if python main.py --help > /dev/null 2>&1; then
        echo "✓ 备用命令可以执行"
    else
        echo "⚠ 备用命令执行可能有问题"
    fi
fi
echo ""

echo "=== 测试完成 ==="
echo "如果配置正确，定时任务将在每天上午8点执行"
echo "可以通过以下命令查看定时任务日志："
echo "  tail -f $CRON_LOG_FILE" 