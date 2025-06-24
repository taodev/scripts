#!/bin/bash

set -eo pipefail

# 使用getopts解析参数（支持-h帮助、-f文件输入、-d目标目录）
FROM_FILE=""
CLONE_DIR=""
while getopts ":hfc:" opt; do
  case $opt in
    h) echo "用法:"
       echo "  $0 [选项] <repo-url> [目录列表|文件路径]"
       echo "选项:" 
       echo "  -h          显示帮助信息"
       echo "  -f <文件>   从文件读取目录列表"
       echo "  -c <目录>   指定目标目录（默认自动生成）"
       exit 0 ;; 
    f) FROM_FILE="$OPTARG"
       if [[ ! -f "$FROM_FILE" || ! -r "$FROM_FILE" ]]; then
         echo "❌ 文件无效: $FROM_FILE（不存在或不可读）" >&2
         exit 1
       fi ;; 
    c) CLONE_DIR="$OPTARG" ;; 
    \?) echo "❌ 无效选项: -$OPTARG" >&2; exit 1 ;; 
    :) echo "❌ 选项 -$OPTARG 需要参数" >&2; exit 1 ;; 
  esac
done
shift $((OPTIND-1))

# 基础参数检查（确保仓库URL存在）
if [[ $# -lt 1 ]]; then
  echo "❌ 缺少仓库URL参数"
  $0 -h
  exit 1
fi

REPO_URL="$1"
shift

# 调试：输出解析到的-c参数值
if [[ -n "$DEST_DIR" ]]; then
  echo "🔍 已解析到目标目录参数：$DEST_DIR" >&2
fi

# 验证-c参数有效性（可选）
if [[ -n "$DEST_DIR" && ! -d "$DEST_DIR" ]]; then
  echo "⚠️ 注意：指定的目标目录 $DEST_DIR 不存在，将自动创建"
  mkdir -p "$DEST_DIR"
fi

# 确定目标目录（用户指定或使用仓库名）
REPO_NAME=$(basename "$REPO_URL" .git)
# CLONE_DIR="${DEST_DIR:-$REPO_NAME}"  # 未指定-c时使用仓库名作为目录名

# 未指定-c时使用仓库名作为目录名
CLONE_DIR="${CLONE_DIR:-$REPO_NAME}"

# 克隆并检查失败
if ! git clone --filter=blob:none --no-checkout --depth=1 "$REPO_URL" "$CLONE_DIR"; then
  echo "❌ 克隆仓库失败，请检查URL是否正确" >&2
  exit 1
fi
cd "$CLONE_DIR" || {
  echo "❌ 进入克隆目录失败: $CLONE_DIR" >&2
  exit 1
}

# 初始化 sparse-checkout
git sparse-checkout init --cone

# 安全读取目录（支持带空格的目录名）
if [[ -n "$FROM_FILE" ]]; then
  mapfile -t DIRS < "$FROM_FILE"  # 从指定文件读取目录列表
else
  mapfile -t DIRS <<< "$*"  # 从命令行参数读取目录列表
fi

# 设置并验证sparse-checkout路径
if ! git sparse-checkout set "${DIRS[@]}"; then
  echo "❌ 设置sparse-checkout失败，请检查目录名是否正确" >&2
  exit 1
fi

# 检出并优化输出
if git checkout; then
  echo "✅ 成功克隆仓库：$REPO_URL"
  echo "📁 保留目录（共${#DIRS[@]}个）:"
  printf "  - %s\n" "${DIRS[@]}"
  echo "📂 本地路径: $(pwd)"
else
  echo "❌ 检出文件失败，请检查目录权限" >&2
  exit 1
fi
