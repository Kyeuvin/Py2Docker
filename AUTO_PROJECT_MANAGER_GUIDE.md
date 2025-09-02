# 自动脚本执行管理器 - 使用指南

## 概述

自动脚本执行管理器是一个基于Docker的统一项目管理系统，通过标准化的`setup.sh`配置文件实现项目的自动发现、注册和管理。您只需要在项目目录下创建一个`setup.sh`文件，系统就会自动处理定时任务注册和后台服务启动。

### 主要特性

- ✅ **自动项目发现**: 容器启动时自动扫描并注册包含`setup.sh`的项目
- ✅ **统一配置管理**: 每个项目通过单一的`setup.sh`文件进行配置
- ✅ **动态项目添加**: 支持运行时添加新项目，无需重启容器
- ✅ **灵活任务类型**: 支持定时任务（cron）和后台服务（service）
- ✅ **智能监控**: 自动监控后台服务状态并支持自动重启
- ✅ **完善日志**: 系统和项目日志分离，便于调试和监控

### 系统架构

```
/app/
├── task1/                  # 项目目录
│   ├── setup.sh           # 项目配置文件 (必需)
│   ├── main.py            # 主程序文件
│   └── ...                # 其他项目文件
├── task2/                  # 另一个项目
│   ├── setup.sh           # 项目配置文件
│   └── service.py         # 服务程序文件
├── scripts/               # 系统管理脚本
│   ├── project_manager.sh # 项目管理器
│   ├── task_monitor.sh    # 任务监控器
│   ├── add_project.sh     # 项目添加工具
│   └── ...               # 其他工具脚本
└── logs/                  # 日志目录
    ├── system/           # 系统日志
    └── projects/         # 项目日志
```

## 快速开始

### 1. 系统初始化

容器启动时会自动执行以下操作：

1. 设置文件权限
2. 启动Cron服务
3. 扫描并注册所有项目
4. 启动任务监控器

您也可以手动验证系统状态：

```bash
# 快速验证系统
bash /app/scripts/quick_test.sh

# 完整测试
bash /app/scripts/test_system.sh
```

### 2. 查看当前项目

```bash
# 列出所有项目及其状态
/app/scripts/project_manager.sh list

# 查看系统整体状态
/app/scripts/task_monitor.sh status
```

### 3. 添加新项目

#### 方法一：交互式添加（推荐）

```bash
/app/scripts/add_project.sh interactive
```

系统会引导您完成以下配置：
- 项目名称
- 项目类型（定时任务或后台服务）
- 调度规则或启动命令
- 重启策略（仅后台服务）

#### 方法二：快速添加

```bash
# 添加默认定时任务（每2小时执行）
/app/scripts/add_project.sh quick my_task

# 添加自定义定时任务
/app/scripts/add_project.sh quick data_sync cron "0 */4 * * *"

# 添加后台服务
/app/scripts/add_project.sh quick api_monitor service
```

#### 方法三：手动创建

1. 创建项目目录：
```bash
mkdir /app/my_project
```

2. 创建`setup.sh`文件（参考[配置规范](#配置规范)）

3. 注册项目：
```bash
/app/scripts/project_manager.sh add my_project
```

## 配置规范

### setup.sh 基本结构

每个项目的`setup.sh`文件必须包含以下内容：

```bash
#!/bin/bash

# 基本项目信息 (必需)
PROJECT_NAME="项目名称"
PROJECT_TYPE="cron"  # 或 "service"

# 定时任务配置 (PROJECT_TYPE=cron时必需)
CRON_SCHEDULE="0 */2 * * *"
CRON_COMMAND="cd /app/项目目录 && python3 main.py"

# 后台服务配置 (PROJECT_TYPE=service时必需)
SERVICE_COMMAND="cd /app/项目目录 && python3 service.py"
SERVICE_RESTART_POLICY="always"

# 可选函数
check_dependencies() { ... }
initialize() { ... }
cleanup() { ... }
```

### 项目类型详解

#### 1. 定时任务 (cron)

适用于周期性执行的脚本，如数据同步、报表生成、清理任务等。

```bash
PROJECT_TYPE="cron"
CRON_SCHEDULE="0 */2 * * *"  # 每2小时执行
CRON_COMMAND="cd /app/task1 && python3 main.py"
```

**Cron调度表达式示例：**

| 表达式 | 说明 |
|--------|------|
| `*/5 * * * *` | 每5分钟 |
| `0 */2 * * *` | 每2小时 |
| `0 9 * * 1-5` | 工作日上午9点 |
| `30 2 * * 0` | 每周日凌晨2:30 |
| `0 0 1 * *` | 每月1号午夜 |

#### 2. 后台服务 (service)

适用于需要持续运行的服务，如API监控、消息队列处理、实时数据采集等。

```bash
PROJECT_TYPE="service"
SERVICE_COMMAND="cd /app/monitor && python3 service.py"
SERVICE_RESTART_POLICY="always"
```

**重启策略：**
- `always`: 服务停止后总是重启（推荐）
- `on-failure`: 仅在异常退出时重启
- `never`: 不自动重启

### 可选函数

#### 依赖检查函数
在项目注册前执行，用于验证运行环境：

```bash
check_dependencies() {
    echo "检查项目依赖..."
    
    # 检查文件
    if [[ ! -f "main.py" ]]; then
        echo "错误：找不到 main.py"
        return 1
    fi
    
    # 检查Python包
    python3 -c "import requests" 2>/dev/null || {
        echo "错误：缺少 requests 包"
        return 1
    }
    
    # 检查环境变量
    if [[ -z "${API_KEY:-}" ]]; then
        echo "错误：缺少 API_KEY 环境变量"
        return 1
    fi
    
    return 0
}
```

#### 初始化函数
在注册任务前执行，用于项目准备工作：

```bash
initialize() {
    echo "初始化项目..."
    
    # 创建目录
    mkdir -p data logs temp
    
    # 初始化配置
    if [[ ! -f "config.json" ]]; then
        echo '{"version": "1.0"}' > config.json
    fi
    
    # 设置权限
    chmod 755 scripts/*.sh 2>/dev/null || true
    
    return 0
}
```

#### 清理函数
在移除项目时执行：

```bash
cleanup() {
    echo "清理项目..."
    
    # 清理临时文件
    rm -rf temp/* 2>/dev/null || true
    
    # 停止相关进程
    pkill -f "项目标识" 2>/dev/null || true
    
    return 0
}
```

## 管理命令

### 项目管理器 (project_manager.sh)

```bash
# 扫描并注册所有项目
/app/scripts/project_manager.sh scan

# 添加单个项目
/app/scripts/project_manager.sh add <项目名>

# 移除项目
/app/scripts/project_manager.sh remove <项目名>

# 列出所有项目
/app/scripts/project_manager.sh list

# 查看项目状态
/app/scripts/project_manager.sh status <项目名>

# 重启项目
/app/scripts/project_manager.sh restart <项目名>

# 显示帮助
/app/scripts/project_manager.sh help
```

### 任务监控器 (task_monitor.sh)

```bash
# 显示系统状态
/app/scripts/task_monitor.sh status

# 查看项目日志
/app/scripts/task_monitor.sh logs <项目名> [行数]

# 实时跟踪日志
/app/scripts/task_monitor.sh follow <项目名>

# 重启项目
/app/scripts/task_monitor.sh restart <项目名>

# 系统健康检查
/app/scripts/task_monitor.sh health

# 启动监控守护进程（通常自动启动）
/app/scripts/task_monitor.sh daemon
```

### 项目添加工具 (add_project.sh)

```bash
# 交互式添加
/app/scripts/add_project.sh interactive

# 快速添加
/app/scripts/add_project.sh quick <项目名> [类型] [调度/命令]

# 显示帮助
/app/scripts/add_project.sh help
```

## 实际使用示例

### 示例1：数据同步定时任务

1. **创建项目目录：**
```bash
mkdir /app/data_sync
cd /app/data_sync
```

2. **创建主程序：**
```python
# main.py
import requests
import json
from datetime import datetime

def sync_data():
    print(f"[{datetime.now()}] 开始数据同步...")
    # 实际的数据同步逻辑
    response = requests.get("https://api.example.com/data")
    
    if response.status_code == 200:
        with open("data/latest.json", "w") as f:
            json.dump(response.json(), f)
        print(f"[{datetime.now()}] 数据同步完成")
    else:
        print(f"[{datetime.now()}] 数据同步失败: {response.status_code}")

if __name__ == "__main__":
    sync_data()
```

3. **创建setup.sh：**
```bash
#!/bin/bash
PROJECT_NAME="data_sync"
PROJECT_TYPE="cron"
CRON_SCHEDULE="0 */6 * * *"  # 每6小时执行
CRON_COMMAND="cd /app/data_sync && python3 main.py"

check_dependencies() {
    python3 -c "import requests" 2>/dev/null || {
        echo "错误：缺少 requests 包"
        return 1
    }
    return 0
}

initialize() {
    mkdir -p data
    return 0
}
```

4. **注册项目：**
```bash
chmod +x setup.sh
/app/scripts/project_manager.sh add data_sync
```

### 示例2：API监控后台服务

1. **使用快速添加：**
```bash
/app/scripts/add_project.sh quick api_monitor service
```

2. **编辑生成的service.py：**
```python
# /app/api_monitor/service.py
import time
import requests
from datetime import datetime

class APIMonitor:
    def __init__(self):
        self.running = True
        self.api_urls = [
            "https://api1.example.com/health",
            "https://api2.example.com/status"
        ]
    
    def run(self):
        print(f"[{datetime.now()}] API监控服务启动")
        
        while self.running:
            self.check_apis()
            time.sleep(60)  # 每分钟检查一次
    
    def check_apis(self):
        for url in self.api_urls:
            try:
                response = requests.get(url, timeout=10)
                status = "OK" if response.status_code == 200 else f"ERROR({response.status_code})"
                print(f"[{datetime.now()}] {url}: {status}")
            except Exception as e:
                print(f"[{datetime.now()}] {url}: FAILED({e})")

if __name__ == "__main__":
    monitor = APIMonitor()
    monitor.run()
```

### 示例3：批量迁移现有项目

如果您有多个现有项目需要迁移到新系统：

```bash
# 为每个现有项目快速生成setup.sh
for task in task1 task2 task3; do
    echo "处理项目: $task"
    
    # 根据项目特点创建setup.sh
    cat > /app/$task/setup.sh << EOF
#!/bin/bash
PROJECT_NAME="$task"
PROJECT_TYPE="cron"
CRON_SCHEDULE="0 */2 * * *"
CRON_COMMAND="cd /app/$task && python3 main.py"

check_dependencies() {
    [[ -f "main.py" ]] || { echo "缺少main.py"; return 1; }
    return 0
}

initialize() {
    mkdir -p data logs
    return 0
}
EOF
    
    chmod +x /app/$task/setup.sh
    echo "✓ $task/setup.sh 已创建"
done

# 批量注册所有项目
/app/scripts/project_manager.sh scan
```

## 日志管理

### 日志文件位置

```
/app/logs/
├── system/                    # 系统日志
│   ├── project_manager.log    # 项目管理日志
│   ├── task_monitor.log       # 任务监控日志
│   ├── registration.log       # 注册操作日志
│   └── services.conf          # 后台服务配置
└── projects/                  # 项目日志
    ├── project1.log          # 项目1执行日志
    ├── project1.pid          # 项目1进程ID（仅后台服务）
    └── ...
```

### 日志查看命令

```bash
# 查看项目日志
/app/scripts/task_monitor.sh logs task1 100

# 实时跟踪日志
/app/scripts/task_monitor.sh follow task1

# 查看系统日志
tail -f /app/logs/system/project_manager.log
tail -f /app/logs/system/task_monitor.log

# 查看所有错误日志
grep "ERROR" /app/logs/system/*.log
grep "FAIL" /app/logs/projects/*.log
```

### 日志轮转

系统会自动管理日志文件。您可以在项目的`cleanup`函数中添加日志清理逻辑：

```bash
cleanup() {
    # 清理30天前的日志
    find logs -name "*.log" -mtime +30 -delete 2>/dev/null || true
}
```

## 故障排查

### 常见问题及解决方案

#### 1. 项目未被发现

**现象：** `/app/scripts/project_manager.sh list` 中看不到项目

**检查步骤：**
```bash
# 1. 检查setup.sh文件是否存在
ls -la /app/项目名/setup.sh

# 2. 检查文件权限
chmod +x /app/项目名/setup.sh

# 3. 检查语法错误
bash -n /app/项目名/setup.sh

# 4. 手动注册
/app/scripts/project_manager.sh add 项目名
```

#### 2. 定时任务不执行

**现象：** 任务已注册但不执行

**检查步骤：**
```bash
# 1. 检查Cron服务状态
service cron status

# 2. 查看crontab配置
crontab -l

# 3. 检查项目日志
/app/scripts/task_monitor.sh logs 项目名

# 4. 手动测试命令
cd /app/项目名 && python3 main.py
```

#### 3. 后台服务异常退出

**现象：** 服务状态显示为"已停止"

**检查步骤：**
```bash
# 1. 查看项目日志
/app/scripts/task_monitor.sh logs 项目名

# 2. 检查错误信息
tail -50 /app/logs/projects/项目名.log | grep -i error

# 3. 手动启动测试
cd /app/项目名 && python3 service.py

# 4. 重启服务
/app/scripts/task_monitor.sh restart 项目名
```

#### 4. 权限问题

**现象：** "Permission denied" 错误

**解决方案：**
```bash
# 设置脚本权限
chmod +x /app/scripts/*.sh
chmod +x /app/*/setup.sh

# 设置日志目录权限
chmod 755 /app/logs
chmod 666 /app/logs/projects/*.log

# 或运行权限设置脚本
bash /app/scripts/setup_permissions.sh
```

### 调试模式

启用调试输出以获取更多信息：

```bash
# 启用调试模式
export DEBUG=true

# 重新扫描项目
/app/scripts/project_manager.sh scan

# 查看详细状态
/app/scripts/task_monitor.sh status
```

### 系统健康检查

定期运行健康检查以发现问题：

```bash
# 系统健康检查
/app/scripts/task_monitor.sh health

# 完整系统测试
bash /app/scripts/test_system.sh
```

## 最佳实践

### 1. 项目命名规范

- 使用小写字母、数字和下划线
- 名称要有意义，例如：`data_sync`, `email_sender`, `log_cleaner`
- 避免使用系统保留名称：`logs`, `scripts`, `data`, `backup`

### 2. 错误处理

在`setup.sh`中添加适当的错误处理：

```bash
check_dependencies() {
    local errors=0
    
    # 检查Python包
    python3 -c "import requests, pandas" 2>/dev/null || {
        echo "错误：缺少必需的Python包"
        ((errors++))
    }
    
    # 检查环境变量
    if [[ -z "${DATABASE_URL:-}" ]]; then
        echo "错误：缺少 DATABASE_URL 环境变量"
        ((errors++))
    fi
    
    return $errors
}
```

### 3. 资源管理

合理设置资源限制和清理策略：

```bash
initialize() {
    # 设置资源限制
    ulimit -m 512000  # 限制内存使用
    
    # 清理旧文件
    find temp -type f -mtime +7 -delete 2>/dev/null || true
}

cleanup() {
    # 优雅关闭
    pkill -TERM -f "项目进程标识" 2>/dev/null || true
    sleep 5
    pkill -KILL -f "项目进程标识" 2>/dev/null || true
    
    # 清理资源
    rm -rf temp/* 2>/dev/null || true
}
```

### 4. 监控和告警

在项目中集成监控：

```python
# 示例：在Python脚本中添加健康检查
import os
import sys
from datetime import datetime

def health_check():
    """健康检查函数"""
    health_file = "logs/health.txt"
    os.makedirs("logs", exist_ok=True)
    
    with open(health_file, "w") as f:
        f.write(f"{datetime.now()}: OK\n")

def main():
    try:
        # 业务逻辑
        process_data()
        health_check()  # 记录健康状态
    except Exception as e:
        print(f"ERROR: {e}")
        sys.exit(1)
```

### 5. 环境配置

使用环境变量进行配置管理：

```bash
# 在docker-compose.yml中设置
environment:
  - DATABASE_URL=postgresql://user:pass@host:5432/db
  - API_KEY=your_api_key
  - LOG_LEVEL=INFO

# 在setup.sh中验证
check_dependencies() {
    required_vars=("DATABASE_URL" "API_KEY")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "错误：缺少环境变量 $var"
            return 1
        fi
    done
    return 0
}
```

## 升级和维护

### 系统更新

当需要更新管理脚本时：

1. 备份现有配置
2. 更新脚本文件
3. 重新设置权限
4. 测试功能

```bash
# 备份
cp -r /app/scripts /app/scripts.backup

# 更新脚本后
bash /app/scripts/setup_permissions.sh
bash /app/scripts/test_system.sh
```

### 数据迁移

如需迁移到新容器：

1. 备份项目目录和配置
2. 在新环境中重新部署
3. 验证所有项目正常运行

## 技术支持

如果您遇到问题：

1. 查看[故障排查](#故障排查)部分
2. 运行系统测试：`bash /app/scripts/test_system.sh`
3. 检查日志文件获取详细信息
4. 参考项目设计文档了解系统原理

---

**系统版本：** 1.0.0  
**最后更新：** 2024-08-28  
**维护者：** Qoder AI