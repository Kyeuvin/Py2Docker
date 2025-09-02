# 项目自动管理规范

## 概述

自动脚本执行管理器通过统一的 `setup.sh` 配置文件实现项目的自动发现和管理。每个项目只需要在根目录下创建一个 `setup.sh` 文件，即可实现自动注册和管理。

## 目录结构约定

```
/app/
├── task1/              # 项目目录
│   ├── setup.sh        # 项目配置脚本 (必需)
│   ├── main.py         # 主程序文件
│   └── config.json     # 配置文件 (可选)
├── task2/              # 另一个项目
│   ├── setup.sh        # 项目配置脚本
│   └── service.py      # 服务程序文件
└── scripts/            # 系统管理脚本目录
    ├── project_manager.sh
    └── setup_template.sh
```

## setup.sh 配置规范

### 基本要求

1. **文件名**: 必须是 `setup.sh`
2. **位置**: 项目根目录
3. **权限**: 可执行 (`chmod +x setup.sh`)
4. **编码**: UTF-8
5. **格式**: Bash脚本

### 必需配置项

```bash
# 项目名称 (必需)
PROJECT_NAME="your_project_name"

# 项目类型 (必需): "cron" 或 "service"  
PROJECT_TYPE="cron"
```

### 定时任务配置 (PROJECT_TYPE=cron)

```bash
# cron调度表达式 (必需)
CRON_SCHEDULE="0 */2 * * *"

# 执行命令 (必需)
CRON_COMMAND="cd /app/your_project && python3 main.py"
```

#### Cron调度表达式示例

| 表达式 | 说明 |
|--------|------|
| `*/5 * * * *` | 每5分钟执行 |
| `0 */2 * * *` | 每2小时执行 |
| `0 9 * * 1-5` | 周一到周五上午9点 |
| `30 2 * * 0` | 每周日凌晨2:30 |
| `0 0 1 * *` | 每月1号午夜 |

### 后台服务配置 (PROJECT_TYPE=service)

```bash
# 服务执行命令 (必需)
SERVICE_COMMAND="cd /app/your_project && python3 service.py"

# 重启策略 (可选，默认: always)
SERVICE_RESTART_POLICY="always"
```

#### 重启策略说明

- `always`: 服务停止后总是重启
- `on-failure`: 仅在异常退出时重启  
- `never`: 不自动重启

### 可选函数

#### 依赖检查函数

```bash
check_dependencies() {
    echo "检查项目依赖..."
    
    # 检查文件是否存在
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

```bash
initialize() {
    echo "初始化项目: $PROJECT_NAME"
    
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

```bash
cleanup() {
    echo "清理项目: $PROJECT_NAME"
    
    # 清理临时文件
    rm -rf temp/* 2>/dev/null || true
    
    # 停止相关进程
    pkill -f "your_project_pattern" 2>/dev/null || true
    
    return 0
}
```

## 完整示例

### 定时任务项目示例

```bash
#!/bin/bash
# 项目：数据同步任务
# 文件：task1/setup.sh

PROJECT_NAME="task1"
PROJECT_TYPE="cron"
CRON_SCHEDULE="0 */2 * * *"
CRON_COMMAND="cd /app/task1 && python3 main.py"

check_dependencies() {
    echo "检查数据同步任务依赖..."
    
    if [[ ! -f "main.py" ]]; then
        echo "错误：找不到 main.py"
        return 1
    fi
    
    python3 -c "import pandas, requests" 2>/dev/null || {
        echo "错误：缺少必需的Python包"
        return 1
    }
    
    return 0
}

initialize() {
    echo "初始化数据同步任务..."
    mkdir -p data/input data/output
    chmod 666 data/input/* 2>/dev/null || true
    return 0
}
```

### 后台服务项目示例

```bash
#!/bin/bash
# 项目：API监控服务
# 文件：monitor_service/setup.sh

PROJECT_NAME="monitor_service"
PROJECT_TYPE="service"
SERVICE_COMMAND="cd /app/monitor_service && python3 service.py"
SERVICE_RESTART_POLICY="always"

check_dependencies() {
    echo "检查监控服务依赖..."
    
    if [[ ! -f "service.py" ]]; then
        echo "错误：找不到 service.py"
        return 1
    fi
    
    if [[ -z "${MONITOR_URL:-}" ]]; then
        echo "错误：缺少 MONITOR_URL 环境变量"
        return 1
    fi
    
    return 0
}

initialize() {
    echo "初始化监控服务..."
    touch service.log
    chmod 666 service.log
    return 0
}

cleanup() {
    echo "清理监控服务..."
    pkill -f "monitor_service" 2>/dev/null || true
    return 0
}
```

## 使用流程

### 1. 添加新项目

1. 在 `/app/` 下创建项目目录
2. 将项目文件放入目录
3. 根据模板创建 `setup.sh` 文件
4. 设置执行权限：`chmod +x setup.sh`
5. 手动注册：`/app/scripts/project_manager.sh add 项目名`

### 2. 容器启动自动发现

容器启动时会自动：
1. 扫描所有项目目录
2. 查找包含 `setup.sh` 的项目
3. 验证脚本格式和依赖
4. 注册定时任务或启动后台服务

### 3. 管理项目

```bash
# 列出所有项目
/app/scripts/project_manager.sh list

# 查看项目状态
/app/scripts/project_manager.sh status task1

# 重启项目
/app/scripts/project_manager.sh restart task1

# 移除项目
/app/scripts/project_manager.sh remove task1

# 重新扫描所有项目
/app/scripts/project_manager.sh scan
```

## 最佳实践

### 1. 命名约定

- 项目名称使用小写字母、数字和下划线
- 避免使用系统保留名称：`logs`, `scripts`, `data`, `backup`

### 2. 错误处理

- 在函数中使用适当的返回码
- 提供清晰的错误消息
- 使用 `set -e` 在脚本开头启用错误检查

### 3. 日志记录

- 项目日志自动保存到 `/app/logs/projects/项目名.log`
- 系统日志保存到 `/app/logs/system/`
- 使用标准输出和错误输出

### 4. 资源管理

- 在cleanup函数中清理临时文件和进程
- 避免产生僵尸进程
- 合理设置重启策略

### 5. 安全考虑

- 不在setup.sh中存储敏感信息
- 使用环境变量传递配置
- 设置适当的文件权限

## 故障排查

### 常见问题

1. **项目未被发现**
   - 检查 setup.sh 文件是否存在
   - 检查文件权限是否为可执行
   - 查看系统日志：`/app/logs/system/project_manager.log`

2. **依赖检查失败**
   - 检查 check_dependencies 函数返回值
   - 验证Python包是否安装
   - 检查环境变量是否设置

3. **任务不执行**
   - 查看项目日志：`/app/logs/projects/项目名.log`
   - 检查cron服务状态：`service cron status`
   - 验证cron表达式格式

4. **服务异常退出**
   - 查看项目日志了解错误原因
   - 检查服务依赖和资源使用
   - 调整重启策略

### 调试模式

启用调试输出：
```bash
DEBUG=true /app/scripts/project_manager.sh scan
```

查看详细日志：
```bash
tail -f /app/logs/system/project_manager.log
tail -f /app/logs/projects/项目名.log
```