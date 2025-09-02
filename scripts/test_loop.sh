#!/bin/bash

# 测试循环处理逻辑的脚本

set -x  # 启用详细调试

echo "=== 测试项目循环处理 ==="

# 使用相同的扫描逻辑
PROJECTS_DIR="/app"

scan_projects() {
    echo "开始扫描项目目录: $PROJECTS_DIR" >&2
    local discovered_projects=()
    
    for project_dir in "$PROJECTS_DIR"/*/; do
        if [[ -d "$project_dir" ]]; then
            local project_name=$(basename "$project_dir")
            local setup_file="$project_dir/setup.sh"
            
            # 跳过系统目录
            if [[ "$project_name" =~ ^(logs|scripts|data|backup)$ ]]; then
                echo "跳过系统目录: $project_name" >&2
                continue
            fi
            
            if [[ -f "$setup_file" ]]; then
                echo "发现项目: $project_name (setup.sh存在)" >&2
                discovered_projects+=("$project_name")
            fi
        fi
    done
    
    echo "共发现 ${#discovered_projects[@]} 个项目: ${discovered_projects[*]}" >&2
    echo "${discovered_projects[@]}"
}

# 模拟项目处理
mock_execute_project_setup() {
    local project_name="$1"
    echo "模拟处理项目: $project_name"
    
    # 检查项目类型
    local project_dir="$PROJECTS_DIR/$project_name"
    if [[ -f "$project_dir/setup.sh" ]]; then
        local project_type=$(cd "$project_dir" && source ./setup.sh >/dev/null 2>&1 && echo "${PROJECT_TYPE:-cron}")
        echo "  项目类型: $project_type"
        
        case "$project_type" in
            "cron")
                echo "  -> 这是cron项目，会调用simple_register.sh"
                return 0
                ;;
            "service")
                echo "  -> 这是service项目，会直接注册为后台服务"
                return 0
                ;;
            *)
                echo "  -> 不支持的项目类型: $project_type"
                return 1
                ;;
        esac
    else
        echo "  -> 错误：没有setup.sh文件"
        return 1
    fi
}

# 主测试逻辑
echo "获取项目列表..."
projects=($(scan_projects))
total_count=${#projects[@]}
success_count=0

echo "发现 $total_count 个项目: ${projects[*]}"
echo ""

echo "开始循环处理..."
for project in "${projects[@]}"; do
    echo "========================================="
    echo "处理项目: $project"
    
    if mock_execute_project_setup "$project"; then
        ((success_count++))
        echo "项目 $project 处理成功 (进度: $success_count/$total_count)"
    else
        echo "项目 $project 配置失败 (进度: $success_count/$total_count)"
    fi
    
    echo "项目 $project 处理完成，继续下一个..."
    echo ""
done

echo "========================================="
echo "循环处理完成"
echo "扫描完成: $success_count/$total_count 个项目配置成功"