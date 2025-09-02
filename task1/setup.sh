#!/bin/bash

# 基本项目信息
PROJECT_NAME="$(basename "$(pwd)")"
PROJECT_TYPE="cron"

# 定时任务配置
CRON_SCHEDULE="0 */2 * * *"  # 每2小时执行一次
CRON_COMMAND="cd /app/$PROJECT_NAME && python3 main.py"
