# Docker Compose 定时任务使用说明

## 项目概述

本项目提供了一个基于Docker Compose的定时任务解决方案，可以在一个容器中运行三个独立的Python脚本，每个脚本都有自己的定时调度配置。

### 核心特性

- ✅ **多任务支持**: 支持三个独立的Python脚本
- ✅ **灵活调度**: 基于环境变量的定时配置
- ✅ **健康检查**: 内置健康监控机制
- ✅ **日志管理**: 自动日志收集和轮转
- ✅ **容器化部署**: 一键构建和部署
- ✅ **实时监控**: 完整的监控和管理工具

## 快速开始

### 1. 环境要求

- Docker (版本 20.10+)
- Docker Compose (版本 1.29+)
- Linux操作系统或WSL2

### 2. 项目结构

```
cron_test/
├── task1/                  # 任务1脚本目录
│   └── main.py            # 任务1主脚本
├── task2/                  # 任务2脚本目录
│   └── main.py            # 任务2主脚本
├── task3/                  # 任务3脚本目录
│   └── main.py            # 任务3主脚本
├── scripts/                # 管理脚本目录
│   ├── health_check.sh    # 健康检查脚本
│   └── setup_cron.sh      # 定时任务管理脚本
├── logs/                   # 日志文件目录
├── data/                   # 数据持久化目录
├── Dockerfile             # Docker镜像构建文件
├── docker-compose.yml     # Docker Compose配置
├── .env                   # 环境变量配置
├── entrypoint.sh          # 容器入口脚本
├── requirements.txt       # Python依赖
└── 管理脚本/
    ├── start.sh           # 一键启动脚本
    ├── stop.sh            # 停止脚本
    ├── restart.sh         # 重启脚本
    ├── status.sh          # 状态查看脚本
    └── logs.sh            # 日志查看脚本
```

### 3. 一键启动

```bash
# 赋予脚本执行权限
chmod +x *.sh

# 启动容器
./start.sh
```

或者使用Docker Compose命令：

```bash
# 构建镜像
docker-compose build

# 启动容器
docker-compose up -d
```

## 配置说明

### 环境变量配置

编辑`.env`文件来配置定时任务：

```bash
# 时区设置
TIMEZONE=Asia/Shanghai

# 日志级别
LOG_LEVEL=INFO

# 定时任务调度 (Cron表达式格式)
TASK1_SCHEDULE=0 */2 * * *      # 每2小时执行
TASK2_SCHEDULE=*/30 * * * *     # 每30分钟执行
TASK3_SCHEDULE=0 9 * * 1        # 每周一9点执行
```

### Cron表达式参考

Cron表达式格式：`分钟 小时 日期 月份 星期`

| 表达式 | 说明 |
|--------|------|
| `* * * * *` | 每分钟 |
| `*/5 * * * *` | 每5分钟 |
| `0 * * * *` | 每小时 |
| `0 */2 * * *` | 每2小时 |
| `0 9 * * *` | 每天9点 |
| `0 9 * * 1-5` | 工作日9点 |
| `0 0 1 * *` | 每月1号午夜 |
| `0 9 * * 1` | 每周一9点 |

## 管理命令

### 容器管理

```bash
# 启动容器
./start.sh

# 停止容器
./stop.sh

# 重启容器
./restart.sh

# 查看状态
./status.sh
```

### 日志查看

```bash
# 查看所有日志摘要
./logs.sh all

# 查看特定任务日志
./logs.sh task1
./logs.sh task2
./logs.sh task3

# 实时跟踪日志
./logs.sh -f task1

# 查看最后100行日志
./logs.sh -n 100 task2
```

### 容器内管理

```bash
# 进入容器
docker exec -it cron-tasks bash

# 查看定时任务列表
docker exec cron-tasks crontab -l

# 使用管理脚本
docker exec cron-tasks /app/scripts/setup_cron.sh list
docker exec cron-tasks /app/scripts/setup_cron.sh status
docker exec cron-tasks /app/scripts/setup_cron.sh logs task1

# 执行健康检查
docker exec cron-tasks /app/scripts/health_check.sh
```

## 高级用法

### 动态添加定时任务

```bash
# 进入容器
docker exec -it cron-tasks bash

# 添加新任务
/app/scripts/setup_cron.sh add "*/10 * * * *" "echo 'Hello World' >> /app/logs/test.log"

# 删除任务
/app/scripts/setup_cron.sh remove task1

# 重启cron服务
/app/scripts/setup_cron.sh restart
```

### 自定义Python依赖

编辑`requirements.txt`文件添加需要的Python包：

```txt
requests
pandas
numpy
# 添加其他依赖...
```

然后重新构建镜像：

```bash
docker-compose build --no-cache
docker-compose up -d
```

### 健康检查

健康检查自动运行，检查以下项目：

- ✅ Cron服务状态
- ✅ 日志文件可写性
- ✅ 磁盘空间使用
- ✅ Python环境
- ✅ 定时任务配置
- ✅ 脚本文件存在性

查看健康状态：

```bash
# 查看Docker健康状态
docker ps

# 执行详细健康检查
docker exec cron-tasks /app/scripts/health_check.sh
```

## 监控和调试

### 查看容器状态

```bash
# 查看容器列表
docker ps

# 查看容器详细信息
docker inspect cron-tasks

# 查看资源使用情况
docker stats cron-tasks
```

### 日志文件位置

| 日志类型 | 文件路径 | 说明 |
|----------|----------|------|
| 任务1日志 | `./logs/task1.log` | 任务1执行日志 |
| 任务2日志 | `./logs/task2.log` | 任务2执行日志 |
| 任务3日志 | `./logs/task3.log` | 任务3执行日志 |
| 健康检查日志 | `./logs/health.log` | 健康检查记录 |
| 容器日志 | `docker logs cron-tasks` | 容器系统日志 |

### 常见问题排查

#### 1. 定时任务不执行

```bash
# 检查cron服务状态
docker exec cron-tasks pgrep cron

# 查看cron配置
docker exec cron-tasks crontab -l

# 重启cron服务
docker exec cron-tasks service cron restart
```

#### 2. 日志文件为空

```bash
# 检查日志目录权限
docker exec cron-tasks ls -la /app/logs/

# 手动执行任务测试
docker exec cron-tasks python /app/task1/main.py
```

#### 3. 容器启动失败

```bash
# 查看容器日志
docker logs cron-tasks

# 检查配置文件
cat docker-compose.yml
cat .env
```

#### 4. 健康检查失败

```bash
# 执行健康检查
docker exec cron-tasks /app/scripts/health_check.sh

# 查看健康检查日志
tail -f ./logs/health.log
```

## 生产环境部署

### 安全建议

1. **不要以root用户运行容器**
2. **定期清理日志文件**
3. **监控磁盘空间使用**
4. **备份重要数据**
5. **定期更新基础镜像**

### 性能优化

1. **合理设置定时间隔**
2. **避免任务重叠执行**
3. **监控资源使用情况**
4. **使用日志轮转机制**

### 备份和恢复

```bash
# 备份数据目录
tar -czf backup-$(date +%Y%m%d).tar.gz ./data ./logs

# 备份定时任务配置
docker exec cron-tasks crontab -l > crontab-backup-$(date +%Y%m%d).txt

# 恢复定时任务
docker exec cron-tasks crontab crontab-backup-YYYYMMDD.txt
```

## 支持和帮助

### 查看帮助信息

```bash
# 查看脚本帮助
./start.sh --help
./logs.sh --help
docker exec cron-tasks /app/scripts/setup_cron.sh help
```

### 联系支持

如果遇到问题，请提供以下信息：

1. 容器状态：`docker ps`
2. 容器日志：`docker logs cron-tasks`
3. 健康检查结果：`docker exec cron-tasks /app/scripts/health_check.sh`
4. 系统信息：`docker version` 和 `docker-compose version`

---

**祝您使用愉快！** 🎉