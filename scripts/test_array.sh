#!/bin/bash

echo "=== 数组处理测试 ==="

# 模拟scan_projects函数
test_scan() {
    echo "abc task1 task2 task3 task4 task5 task6"
}

echo "1. 测试直接数组赋值:"
projects=($(test_scan))
echo "数组长度: ${#projects[@]}"
echo "数组内容: [${projects[*]}]"

echo -e "\n2. 测试索引循环:"
for ((i=0; i<${#projects[@]}; i++)); do
    echo "项目索引 $i: '${projects[i]}'"
done

echo -e "\n3. 测试for循环:"
for project in "${projects[@]}"; do
    echo "处理项目: $project"
done

echo -e "\n4. 直接调用scan_projects测试:"
source /app/scripts/project_manager.sh
real_projects=($(scan_projects))
echo "真实数组长度: ${#real_projects[@]}"
echo "真实数组内容: [${real_projects[*]}]"

echo -e "\n5. 真实数组循环测试:"
for ((i=0; i<${#real_projects[@]}; i++)); do
    echo "真实项目索引 $i: '${real_projects[i]}'"
done