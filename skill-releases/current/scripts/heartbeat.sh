#!/bin/bash
# 逍遥派 · 心跳同步脚本 v0.0.16
# 功能：正典更新（云端 API）+ 配置体系更新（git pull）+ 上传已提炼经验 + 心跳上报
# 不再包含经验提炼（已拆为独立自动化任务）
set -e

WORKSPACE="$HOME/.claw/workspace"
SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-pai"
NODE_CONFIG="$SKILL_DIR/config/node.json"
CANON_SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-canon-practices"

# 读取配置
TOKEN=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG'))['token'])" 2>/dev/null)
API_BASE=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG')).get('api_base', 'http://119.29.181.188/xiaoyao/api'))" 2>/dev/null)

# 读取版本号
LOCAL_VERSION=$(python3 -c "
import json, os
vf = os.path.expanduser('$SKILL_DIR/config/version.json')
nf = os.path.expanduser('$SKILL_DIR/config/node.json')
if os.path.exists(vf):
    print(json.load(open(vf))['version'])
elif os.path.exists(nf):
    print(json.load(open(nf)).get('skill_version', '0.0.0'))
else:
    print('0.0.0')
" 2>/dev/null || echo "0.0.0")

if [ -z "$TOKEN" ]; then
  echo "错误: 未找到节点配置，请先运行 install.sh"
  exit 1
fi

echo "[同步] 令牌号: $TOKEN | 版本: $LOCAL_VERSION | $(date '+%Y-%m-%d %H:%M')"

# === 1. 检查正典更新（云端 API）===
echo "[同步] 1/4 检查正典更新（云端）..."
REMOTE_CANON_VER=$(curl -s -m 10 "$API_BASE/canon/version" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('version','0.0.0'))" 2>/dev/null || echo "0.0.0")

LOCAL_CANON_VER=$(python3 -c "
import json, os
vf = os.path.expanduser('$CANON_SKILL_DIR/_version.json')
print(json.load(open(vf))['version'] if os.path.exists(vf) else '0.0.0')
" 2>/dev/null || echo "0.0.0")

if [ "$REMOTE_CANON_VER" != "$LOCAL_CANON_VER" ] && [ "$REMOTE_CANON_VER" != "0.0.0" ]; then
  echo "[同步] 正典有更新: $LOCAL_CANON_VER → $REMOTE_CANON_VER，下载中..."
  mkdir -p "$CANON_SKILL_DIR/practices"

  curl -s -m 30 "$API_BASE/canon/download?token=$TOKEN" 2>/dev/null | python3 -c "
import sys, json, os
data = json.load(sys.stdin)
if data.get('status') != 'ok': sys.exit(1)
base = '$CANON_SKILL_DIR'
count = 0
for rel_path, content in data.get('files', {}).items():
    if rel_path.startswith('_'): continue
    full = os.path.join(base, rel_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(content)
    count += 1
ver = data.get('version', '0.0.0')
with open(os.path.join('$CANON_SKILL_DIR', '_version.json'), 'w') as f:
    json.dump({'version': ver, 'file_count': count}, f)
# 更新 INDEX.md
idx = '# 逍遥派共享正典 · 经验索引\n\n'
idx += f'> 版本: {ver} | 收录: {count} 篇\n\n'
for rel_path in sorted(data.get('files', {}).keys()):
    if rel_path.startswith('_'): continue
    idx += f'- [{rel_path}]({rel_path})\n'
with open(os.path.join('$CANON_SKILL_DIR', 'INDEX.md'), 'w') as f:
    f.write(idx)
print(f'[同步] 正典更新完成: {count} 个文件')
" 2>/dev/null || echo "[同步] 正典下载失败"
else
  echo "[同步] 正典版本一致: $LOCAL_CANON_VER"
fi

# === 2. 检查配置体系更新（git pull）===
echo "[同步] 2/4 检查配置体系更新（GitHub）..."
if [ -d "$WORKSPACE/xiaoyao-canon/.git" ]; then
  cd "$WORKSPACE/xiaoyao-canon"
  GIT_RESULT=$(git pull origin main 2>&1)
  if [ $? -eq 0 ]; then
    echo "[同步] 配置体系源已更新"
  else
    echo "[同步] Git 拉取结果: $GIT_RESULT"
    echo "[同步] 尝试重新克隆..."
    cd "$WORKSPACE"
    rm -rf xiaoyao-canon
    git clone --depth 1 https://github.com/xiaoyao-pai/xiaoyao-canon.git 2>/dev/null && \
      echo "[同步] 重新克隆成功" || echo "[同步] 克隆失败（不影响使用）"
  fi

  REMOTE_DIR="$WORKSPACE/xiaoyao-canon/skill-releases/current"
  REMOTE_SKILL_VER=$(python3 -c "import json; print(json.load(open('$REMOTE_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")

  SHOULD_UPDATE=$(python3 -c "
r = tuple(int(x) for x in '$REMOTE_SKILL_VER'.split('.'))
l = tuple(int(x) for x in '$LOCAL_VERSION'.split('.'))
print('yes' if r > l else 'no')
" 2>/dev/null || echo "no")

  if [ "$SHOULD_UPDATE" = "yes" ]; then
    echo "[同步] 配置体系升级: $LOCAL_VERSION → $REMOTE_SKILL_VER"
    if [ -f "$REMOTE_DIR/scripts/update.sh" ]; then
      bash "$REMOTE_DIR/scripts/update.sh"
    else
      echo "[同步] update.sh 不存在，跳过自动升级"
    fi
  else
    echo "[同步] 配置体系版本一致: $LOCAL_VERSION"
  fi
else
  # 首次心跳时按需 clone
  echo "[同步] 配置体系源不存在，按需克隆..."
  cd "$WORKSPACE"
  git clone --depth 1 https://github.com/xiaoyao-pai/xiaoyao-canon.git 2>/dev/null && \
    echo "[同步] 配置体系源已克隆" || echo "[同步] 克隆失败（不影响使用）"
fi

# === 3. 上传已提炼的经验 ===
echo "[同步] 3/4 上传已提炼经验..."
CONTRIB_DIR="$HOME/.claw/workspace/xiaoyao-contrib/contributions/$TOKEN"
UPLOAD_MARKER="$CONTRIB_DIR/.last_upload"

if [ -d "$CONTRIB_DIR" ]; then
  # 找到上次上传后新增的文件
  if [ -f "$UPLOAD_MARKER" ]; then
    PENDING=$(find "$CONTRIB_DIR" -name "*.md" -newer "$UPLOAD_MARKER" 2>/dev/null)
  else
    PENDING=$(find "$CONTRIB_DIR" -name "*.md" 2>/dev/null)
  fi

  UPLOAD_COUNT=0
  for f in $PENDING; do
    FILENAME=$(basename "$f")
    CONTENT_JSON=$(python3 -c "import json; print(json.dumps(open('$f', encoding='utf-8').read()))" 2>/dev/null)
    if [ -n "$CONTENT_JSON" ]; then
      curl -s -m 10 -X POST "$API_BASE/contribute" \
        -H "Content-Type: application/json" \
        -d "{\"token\":\"$TOKEN\",\"filename\":\"$FILENAME\",\"content\":$CONTENT_JSON}" 2>/dev/null | grep -q '"ok"' && \
        UPLOAD_COUNT=$((UPLOAD_COUNT + 1))
    fi
  done

  if [ $UPLOAD_COUNT -gt 0 ]; then
    touch "$UPLOAD_MARKER"
    echo "[同步] 已上传 $UPLOAD_COUNT 条经验"
  else
    echo "[同步] 无新经验需上传"
  fi
else
  echo "[同步] 无本地经验（经验提炼任务尚未产出）"
fi

# === 4. 心跳上报 ===
echo "[同步] 4/4 上报心跳..."
curl -s -m 10 -X POST "$API_BASE/heartbeat" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"skill_version\":\"$LOCAL_VERSION\"}" 2>/dev/null | grep -q '"ok"' && \
  echo "[同步] 心跳已上报 ✅" || echo "[同步] 心跳上报失败（不影响使用）"

echo "[同步] 完成"
