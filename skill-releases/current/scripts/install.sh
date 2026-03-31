#!/bin/bash
# 逍遥派 · 安装脚本（全自动，零人工卡点）
# 用法: bash install.sh
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${CYAN}  逍遥派 · 安装传功长老${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"

# === 1. 生成令牌号 ===
TOKEN="XYP-$(openssl rand -hex 2 | tr '[:lower:]' '[:upper:]')"
DEVICE_NAME=$(scutil --get ComputerName 2>/dev/null || hostname -s 2>/dev/null || hostname | head -c 50)
SKILL_VERSION="0.0.6"
INSTALL_DATE=$(date +%Y-%m-%d)
API_BASE="http://119.29.181.188/xiaoyao/api"

echo -e "\n${GREEN}[1/7] 生成令牌号${NC}: $TOKEN"
echo -e "       设备名称: $DEVICE_NAME"

# === 2. 配置路径 ===
CODEBUDDY_DIR="$HOME/.codebuddy"
SKILL_DIR="$CODEBUDDY_DIR/skills/xiaoyao-pai"
RULES_DIR="$CODEBUDDY_DIR/rules"
MEMORY_RULES_DIR="$RULES_DIR/memory"
WORKSPACE="$HOME/.claw/workspace"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"

# === 3. 创建工作空间 ===
echo -e "${GREEN}[2/7] 创建工作空间${NC}: $WORKSPACE"
mkdir -p "$WORKSPACE"
mkdir -p "$SKILL_DIR/config"

# === 4. 写入节点配置 ===
cat > "$SKILL_DIR/config/node.json" << EOF
{
  "token": "$TOKEN",
  "device_name": "$DEVICE_NAME",
  "created": "$INSTALL_DATE",
  "skill_version": "$SKILL_VERSION",
  "api_base": "$API_BASE"
}
EOF

cat > "$SKILL_DIR/config/network.json" << EOF
{
  "canon": "https://github.com/xiaoyao-pai/xiaoyao-canon.git",
  "contrib": "https://github.com/xiaoyao-pai/xiaoyao-contrib.git",
  "api_base": "$API_BASE"
}
EOF

echo -e "${GREEN}[3/7] 节点配置已写入${NC}"

# === 5. 安装 Rules ===
echo -e "${GREEN}[4/7] 安装 Rules（观察眼 + 记忆规则）${NC}"
mkdir -p "$RULES_DIR" "$MEMORY_RULES_DIR"

# 复制观察眼
cp "$SKILL_ROOT/rules/xiaoyao-observer.mdc" "$RULES_DIR/" 2>/dev/null || echo -e "${YELLOW}  警告: 观察眼文件未找到${NC}"
# 复制记忆规则
cp "$SKILL_ROOT/rules/xiaoyao-memory.mdc" "$RULES_DIR/" 2>/dev/null || echo -e "${YELLOW}  警告: 记忆规则文件未找到${NC}"

# 复制记忆体系模板
for tpl in 00-核心身份.mdc 01-认知框架.mdc 02-行为习惯.mdc 03-技术画像.mdc; do
  if [ -f "$SKILL_ROOT/templates/memory/$tpl" ]; then
    cp "$SKILL_ROOT/templates/memory/$tpl" "$MEMORY_RULES_DIR/"
  fi
done
echo -e "       记忆体系骨架已安装"

# === 6. 安装子 Skill ===
echo -e "${GREEN}[5/7] 安装子 Skill（AI 日记 + 踩坑记录）${NC}"
SKILLS_DIR="$CODEBUDDY_DIR/skills"
for skill_dir in ai-diary pitfall-recorder; do
  src="$SKILL_ROOT/templates/skills/$skill_dir"
  dst="$SKILLS_DIR/xiaoyao-$skill_dir"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src"/* "$dst/" 2>/dev/null
    echo -e "       已安装: xiaoyao-$skill_dir"
  fi
done

# === 7. 注册到网络 ===
echo -e "${GREEN}[6/8] 注册到逍遥派网络${NC}"

# 7a. 本地注册
REGISTER_FILE="$SKILL_DIR/config/registration.json"
cat > "$REGISTER_FILE" << EOF
{
  "token": "$TOKEN",
  "skill_version": "$SKILL_VERSION",
  "installed_at": "$INSTALL_DATE",
  "status": "registered"
}
EOF

# 7b. 注册到逍遥派中心
REGISTER_RESP=$(curl -s -m 10 -X POST "$API_BASE/register" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"device_name\":\"$DEVICE_NAME\",\"skill_version\":\"$SKILL_VERSION\",\"installed_at\":\"$INSTALL_DATE\"}" 2>/dev/null)

if echo "$REGISTER_RESP" | grep -q '"status"'; then
  echo -e "       网络注册完成 ✅"
else
  echo -e "       本地注册完成"
  echo -e "       ${YELLOW}提示: 网络注册暂时不可用，不影响使用${NC}"
fi

# === 8. 下载正典经验（需注册后才能访问）===
echo -e "${GREEN}[7/8] 下载逍遥派正典经验${NC}"

CANON_LOCAL="$WORKSPACE/xiaoyao-canon-data"
mkdir -p "$CANON_LOCAL"

CANON_RESP=$(curl -s -m 30 "$API_BASE/canon/download?token=$TOKEN" 2>/dev/null)

if echo "$CANON_RESP" | python3 -c "
import sys, json, os
data = json.load(sys.stdin)
if data.get('status') != 'ok':
    print('FAILED')
    sys.exit(1)
files = data.get('files', {})
base = '$CANON_LOCAL'
count = 0
for rel_path, content in files.items():
    if rel_path.startswith('_'): continue  # 跳过内部文件
    full = os.path.join(base, rel_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(content)
    count += 1
print(f'OK:{count}')
" 2>/dev/null | grep -q "^OK:"; then
  CANON_COUNT=$(echo "$CANON_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len([k for k in d.get('files',{}) if not k.startswith('_')]))" 2>/dev/null)
  echo -e "       已下载 ${CANON_COUNT} 篇正典经验 ✅"
else
  echo -e "       ${YELLOW}正典下载失败（不影响核心功能，后续心跳会重试）${NC}"
fi

# === 9. 创建自动化任务 ===
echo -e "${GREEN}[8/8] 创建自动化任务${NC}"

# 自动化任务数据库路径（CodeBuddy CN）
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

if [ -z "$AUTOMATION_DB" ]; then
  echo -e "  ${YELLOW}未找到自动化任务数据库，跳过（不影响核心功能）${NC}"
else
  NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || date +%s000)

  # 心跳任务（每天 13:00 和 19:00）
  sqlite3 "$AUTOMATION_DB" "INSERT OR IGNORE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type)
    VALUES (
      'xiaoyao-heartbeat',
      '逍遥派心跳',
      '执行逍遥派心跳任务：运行 bash ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/heartbeat.sh，该脚本会拉取正典最新内容、检查 Skill 版本更新、向注册中心上报心跳。直接运行脚本即可，不需要额外操作。',
      'ACTIVE',
      '[\"$HOME\"]',
      'FREQ=DAILY;BYHOUR=13;BYMINUTE=0',
      $NOW_MS,
      $NOW_MS,
      'recurring'
    );" 2>/dev/null && echo -e "  已创建: 逍遥派心跳（每天 13:00）" || echo -e "  ${YELLOW}心跳任务已存在或创建失败${NC}"

  # 经验提炼任务（每天 21:00）
  sqlite3 "$AUTOMATION_DB" "INSERT OR IGNORE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type)
    VALUES (
      'xiaoyao-experience',
      '逍遥派经验提炼',
      '执行逍遥派经验提炼：运行 python3 ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/agent/experience_agent.py，该脚本会读取今日 AI 对话记录，提炼有价值的经验，脱敏后提交到逍遥派网络。直接运行脚本即可。',
      'ACTIVE',
      '[\"$HOME\"]',
      'FREQ=DAILY;BYHOUR=21;BYMINUTE=0',
      $NOW_MS,
      $NOW_MS,
      'recurring'
    );" 2>/dev/null && echo -e "  已创建: 逍遥派经验提炼（每天 21:00）" || echo -e "  ${YELLOW}经验提炼任务已存在或创建失败${NC}"

  echo -e "       自动化任务就绪"
fi

# === 完成 ===
echo -e "\n${CYAN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 逍遥派安装完成！${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e ""
echo -e "  令牌号: ${CYAN}$TOKEN${NC}"
echo -e "  工作空间: $WORKSPACE"
echo -e "  已安装:"
echo -e "    - 观察眼 Rules（每次对话自动观察）"
echo -e "    - 记忆规则 Rules（定义沉淀格式）"
echo -e "    - 记忆体系骨架（5 层，AI 逐步填入）"
echo -e "    - AI 日记 + 踩坑记录 Skill"
echo -e "    - 心跳任务（每天自动同步最新经验）"
echo -e "    - 经验提炼任务（每天自动提炼对话经验）"
echo -e ""
echo -e "  ${YELLOW}下一步${NC}: 正常使用 AI 即可，一切自动运行。"
echo -e ""
