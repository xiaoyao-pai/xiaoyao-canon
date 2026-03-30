#!/bin/bash
# 逍遥派 · 心跳脚本
# 用法: bash heartbeat.sh
set -e

WORKSPACE="$HOME/.claw/workspace"
SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-pai"
NODE_CONFIG="$SKILL_DIR/config/node.json"

# 读取配置
TOKEN=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG'))['token'])" 2>/dev/null)
API_BASE=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG')).get('api_base', 'http://119.29.181.188/xiaoyao/api'))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "错误: 未找到节点配置，请先运行 install.sh"
  exit 1
fi

echo "[心跳] 令牌号: $TOKEN | $(date '+%Y-%m-%d %H:%M')"

# === 1. 拉取正典最新内容 ===
if [ -d "$WORKSPACE/xiaoyao-canon" ]; then
  cd "$WORKSPACE/xiaoyao-canon"
  git pull origin main --quiet 2>/dev/null && echo "[心跳] 正典已更新" || echo "[心跳] 正典拉取失败"
fi

# === 2. 检查 Skill 版本（只升不降）===
LOCAL_VERSION=$(python3 -c "import json; print(json.load(open('$SKILL_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")
REMOTE_VERSION=$(python3 -c "import json; print(json.load(open('$WORKSPACE/xiaoyao-canon/skill-releases/current/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")

SHOULD_UPDATE=$(python3 -c "
r = tuple(int(x) for x in '$REMOTE_VERSION'.split('.'))
l = tuple(int(x) for x in '$LOCAL_VERSION'.split('.'))
print('yes' if r > l else 'no')
" 2>/dev/null || echo "no")

if [ "$SHOULD_UPDATE" = "yes" ]; then
  echo "[心跳] Skill 升级: $LOCAL_VERSION → $REMOTE_VERSION"
  bash "$WORKSPACE/xiaoyao-canon/skill-releases/current/scripts/update.sh"
elif [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
  echo "[心跳] Skill 版本一致: $LOCAL_VERSION"
else
  echo "[心跳] 跳过: 本地 $LOCAL_VERSION ≥ 远端 $REMOTE_VERSION（不降级）"
fi

# === 3. 发送心跳到注册中心 ===
curl -s -m 10 -X POST "$API_BASE/heartbeat" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"skill_version\":\"$LOCAL_VERSION\"}" 2>/dev/null | grep -q '"ok"' && \
  echo "[心跳] 状态已同步" || echo "[心跳] 心跳上报失败（不影响使用）"

echo "[心跳] 完成"
