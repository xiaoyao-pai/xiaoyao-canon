#!/bin/bash
# 逍遥派 · Skill 版本更新脚本（安全升级，保留用户数据）
# 用法: bash update.sh
set -e

SKILL_DIR="$HOME/.codebuddy/skills/xiaoyao-pai"
WORKSPACE="$HOME/.claw/workspace"
REMOTE_DIR="$WORKSPACE/xiaoyao-canon/skill-releases/current"
RULES_DIR="$HOME/.codebuddy/rules"
SKILLS_DIR="$HOME/.codebuddy/skills"

LOCAL_VER=$(python3 -c "import json; print(json.load(open('$SKILL_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")
REMOTE_VER=$(python3 -c "import json; print(json.load(open('$REMOTE_DIR/config/version.json'))['version'])" 2>/dev/null || echo "0.0.0")

if [ "$LOCAL_VER" = "$REMOTE_VER" ]; then
  echo "[更新] 版本一致: $LOCAL_VER，无需更新"
  exit 0
fi

echo "[更新] 升级: $LOCAL_VER → $REMOTE_VER"

# ============================================================
# 安全升级框架：分三类处理
# ============================================================

# === 类型 1：直接覆盖（纯逻辑代码，无用户数据）===
echo "[更新] 升级脚本和配置..."
# 脚本
cp "$REMOTE_DIR/scripts/install.sh"     "$SKILL_DIR/scripts/" 2>/dev/null
cp "$REMOTE_DIR/scripts/heartbeat.sh"   "$SKILL_DIR/scripts/" 2>/dev/null
cp "$REMOTE_DIR/scripts/contribute.sh"  "$SKILL_DIR/scripts/" 2>/dev/null
cp "$REMOTE_DIR/scripts/update.sh"      "$SKILL_DIR/scripts/" 2>/dev/null
mkdir -p "$SKILL_DIR/scripts/agent"
cp "$REMOTE_DIR/scripts/agent/experience_agent.py" "$SKILL_DIR/scripts/agent/" 2>/dev/null
chmod +x "$SKILL_DIR/scripts/"*.sh 2>/dev/null

# 元数据
cp "$REMOTE_DIR/SKILL.md"       "$SKILL_DIR/" 2>/dev/null
cp "$REMOTE_DIR/README.md"      "$SKILL_DIR/" 2>/dev/null
cp "$REMOTE_DIR/plugin.json"    "$SKILL_DIR/" 2>/dev/null

# 配置（保留 node.json 和 registration.json）
cp "$REMOTE_DIR/config/version.json"  "$SKILL_DIR/config/" 2>/dev/null
cp "$REMOTE_DIR/config/network.json"  "$SKILL_DIR/config/" 2>/dev/null
# 注意：不覆盖 node.json 和 registration.json

# === 类型 2：直接覆盖（系统级 Rules，观察/记忆的逻辑规则）===
echo "[更新] 升级系统 Rules..."
cp "$REMOTE_DIR/rules/xiaoyao-observer.mdc" "$RULES_DIR/" 2>/dev/null
cp "$REMOTE_DIR/rules/xiaoyao-memory.mdc"   "$RULES_DIR/" 2>/dev/null

# === 类型 3：合并升级（用户数据文件，只补充不覆盖）===
echo "[更新] 检查记忆模板（不覆盖已有数据）..."
MEMORY_DIR="$RULES_DIR/memory"
mkdir -p "$MEMORY_DIR"

for tpl in 00-核心身份.mdc 01-认知框架.mdc 02-行为习惯.mdc 03-技术画像.mdc; do
  LOCAL_FILE="$MEMORY_DIR/$tpl"
  REMOTE_FILE="$REMOTE_DIR/templates/memory/$tpl"
  
  if [ ! -f "$LOCAL_FILE" ]; then
    # 本地不存在 → 直接复制（新安装或文件被删）
    cp "$REMOTE_FILE" "$LOCAL_FILE" 2>/dev/null
    echo "  + 新建: $tpl"
  else
    # 本地已存在 → 检查是否有用户数据
    # 判断标准：观察记录区是否有实际条目（非注释、非空行）
    HAS_DATA=$(grep -c "^\- \[20" "$LOCAL_FILE" 2>/dev/null || echo "0")
    
    if [ "$HAS_DATA" -eq 0 ]; then
      # 无用户数据 → 可以安全覆盖（还是空模板）
      cp "$REMOTE_FILE" "$LOCAL_FILE" 2>/dev/null
      echo "  ↻ 更新空模板: $tpl"
    else
      # 有用户数据 → 保留！只更新模板的结构部分（frontmatter + 分区标题）
      echo "  ✓ 保留: $tpl（含 $HAS_DATA 条观察记录）"
      # 未来可以做更精细的结构合并，目前保守策略：不动
    fi
  fi
done

# 领域层文件保护（domain-*.mdc 由观察眼自动创建，永远不覆盖不删除）
DOMAIN_COUNT=$(ls "$MEMORY_DIR"/domain-*.mdc 2>/dev/null | wc -l | tr -d ' ')
if [ "$DOMAIN_COUNT" -gt 0 ]; then
  echo "  ✓ 保留: $DOMAIN_COUNT 个领域层文件（domain-*.mdc）"
fi

# === 子 Skill 升级（同理，有用户自定义则不覆盖）===
echo "[更新] 检查子 Skill..."
for skill_name in xiaoyao-ai-diary xiaoyao-pitfall-recorder; do
  LOCAL_SKILL="$SKILLS_DIR/$skill_name/SKILL.md"
  
  case $skill_name in
    xiaoyao-ai-diary)       REMOTE_SKILL="$REMOTE_DIR/templates/skills/ai-diary/SKILL.md" ;;
    xiaoyao-pitfall-recorder) REMOTE_SKILL="$REMOTE_DIR/templates/skills/pitfall-recorder/SKILL.md" ;;
  esac
  
  if [ ! -f "$LOCAL_SKILL" ]; then
    mkdir -p "$SKILLS_DIR/$skill_name"
    cp "$REMOTE_SKILL" "$LOCAL_SKILL" 2>/dev/null
    echo "  + 新建: $skill_name"
  else
    # 比对内容是否被用户修改过
    if diff -q "$LOCAL_SKILL" "$REMOTE_SKILL" > /dev/null 2>&1; then
      # 内容相同，用新版覆盖（可能只是格式变化）
      cp "$REMOTE_SKILL" "$LOCAL_SKILL" 2>/dev/null
      echo "  ↻ 更新: $skill_name"
    else
      # 用户已自定义，不覆盖
      echo "  ✓ 保留: $skill_name（用户已自定义）"
    fi
  fi
done

echo ""
echo "[更新] ✅ 升级完成: $LOCAL_VER → $REMOTE_VER"
echo "  保护项: node.json / registration.json / 有数据的记忆文件 / domain-*.mdc / 用户自定义的子Skill"
