#!/bin/bash
# 逍遥派 · 心跳同步脚本（每天 12:00 + 18:00）
# 功能：正典更新 + 配置体系更新 + 经验提炼 + 心跳上报
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

echo "[同步] 令牌号: $TOKEN | $(date '+%Y-%m-%d %H:%M')"

# === 1. 检查正典更新（从云端）===
echo "[同步] 1/4 检查正典更新..."
REMOTE_CANON_VER=$(curl -s -m 10 "$API_BASE/canon/version" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','0.0.0'))" 2>/dev/null || echo "0.0.0")
LOCAL_CANON_VER=$(python3 -c "
import json, os
vf = os.path.expanduser('$WORKSPACE/xiaoyao-canon-data/_version.json')
print(json.load(open(vf))['version'] if os.path.exists(vf) else '0.0.0')
" 2>/dev/null || echo "0.0.0")

if [ "$REMOTE_CANON_VER" != "$LOCAL_CANON_VER" ] && [ "$REMOTE_CANON_VER" != "0.0.0" ]; then
  echo "[同步] 正典有更新: $LOCAL_CANON_VER → $REMOTE_CANON_VER，下载中..."
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
print(f'[同步] 正典更新完成: {count} 个文件')
" 2>/dev/null || echo "[同步] 正典下载失败"
else
  echo "[同步] 正典版本一致: $LOCAL_CANON_VER"
fi

# === 2. 检查配置体系更新（从 GitHub）===
echo "[同步] 2/4 检查配置体系更新..."
if [ -d "$WORKSPACE/xiaoyao-canon/.git" ]; then
  cd "$WORKSPACE/xiaoyao-canon"
  git pull origin main --quiet 2>/dev/null && echo "[同步] 配置体系源已更新" || echo "[同步] 拉取失败（不影响使用）"

  REMOTE_DIR="$WORKSPACE/xiaoyao-canon/skill-releases/current"
  REMOTE_SKILL_VER=$(python3 -c "import json; print(json.load(open('$REMOTE_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")

  SHOULD_UPDATE=$(python3 -c "
r = tuple(int(x) for x in '$REMOTE_SKILL_VER'.split('.'))
l = tuple(int(x) for x in '$LOCAL_VERSION'.split('.'))
print('yes' if r > l else 'no')
" 2>/dev/null || echo "no")

  if [ "$SHOULD_UPDATE" = "yes" ]; then
    echo "[同步] 配置体系升级: $LOCAL_VERSION → $REMOTE_SKILL_VER"
    bash "$REMOTE_DIR/scripts/update.sh"
  else
    echo "[同步] 配置体系版本一致: $LOCAL_VERSION"
  fi
else
  # 首次心跳时补 clone
  echo "[同步] 配置体系源不存在，尝试克隆..."
  cd "$WORKSPACE"
  git clone --depth 1 https://github.com/xiaoyao-pai/xiaoyao-canon.git 2>/dev/null && \
    echo "[同步] 配置体系源已克隆" || echo "[同步] 克隆失败（不影响使用）"
fi

# === 3. 经验提炼 + 上传 ===
echo "[同步] 3/4 提炼今日经验..."
EXPERIENCE_SCRIPT="$WORKSPACE/xiaoyao-canon/skill-releases/current/scripts/agent/experience_agent.py"
if [ -f "$EXPERIENCE_SCRIPT" ]; then
  python3 "$EXPERIENCE_SCRIPT" 2>/dev/null || echo "[同步] 经验提炼跳过（无活动或脚本错误）"
else
  echo "[同步] 经验提炼脚本不存在，跳过"
fi

# === 4. 心跳上报 ===
echo "[同步] 4/4 上报心跳..."
curl -s -m 10 -X POST "$API_BASE/heartbeat" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"skill_version\":\"$LOCAL_VERSION\"}" 2>/dev/null | grep -q '"ok"' && \
  echo "[同步] 心跳已上报 ✅" || echo "[同步] 心跳上报失败（不影响使用）"

echo "[同步] 完成"
