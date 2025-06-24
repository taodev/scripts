#!/bin/bash

set -eo pipefail

# 增强参数检查
if [[ $# -lt 2 ]]; then
  echo "❌ 参数不足"
  echo "用法:"
  echo "  直接指定目录: $0 <repo-url> <dir1> [<dir2> ...]"
  echo "  从文件读取目录: $0 <repo-url> --from-file <file-with-dirs>"
  exit 1
fi

REPO_URL="$1"
shift

# 生成唯一临时目录（添加时间戳防冲突）
REPO_NAME=$(basename "$REPO_URL" .git)
TIMESTAMP=$(date +%Y%m%d%H%M%S)
CLONE_DIR="${REPO_NAME}-sparse-${TIMESTAMP}"

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
if [[ "$1" == "--from-file" ]]; then
  FILE="$2"
  if [[ ! -f "$FILE" ]]; then
    echo "❌ 文件不存在: $FILE" >&2
    exit 1
  fi
  mapfile -t DIRS < "$FILE"  # 按行读取，保留空格
  shift 2
else
  mapfile -t DIRS <<< "$*"  # 转换为数组处理空格
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
  echo "📂 本地路径: $(realpath "$CLONE_DIR")"
else
  echo "❌ 检出文件失败，请检查目录权限" >&2
  exit 1
fi
