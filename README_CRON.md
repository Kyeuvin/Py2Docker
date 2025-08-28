# Docker 定时任务使用说明

## 概述
本项目已集成cron定时任务功能，可以通过环境变量轻松配置执行时间，无需重新构建镜像。

## 快速开始

### 1. 基本配置
在 `docker-compose.yml` 中配置定时任务：

```yaml
environment:
  # 定时任务配置
  - CRON_ENABLED=true                    # 是否启用定时任务
  - CRON_SCHEDULE="0 2 * * *"           # 执行时间表达式
  - CRON_LOG_FILE=/app/data/cron.log    # 日志文件路径
```

### 2. 常用时间表达式

| 表达式 | 说明 | 示例 |
|--------|------|------|
| `0 2 * * *` | 每天凌晨2点 | 每天凌晨2:00 |
| `0 */2 * * *` | 每2小时 | 0:00, 2:00, 4:00... |
| `*/30 * * * *` | 每30分钟 | 0:00, 0:30, 1:00... |
| `0 9 * * 1` | 每周一早上9点 | 每周一9:00 |
| `0 1 1 * *` | 每月1号凌晨1点 | 每月1号1:00 |
| `0 8-18 * * 1-5` | 工作日8点到18点每小时 | 周一到周五8:00-18:00 |

### 3. 动态调整时间

#### 方法1：修改环境变量（推荐）
```bash
# 修改docker-compose.yml中的CRON_SCHEDULE
- CRON_SCHEDULE="0 */4 * * *"  # 每4小时执行一次

# 重启容器
docker-compose down
docker-compose up -d
```

#### 方法2：进入容器实时调整
```bash
# 进入容器
docker exec -it invoice-bot bash

# 查看当前定时任务
/app/cron_manager.sh list

# 添加新的定时任务
/app/cron_manager.sh add

# 查看定时任务状态
/app/cron_manager.sh status

# 查看执行日志
/app/cron_manager.sh logs
```

## 管理命令

### 进入容器后的管理命令

```bash
# 查看定时任务状态
/app/cron_manager.sh status

# 列出所有定时任务
/app/cron_manager.sh list

# 添加新的定时任务
/app/cron_manager.sh add

# 移除所有定时任务
/app/cron_manager.sh remove

# 查看定时任务日志
/app/cron_manager.sh logs

# 重启cron服务
/app/cron_manager.sh restart
```

### 手动编辑crontab
```bash
# 进入容器
docker exec -it invoice-bot bash

# 编辑定时任务
crontab -e

# 查看定时任务
crontab -l

# 清空所有定时任务
crontab -r
```

## 日志查看

### 实时查看日志
```bash
# 进入容器
docker exec -it invoice-bot bash

# 实时查看日志
tail -f /app/data/cron.log

# 查看最后50行日志
tail -50 /app/data/cron.log
```

### 从宿主机查看日志
```bash
# 查看容器日志
docker logs invoice-bot

# 查看定时任务日志文件
cat /root/data/invoice-bot/cron.log
```

## 常见问题

### 1. 定时任务不执行
- 检查cron服务是否启动：`/app/cron_manager.sh status`
- 检查时间表达式是否正确
- 查看日志文件：`/app/cron_manager.sh logs`

### 2. 时区问题
容器已设置为Asia/Shanghai时区，确保你的cron表达式使用正确的时区。

### 3. 权限问题
确保日志目录有写入权限：
```bash
docker exec -it invoice-bot bash
chmod 755 /app/data
```

### 4. 重启后定时任务丢失
定时任务配置会在容器启动时自动恢复，无需担心。

## 高级配置

### 多个定时任务
可以在 `setup_cron.sh` 中添加多个定时任务：

```bash
# 每天凌晨2点执行
0 2 * * * cd /app/src && python main.py >> /app/data/cron.log 2>&1

# 每小时执行一次
0 * * * * cd /app/src && python main.py >> /app/data/cron.log 2>&1

# 每周一早上9点执行
0 9 * * 1 cd /app/src && python main.py >> /app/data/cron.log 2>&1
```

### 自定义执行命令
可以修改 `setup_cron.sh` 中的 `DEFAULT_COMMAND` 变量来执行不同的命令。

## 注意事项

1. **日志轮转**：建议定期清理日志文件，避免占用过多磁盘空间
2. **资源监控**：定时任务执行时会消耗系统资源，注意监控
3. **错误处理**：确保定时任务中的脚本有适当的错误处理
4. **备份**：重要的定时任务配置建议备份到宿主机

## 联系支持
如有问题，请查看容器日志或联系技术支持。