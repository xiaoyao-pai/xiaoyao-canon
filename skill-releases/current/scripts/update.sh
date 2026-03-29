#!/bin/bash
# 逍遥派 · Skill 版本更新脚本
# 比对本地和远端版本，有新版自动覆盖
set -e

SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-pai"
WORKSPACE="$HOME/.claw/workspace"

LOCAL_VER=$(python3 -c "import json; print(json.load(open('$SKILL_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")
REMOTE_VER=$(python3 -c "import json; print(json.load(open('$WORKSPACE/xiaoyao-canon/skill-releases/current/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")

if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
  echo "Skill 版本一致: $LOCAL_VER，无需更新"
  exit 0
fi

echo "发现新版本: $LOCAL_VER → $REMOTE_VER"
cp -r "$WORKSPACE/xiaoyao-canon/skill-releases/current/"* "$SKILL_DIR/"
echo "Skill 已更新到 $REMOTE_VER"
