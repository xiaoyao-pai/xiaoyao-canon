#!/bin/bash
# 逍遥派 · 心跳脚本（每天两次 13:00/19:00）
# 用法: bash heartbeat.sh
set -e

WORKSPACE="$HOME/.claw/workspace"
SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-pai"
NODE_CONFIG="$SKILL_DIR/config/node.json"

# 读取令牌号
TOKEN=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG'))['token'])" 2>/dev/null)
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

# 语义化版本比较：只有远端 > 本地才更新
SHOULD_UPDATE=$(python3 -c "
from packaging.version import Version
try:
    should = Version('$REMOTE_VERSION') > Version('$LOCAL_VERSION')
except:
    # fallback: 简单元组比较
    r = tuple(int(x) for x in '$REMOTE_VERSION'.split('.'))
    l = tuple(int(x) for x in '$LOCAL_VERSION'.split('.'))
    should = r > l
print('yes' if should else 'no')
" 2>/dev/null || echo "no")

if [ "$SHOULD_UPDATE" = "yes" ]; then
  echo "[心跳] Skill 升级: $LOCAL_VERSION → $REMOTE_VERSION"
  bash "$WORKSPACE/xiaoyao-canon/skill-releases/current/scripts/update.sh"
elif [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
  echo "[心跳] Skill 版本一致: $LOCAL_VERSION"
else
  echo "[心跳] 跳过: 本地 $LOCAL_VERSION ≥ 远端 $REMOTE_VERSION（不降级）"
fi

# === 3. 提交心跳状态到贡坊 ===
if [ -d "$WORKSPACE/xiaoyao-contrib" ]; then
  cd "$WORKSPACE/xiaoyao-contrib"
  
  # 写入心跳状态
  mkdir -p heartbeat
  cat > "heartbeat/$TOKEN.json" << EOF
{
  "token": "$TOKEN",
  "last_seen": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "skill_version": "$LOCAL_VERSION",
  "contributions_today": 0
}
EOF

  git add -A
  git commit -m "heartbeat: $TOKEN $(date '+%Y-%m-%d %H:%M')" --quiet 2>/dev/null
  git push origin main --quiet 2>/dev/null && echo "[心跳] 状态已同步" || echo "[心跳] 同步失败（可能无权限）"
fi

echo "[心跳] 完成"
