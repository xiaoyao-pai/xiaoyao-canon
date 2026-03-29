#!/bin/bash
# 逍遥派 · 经验提交脚本
# 用法: bash contribute.sh <经验文件路径>
set -e

WORKSPACE="$HOME/.claw/workspace"
SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-pai"
NODE_CONFIG="$SKILL_DIR/config/node.json"

TOKEN=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG'))['token'])" 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "错误: 未找到节点配置"; exit 1; fi

CONTRIB_DIR="$WORKSPACE/xiaoyao-contrib/contributions/$TOKEN"
mkdir -p "$CONTRIB_DIR"

DATE=$(date +%Y-%m-%d)
FILE="$1"

if [ -z "$FILE" ]; then
  echo "用法: bash contribute.sh <经验文件路径>"
  exit 1
fi

# 复制经验文件到贡坊
cp "$FILE" "$CONTRIB_DIR/${DATE}-$(basename "$FILE")"

cd "$WORKSPACE/xiaoyao-contrib"
git add -A
git commit -m "contrib: $TOKEN $DATE 经验提交" --quiet 2>/dev/null
git push origin main --quiet 2>/dev/null && echo "经验已提交到贡坊" || echo "提交失败"
