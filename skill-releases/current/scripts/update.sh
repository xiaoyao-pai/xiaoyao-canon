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

# === 类型 3：融合升级（用户数据文件，保留数据 + 更新框架）===
echo "[更新] 检查记忆文件（融合模式：保留数据 + 更新框架）..."
MEMORY_DIR="$RULES_DIR/memory"
mkdir -p "$MEMORY_DIR"

# 融合函数：用 Python 精确提取用户数据，注入新模板框架
merge_memory_file() {
  local LOCAL_FILE="$1"
  local REMOTE_FILE="$2"
  local FILENAME="$3"

  if [ ! -f "$LOCAL_FILE" ]; then
    cp "$REMOTE_FILE" "$LOCAL_FILE" 2>/dev/null
    echo "  + 新建: $FILENAME"
    return
  fi

  # 用 Python 做精确融合
  python3 -c "
import re, sys

local_path = '$LOCAL_FILE'
remote_path = '$REMOTE_FILE'

# 读取本地文件
with open(local_path, 'r', encoding='utf-8') as f:
    local_lines = f.readlines()

# 提取用户数据：非空行、非注释行、非 frontmatter、非标题行
user_data = {}  # section_name -> [lines]
current_section = '_top'
in_frontmatter = False
fm_count = 0

for line in local_lines:
    stripped = line.rstrip()
    # frontmatter 检测
    if stripped == '---':
        fm_count += 1
        if fm_count <= 2:
            continue
    if fm_count < 2:
        continue
    # 分区标题检测
    if stripped.startswith('## '):
        current_section = stripped.lstrip('# ').strip()
        if current_section not in user_data:
            user_data[current_section] = []
        continue
    if stripped.startswith('# ') and not stripped.startswith('## '):
        continue
    # 跳过空行、注释行、旧模板占位符
    if not stripped or stripped.startswith('<!--') or stripped.startswith('> '):
        continue
    # 跳过旧模板默认占位文字
    if stripped in ('（AI 观察后自动填入）', '(AI will fill in)', '（待填入）'):
        continue
    # 这是用户数据
    if current_section not in user_data:
        user_data[current_section] = []
    user_data[current_section].append(line.rstrip())

# 统计总数据量
total_data = sum(len(v) for v in user_data.values())
if total_data == 0:
    # 无数据，直接用新模板
    import shutil
    shutil.copy2(remote_path, local_path)
    print(f'  ↻ 更新空模板: $FILENAME')
    sys.exit(0)

# 读取新模板
with open(remote_path, 'r', encoding='utf-8') as f:
    template = f.read()

# 对每个有数据的分区，在模板对应位置追加数据
for section, lines in user_data.items():
    if not lines:
        continue
    # 找到模板中对应的分区位置（## section_name 之后的注释行之后）
    pattern = r'(## ' + re.escape(section) + r'.*?\n)((?:<!--.*?-->\s*\n)*)'
    match = re.search(pattern, template)
    if match:
        insert_pos = match.end()
        data_block = '\n'.join(lines) + '\n'
        template = template[:insert_pos] + data_block + template[insert_pos:]
    else:
        # 分区在新模板中不存在，追加到末尾
        template = template.rstrip() + '\n\n## ' + section + '\n' + '\n'.join(lines) + '\n'

with open(local_path, 'w', encoding='utf-8') as f:
    f.write(template)

print(f'  ⊕ 融合: $FILENAME（框架更新 + 保留 {total_data} 条记录，覆盖 {len(user_data)} 个分区）')
" 2>/dev/null || {
    # Python 融合失败，保守策略：不动
    echo "  ✓ 保留: $FILENAME（融合失败，保守保留原文件）"
  }
}

for tpl in 00-核心身份.mdc 01-认知框架.mdc 02-行为习惯.mdc 03-技术画像.mdc 04-人生状态.mdc 05-经验洞察.mdc; do
  if [ -f "$REMOTE_DIR/templates/memory/$tpl" ]; then
    merge_memory_file "$MEMORY_DIR/$tpl" "$REMOTE_DIR/templates/memory/$tpl" "$tpl"
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

# === 类型 5：正典 Skill 骨架（确保存在）===
echo "[更新] 检查正典 Skill..."
CANON_SKILL="$SKILLS_DIR/xiaoyao-canon-practices"
if [ ! -f "$CANON_SKILL/SKILL.md" ]; then
  mkdir -p "$CANON_SKILL/practices"
  cat > "$CANON_SKILL/SKILL.md" << 'SKILLEOF'
---
name: xiaoyao-canon-practices
description: "逍遥派共享正典 — 全派 AI 弟子共享的经验库。包含审核过的最佳实践、踩坑记录、技术决策。"
triggers:
  - 正典
  - 经验库
  - 有没有类似经验
  - 之前怎么解决的
  - 逍遥派经验
type: flexible
---

# 逍遥派 · 共享正典

> 来自全派弟子的共享经验，经掌门审核收录。

## 使用方式
- "正典里有没有类似的经验？"
- "查一下逍遥派经验库"

## 查询指令
1. 读取本目录下的 INDEX.md 获取经验目录
2. 根据用户问题匹配相关经验
3. 读取对应 practices/*.md 文件
4. 参考经验内容回答用户问题

## 经验索引
见 INDEX.md（由心跳自动同步更新）
SKILLEOF
  echo "  + 新建: xiaoyao-canon-practices（正典 Skill）"
else
  echo "  ✓ 正典 Skill 已存在"
fi

# === 类型 6：刷新自动化任务（补 next_run_at / 新增经验提炼任务）===
echo "[更新] 刷新自动化任务..."
AUTOMATION_DB=""
for db_path in \
  "$HOME/Library/Application Support/CodeBuddy CN/automations/automations.db" \
  "$HOME/Library/Application Support/WorkBuddy/automations/automations.db" \
  "$HOME/.config/CodeBuddy CN/automations/automations.db"; do
  if [ -f "$db_path" ]; then
    AUTOMATION_DB="$db_path"
    break
  fi
done

if [ -n "$AUTOMATION_DB" ]; then
  NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null)
  CWDS_JSON="[\"$HOME\"]"
  HEARTBEAT_PROMPT='执行逍遥派心跳同步任务：运行 bash ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/heartbeat.sh，该脚本会检查正典更新、检查配置体系更新。直接运行脚本即可，不需要额外操作。执行完毕后简要报告结果。'

  NEXT_RUNS=$(python3 -c "
from datetime import datetime, timedelta
import time
now = datetime.now()
slots = [12, 15, 18]
results = {}
for h in slots:
    t = now.replace(hour=h, minute=0, second=0, microsecond=0)
    if now >= t:
        t += timedelta(days=1)
    results[h] = int(t.timestamp() * 1000)
print(f'{results[12]}|{results[15]}|{results[18]}')
" 2>/dev/null)

  NOON_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f1)
  AFTERNOON_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f2)
  EVENING_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f3)

  sqlite3 "$AUTOMATION_DB" "DELETE FROM automations WHERE id LIKE 'xiaoyao-%';" 2>/dev/null

  sqlite3 "$AUTOMATION_DB" "INSERT INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at) VALUES ('xiaoyao-sync-noon', '逍遥派心跳同步（午间）', '$HEARTBEAT_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=12;BYMINUTE=0', $NOW_MS, $NOW_MS, 'recurring', $NOON_NEXT);" 2>/dev/null
  sqlite3 "$AUTOMATION_DB" "INSERT INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at) VALUES ('xiaoyao-sync-afternoon', '逍遥派心跳同步（下午）', '$HEARTBEAT_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=15;BYMINUTE=0', $NOW_MS, $NOW_MS, 'recurring', $AFTERNOON_NEXT);" 2>/dev/null
  sqlite3 "$AUTOMATION_DB" "INSERT INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at) VALUES ('xiaoyao-sync-evening', '逍遥派心跳同步（傍晚）', '$HEARTBEAT_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=18;BYMINUTE=0', $NOW_MS, $NOW_MS, 'recurring', $EVENING_NEXT);" 2>/dev/null

  EXPERIENCE_NEXT=$(python3 -c "from datetime import datetime, timedelta; import time; now=datetime.now(); nh=now.replace(minute=0,second=0,microsecond=0)+timedelta(hours=(2-now.hour%2)); print(int(nh.timestamp()*1000))" 2>/dev/null)
  EXPERIENCE_PROMPT='你是逍遥派经验提炼师。请执行以下任务：
1. 读取最近的 AI 对话记录（brain/overview.md），找到有实质内容的对话
2. 从中提炼可复用的经验，按类型分类：skill/pitfall/decision/insight
3. 每条经验用 markdown 格式，包含 frontmatter（type/domain/tags/date）
4. 安全脱敏（只脱密钥/Token/密码/IP）
5. 读取 ~/.codebuddy/skills/xiaoyao-pai/config/node.json 获取令牌号
6. 保存到 ~/.claw/workspace/xiaoyao-contrib/contributions/{令牌号}/ 目录
7. 如果没有值得提炼的内容，什么都不做，不要编造
文件命名：YYYY-MM-DD-序号-标题.md'

  sqlite3 "$AUTOMATION_DB" "INSERT INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at) VALUES ('xiaoyao-experience', '逍遥派经验提炼', '$EXPERIENCE_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=HOURLY;INTERVAL=2', $NOW_MS, $NOW_MS, 'recurring', $EXPERIENCE_NEXT);" 2>/dev/null

  echo "  ✅ 自动化任务已刷新（心跳×3 + 经验提炼×1）"
else
  echo "  ⚠️ 未找到自动化数据库，跳过"
fi
