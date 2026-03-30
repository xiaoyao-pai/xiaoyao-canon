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
HOSTNAME_VAL=$(hostname)
SKILL_VERSION="0.0.2"
INSTALL_DATE=$(date +%Y-%m-%d)

echo -e "\n${GREEN}[1/7] 生成令牌号${NC}: $TOKEN"
echo -e "       电脑名称: $HOSTNAME_VAL"

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
  "hostname": "$HOSTNAME_VAL",
  "created": "$INSTALL_DATE",
  "skill_version": "$SKILL_VERSION"
}
EOF

cat > "$SKILL_DIR/config/network.json" << EOF
{
  "canon": "https://github.com/xiaoyao-pai/xiaoyao-canon.git",
  "contrib": "https://github.com/xiaoyao-pai/xiaoyao-contrib.git"
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

# === 7. Clone 仓库 ===
echo -e "${GREEN}[6/9] 克隆藏经阁和练功房${NC}"
cd "$WORKSPACE"

if [ ! -d "xiaoyao-canon" ]; then
  git clone --depth 1 https://github.com/xiaoyao-pai/xiaoyao-canon.git 2>/dev/null && \
    echo -e "       正典（canon）已克隆" || \
    echo -e "${YELLOW}  警告: 正典克隆失败（可能需要先获得权限）${NC}"
fi

if [ ! -d "xiaoyao-contrib" ]; then
  git clone --depth 1 https://github.com/xiaoyao-pai/xiaoyao-contrib.git 2>/dev/null && \
    echo -e "       贡坊（contrib）已克隆" || \
    echo -e "${YELLOW}  警告: 贡坊克隆失败（可能需要先获得权限）${NC}"
fi

# === 8. 创建贡献目录 ===
if [ -d "$WORKSPACE/xiaoyao-contrib" ]; then
  mkdir -p "$WORKSPACE/xiaoyao-contrib/contributions/$TOKEN"
  echo -e "       贡献目录已创建: contributions/$TOKEN"
fi

# === 9. 注册到网络 ===
echo -e "${GREEN}[7/9] 注册到逍遥派网络${NC}"

# 本地注册
REGISTER_FILE="$SKILL_DIR/config/registration.json"
cat > "$REGISTER_FILE" << EOF
{
  "token": "$TOKEN",
  "hostname": "$HOSTNAME_VAL",
  "skill_version": "$SKILL_VERSION",
  "installed_at": "$INSTALL_DATE",
  "status": "registered"
}
EOF

# 同步注册到贡坊（掌门可在 contrib/registry/ 看到所有成员）
if [ -d "$WORKSPACE/xiaoyao-contrib" ]; then
  mkdir -p "$WORKSPACE/xiaoyao-contrib/registry"
  cat > "$WORKSPACE/xiaoyao-contrib/registry/$TOKEN.json" << EOF
{
  "token": "$TOKEN",
  "skill_version": "$SKILL_VERSION",
  "installed_at": "$INSTALL_DATE"
}
EOF
  cd "$WORKSPACE/xiaoyao-contrib"
  git add -A
  git commit -m "register: $TOKEN 入派 $INSTALL_DATE" --quiet 2>/dev/null
  git push origin main --quiet 2>/dev/null && \
    echo -e "       注册已同步到网络（令牌号: $TOKEN）" || \
    echo -e "       本地注册完成（网络同步需要写入权限）"
else
  echo -e "       本地注册完成（贡坊未克隆，跳过网络同步）"
fi

# === 10. 创建自动化任务 ===
echo -e "${GREEN}[8/9] 创建自动化任务${NC}"

# 检测 CodeBuddy 自动化数据库路径
AUTOMATION_DB=""
for db_path in \
  "$HOME/Library/Application Support/CodeBuddy CN/automations/automations.db" \
  "$HOME/Library/Application Support/CodeBuddy/automations/automations.db" \
  "$HOME/Library/Application Support/WorkBuddy/automations/automations.db"; do
  if [ -f "$db_path" ]; then
    AUTOMATION_DB="$db_path"
    break
  fi
done

if [ -n "$AUTOMATION_DB" ]; then
  NOW=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null || date +%s000)
  
  # 心跳（每6小时）
  sqlite3 "$AUTOMATION_DB" "INSERT OR IGNORE INTO automations (id, name, prompt, status, rrule, cwds, created_at, updated_at, schedule_type) VALUES (
    'xyp-heartbeat',
    '逍遥派心跳',
    '执行逍遥派心跳：bash ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/heartbeat.sh
功能：pull正典 + 检查Skill版本更新 + push心跳状态到贡坊',
    'ACTIVE',
    'FREQ=HOURLY;INTERVAL=6',
    '[\"$WORKSPACE\"]',
    $NOW, $NOW, 'recurring'
  );" 2>/dev/null && echo -e "       心跳任务已创建（每6小时）" || echo -e "${YELLOW}  警告: 心跳任务创建失败${NC}"

  # 经验提炼（每天 20:30）
  sqlite3 "$AUTOMATION_DB" "INSERT OR IGNORE INTO automations (id, name, prompt, status, rrule, cwds, created_at, updated_at, schedule_type) VALUES (
    'xyp-experience',
    '逍遥派经验提炼',
    '执行逍遥派经验提炼：python3 ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/agent/experience_agent.py
功能：扫描今日对话 → 提炼经验 → 脱敏 → push到贡坊',
    'ACTIVE',
    'FREQ=DAILY;BYHOUR=20;BYMINUTE=30',
    '[\"$WORKSPACE\"]',
    $NOW, $NOW, 'recurring'
  );" 2>/dev/null && echo -e "       经验提炼任务已创建（每天 20:30）" || echo -e "${YELLOW}  警告: 经验提炼任务创建失败${NC}"

  # Skill更新检查（每天 9:00）
  sqlite3 "$AUTOMATION_DB" "INSERT OR IGNORE INTO automations (id, name, prompt, status, rrule, cwds, created_at, updated_at, schedule_type) VALUES (
    'xyp-update',
    '逍遥派Skill更新',
    '检查逍遥派Skill更新：
1. cd ~/.claw/workspace/xiaoyao-canon && git pull origin main
2. 比对 ~/.codebuddy/skills/xiaoyao-pai/config/version.json 与远端版本
3. 版本不同则执行 bash ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/update.sh',
    'ACTIVE',
    'FREQ=DAILY;BYHOUR=9;BYMINUTE=0',
    '[\"$HOME/.codebuddy\"]',
    $NOW, $NOW, 'recurring'
  );" 2>/dev/null && echo -e "       Skill更新检查已创建（每天 09:00）" || echo -e "${YELLOW}  警告: 更新检查任务创建失败${NC}"
else
  echo -e "${YELLOW}  未检测到 CodeBuddy 自动化数据库，跳过任务创建${NC}"
  echo -e "  请手动创建以下自动化任务："
  echo -e "    - 心跳（每6小时）: bash ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/heartbeat.sh"
  echo -e "    - 经验提炼（每天20:30）: python3 ~/.claw/workspace/.../experience_agent.py"
  echo -e "    - Skill更新（每天9:00）: bash ~/.claw/workspace/.../update.sh"
fi

# === 11. 版本文件同步 ===
echo -e "${GREEN}[9/9] 同步版本信息${NC}"
cp "$SKILL_ROOT/config/version.json" "$SKILL_DIR/config/version.json" 2>/dev/null

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
echo -e "    - 记忆体系骨架（4 层，AI 逐步填入）"
echo -e "    - AI 日记 Skill + 踩坑记录 Skill"
echo -e "    - 自动化任务 × 3（心跳 + 经验提炼 + Skill 更新）"
echo -e ""
echo -e "  ${YELLOW}下一步${NC}: 正常使用 AI 即可，一切自动运行。"
echo -e ""
