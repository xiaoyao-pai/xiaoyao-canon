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
LOCAL_VERSION=$(python3 -c "import json; print(json.load(open('$SKILL_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")

if [ -z "$TOKEN" ]; then
  echo "错误: 未找到节点配置，请先运行 install.sh"
  exit 1
fi

echo "[心跳] 令牌号: $TOKEN | $(date '+%Y-%m-%d %H:%M')"

# === 1. 检查正典更新（从云端） ===
echo "[心跳] 检查正典更新..."
REMOTE_CANON_VER=$(curl -s -m 10 "$API_BASE/canon/version" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','0.0.0'))" 2>/dev/null || echo "0.0.0")
LOCAL_CANON_VER=$(python3 -c "
import json, os
vf = os.path.expanduser('$WORKSPACE/xiaoyao-canon-data/_version.json')
print(json.load(open(vf))['version'] if os.path.exists(vf) else '0.0.0')
" 2>/dev/null || echo "0.0.0")

if [ "$REMOTE_CANON_VER" != "$LOCAL_CANON_VER" ] && [ "$REMOTE_CANON_VER" != "0.0.0" ]; then
  echo "[心跳] 正典有更新: $LOCAL_CANON_VER → $REMOTE_CANON_VER，下载中..."
  CANON_LOCAL="$WORKSPACE/xiaoyao-canon-data"
  mkdir -p "$CANON_LOCAL"

  curl -s -m 30 "$API_BASE/canon/download?token=$TOKEN" 2>/dev/null | python3 -c "
import sys, json, os
data = json.load(sys.stdin)
if data.get('status') != 'ok': sys.exit(1)
base = '$CANON_LOCAL'
count = 0
for rel_path, content in data.get('files', {}).items():
    full = os.path.join(base, rel_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(content)
    count += 1
print(f'[心跳] 正典更新完成: {count} 个文件')
" 2>/dev/null || echo "[心跳] 正典下载失败"
else
  echo "[心跳] 正典版本一致: $LOCAL_CANON_VER"
fi

# === 2. 检查 Skill 版本更新（从 GitHub） ===
# Skill 安装器仍然从 GitHub 拉取
if [ -d "$WORKSPACE/xiaoyao-canon/.git" ]; then
  cd "$WORKSPACE/xiaoyao-canon"
  git pull origin main --quiet 2>/dev/null && echo "[心跳] Skill 源码已更新" || echo "[心跳] Skill 源码拉取失败"

  REMOTE_DIR="$WORKSPACE/xiaoyao-canon/skill-releases/current"
  REMOTE_SKILL_VER=$(python3 -c "import json; print(json.load(open('$REMOTE_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")

  SHOULD_UPDATE=$(python3 -c "
r = tuple(int(x) for x in '$REMOTE_SKILL_VER'.split('.'))
l = tuple(int(x) for x in '$LOCAL_VERSION'.split('.'))
print('yes' if r > l else 'no')
" 2>/dev/null || echo "no")

  if [ "$SHOULD_UPDATE" = "yes" ]; then
    echo "[心跳] Skill 升级: $LOCAL_VERSION → $REMOTE_SKILL_VER"
    bash "$REMOTE_DIR/scripts/update.sh"
  else
    echo "[心跳] Skill 版本一致: $LOCAL_VERSION"
  fi
fi

# === 3. 发送心跳到注册中心 ===
curl -s -m 10 -X POST "$API_BASE/heartbeat" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"skill_version\":\"$LOCAL_VERSION\"}" 2>/dev/null | grep -q '"ok"' && \
  echo "[心跳] 状态已同步" || echo "[心跳] 心跳上报失败（不影响使用）"

echo "[心跳] 完成"
