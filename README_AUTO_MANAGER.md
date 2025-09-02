# 自动脚本执行管理器

🚀 **一个统一的Docker项目管理系统，通过简单的配置文件实现定时任务和后台服务的自动化管理。**

## ✨ 特性

- 🔄 **自动项目发现** - 容器启动时自动扫描并注册项目
- ⚙️ **统一配置管理** - 每个项目只需一个`setup.sh`配置文件  
- 🎯 **动态项目管理** - 运行时添加新项目，无需重启容器
- 📊 **智能监控** - 自动监控服务状态并支持故障恢复
- 📝 **完善日志** - 系统和项目日志分离管理

## 🚀 快速开始

### 1. 验证系统

```bash
# 快速验证
bash /app/scripts/quick_test.sh

# 查看项目列表
/app/scripts/project_manager.sh list
```

### 2. 添加新项目

#### 交互式添加（推荐新手）
```bash
/app/scripts/add_project.sh interactive
```

#### 快速添加
```bash
# 定时任务（每2小时执行）
/app/scripts/add_project.sh quick my_task

# 自定义定时任务
/app/scripts/add_project.sh quick data_sync cron "0 */4 * * *"

# 后台服务
/app/scripts/add_project.sh quick api_monitor service
```

### 3. 项目管理

```bash
# 查看所有项目
/app/scripts/project_manager.sh list

# 查看项目状态
/app/scripts/project_manager.sh status task1

# 查看项目日志
/app/scripts/task_monitor.sh logs task1

# 重启项目
/app/scripts/project_manager.sh restart task1
```

## 📁 项目结构

```
/app/
├── task1/                  # 示例项目1 (定时任务)
│   ├── setup.sh           # ✅ 项目配置文件
│   └── main.py            # 主程序
├── task2/                  # 示例项目2 (定时任务)  
├── task3/                  # 示例项目3 (定时任务)
├── task4/                  # 示例项目4 (后台服务)
├── scripts/               # 🛠️ 管理工具
│   ├── project_manager.sh # 项目管理器
│   ├── task_monitor.sh    # 任务监控器
│   ├── add_project.sh     # 项目添加工具
│   └── ...
└── logs/                  # 📝 日志目录
    ├── system/           # 系统日志
    └── projects/         # 项目日志
```

## ⚙️ 配置示例

### 定时任务项目

创建 `/app/my_task/setup.sh`：

```bash
#!/bin/bash

# 项目信息
PROJECT_NAME="my_task"
PROJECT_TYPE="cron"

# 定时配置
CRON_SCHEDULE="0 */2 * * *"  # 每2小时执行
CRON_COMMAND="cd /app/my_task && python3 main.py"

# 依赖检查（可选）
check_dependencies() {
    [[ -f "main.py" ]] || { echo "缺少main.py"; return 1; }
    return 0
}
```

### 后台服务项目

创建 `/app/my_service/setup.sh`：

```bash
#!/bin/bash

# 项目信息
PROJECT_NAME="my_service" 
PROJECT_TYPE="service"

# 服务配置
SERVICE_COMMAND="cd /app/my_service && python3 service.py"
SERVICE_RESTART_POLICY="always"

# 初始化（可选）
initialize() {
    mkdir -p logs data
    return 0
}
```

## 📚 文档

- 📖 **[完整使用指南](AUTO_PROJECT_MANAGER_GUIDE.md)** - 详细的使用说明和示例
- 🔧 **[项目配置规范](PROJECT_SETUP_GUIDE.md)** - setup.sh文件编写规范
- 🎯 **[设计文档](.qoder/quests/auto-script-execution-manager.md)** - 系统架构和设计原理

## 🔧 常用命令

### 项目管理
```bash
/app/scripts/project_manager.sh <command>

scan                    # 扫描并注册所有项目
list                    # 列出项目列表  
add <name>             # 添加项目
remove <name>          # 移除项目
status <name>          # 查看项目状态
restart <name>         # 重启项目
```

### 任务监控
```bash
/app/scripts/task_monitor.sh <command>

status                 # 显示系统状态
logs <name> [lines]    # 查看项目日志
follow <name>          # 实时跟踪日志  
health                 # 系统健康检查
```

### 项目添加
```bash
/app/scripts/add_project.sh <command>

interactive            # 交互式添加
quick <name> [type]    # 快速添加
help                   # 显示帮助
```

## 🔍 Cron调度表达式

| 表达式 | 说明 |
|--------|------|
| `*/5 * * * *` | 每5分钟 |
| `0 */2 * * *` | 每2小时 |
| `0 9 * * 1-5` | 工作日上午9点 |
| `30 2 * * 0` | 每周日凌晨2:30 |
| `0 0 1 * *` | 每月1号午夜 |

## 🚨 故障排查

```bash
# 系统测试
bash /app/scripts/test_system.sh

# 健康检查  
/app/scripts/task_monitor.sh health

# 查看错误日志
grep "ERROR" /app/logs/system/*.log

# 调试模式
DEBUG=true /app/scripts/project_manager.sh scan
```

## 💡 最佳实践

1. **项目命名** - 使用小写字母、数字和下划线
2. **错误处理** - 在`setup.sh`中添加依赖检查
3. **日志管理** - 合理设置日志输出和清理策略
4. **资源控制** - 避免项目占用过多系统资源
5. **环境变量** - 使用环境变量管理配置参数

## 📈 升级历程

- **v1.0.0** - 初始版本，支持自动项目发现和管理
- 基于原有定时任务系统重构，简化项目添加流程
- 统一配置规范，提升系统可维护性

---

🎉 **开始使用吧！** 只需创建一个`setup.sh`文件，系统就会自动处理剩下的工作。