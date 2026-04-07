#!/bin/bash
# 逍遥派 · 经验提交脚本
# 用法: bash contribute.sh <经验文件路径>
set -e

SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-pai"
NODE_CONFIG="$SKILL_DIR/config/node.json"

TOKEN=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG'))['token'])" 2>/dev/null)
API_BASE=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG')).get('api_base', 'https://ai-mas.art/xiaoyao/api'))" 2>/dev/null)

if [ -z "$TOKEN" ]; then echo "错误: 未找到节点配置"; exit 1; fi

FILE="$1"
if [ -z "$FILE" ]; then
  echo "用法: bash contribute.sh <经验文件路径>"
  exit 1
fi

if [ ! -f "$FILE" ]; then
  echo "错误: 文件不存在: $FILE"
  exit 1
fi

DATE=$(date +%Y-%m-%d)
FILENAME="${DATE}-$(basename "$FILE")"
CONTENT=$(cat "$FILE")

# 提交到注册中心 API
RESP=$(curl -s -m 30 -X POST "$API_BASE/contribute" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "import json; print(json.dumps({'token':'$TOKEN','filename':'$FILENAME','content':open('$FILE').read()}))")" 2>/dev/null)

if echo "$RESP" | grep -q '"ok"'; then
  echo "经验已提交到逍遥派网络 ✅"
else
  echo "提交失败（已保存本地）"
fi
