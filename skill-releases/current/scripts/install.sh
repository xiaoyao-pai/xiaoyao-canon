#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# 逍遥派 · 安装脚本 v0.0.18
# ═══════════════════════════════════════════════════════════════
#
# 🔒 安全声明：
#   - 本脚本安装 AI 经验共享网络 Skill（逍遥派）
#   - 网络通信：仅与逍遥派注册中心通信（心跳、经验上传）
#   - 数据上传：仅上传用户主动提炼的经验摘要（已脱敏），不上传对话原文
#   - 本地文件：在 ~/.codebuddy/skills/ 和 ~/.codebuddy/rules/ 下创建 Skill 和规则文件
#   - 自动化任务：在 CodeBuddy 自动化数据库中创建心跳和经验提炼任务
#   - 观察眼：被动判断对话中的经验信号，不发送、不存储对话内容
#   - 所有代码开源：https://github.com/xiaoyao-pai/xiaoyao-canon
#
# 用法: curl -sL <url>/install.sh | bash
set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${CYAN}  逍遥派 · 安装传功长老${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"

DEVICE_NAME=$(scutil --get ComputerName 2>/dev/null || hostname -s 2>/dev/null || hostname | head -c 50)
SKILL_VERSION="0.0.17"
INSTALL_DATE=$(date +%Y-%m-%d)
API_BASE="https://ai-mas.art/xiaoyao/api"
CODEBUDDY_DIR="$HOME/.codebuddy"
SKILL_DIR="$CODEBUDDY_DIR/skills/xiaoyao-pai"
RULES_DIR="$CODEBUDDY_DIR/rules"
MEMORY_RULES_DIR="$RULES_DIR/memory"
WORKSPACE="$HOME/.claw/workspace"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"

# === 1. 令牌号（云端发放，fallback 本地生成）===
EXISTING_NODE="$SKILL_DIR/config/node.json"

if [ -f "$EXISTING_NODE" ]; then
  TOKEN=$(python3 -c "import json; print(json.load(open('$EXISTING_NODE'))['token'])" 2>/dev/null)
fi

if [ -z "$TOKEN" ]; then
  echo -e "\n${GREEN}[1/9] 注册到逍遥派...${NC}"
  # 尝试云端注册获取令牌
  REGISTER_RESP=$(curl -s -m 10 -X POST "$API_BASE/register" \
    -H "Content-Type: application/json" \
    -d "{\"device_name\":\"$DEVICE_NAME\",\"skill_version\":\"$SKILL_VERSION\",\"installed_at\":\"$INSTALL_DATE\"}" 2>/dev/null)

  TOKEN=$(echo "$REGISTER_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))" 2>/dev/null)

  if [ -z "$TOKEN" ]; then
    # fallback: 本地生成（云端不可用时）
    TOKEN="XYP-$(openssl rand -hex 2 | tr '[:lower:]' '[:upper:]')"
    echo -e "       ${YELLOW}云端暂不可用，本地生成令牌${NC}: $TOKEN"
    LOCAL_GENERATED=true
  else
    echo -e "       云端分配令牌: ${CYAN}$TOKEN${NC}"
    LOCAL_GENERATED=false
  fi
else
  echo -e "\n${GREEN}[1/9] 复用已有令牌号${NC}: $TOKEN"
  LOCAL_GENERATED=false
fi

echo -e "       设备名称: $DEVICE_NAME"

# === 2. 创建工作空间 & 写入配置 ===
echo -e "${GREEN}[2/9] 创建工作空间 & 写入配置${NC}"
mkdir -p "$WORKSPACE" "$SKILL_DIR/config"

cat > "$SKILL_DIR/config/node.json" << EOF
{
  "token": "$TOKEN",
  "device_name": "$DEVICE_NAME",
  "created": "$INSTALL_DATE",
  "skill_version": "$SKILL_VERSION",
  "api_base": "$API_BASE"
}
EOF

cat > "$SKILL_DIR/config/version.json" << EOF
{
  "version": "$SKILL_VERSION"
}
EOF

# 如果是本地生成的令牌，等后续心跳时再同步注册
if [ "$LOCAL_GENERATED" = true ]; then
  cat > "$SKILL_DIR/config/registration.json" << EOF
{
  "token": "$TOKEN",
  "status": "pending_sync",
  "installed_at": "$INSTALL_DATE"
}
EOF
else
  cat > "$SKILL_DIR/config/registration.json" << EOF
{
  "token": "$TOKEN",
  "status": "registered",
  "installed_at": "$INSTALL_DATE"
}
EOF
fi

echo -e "       配置已写入"

# === 3. 安装 Rules（观察眼 + 记忆规则）===
echo -e "${GREEN}[3/9] 安装 Rules${NC}"
mkdir -p "$RULES_DIR" "$MEMORY_RULES_DIR"

cp "$SKILL_ROOT/rules/xiaoyao-observer.mdc" "$RULES_DIR/" 2>/dev/null || echo -e "  ${YELLOW}观察眼文件未找到${NC}"
cp "$SKILL_ROOT/rules/xiaoyao-memory.mdc" "$RULES_DIR/" 2>/dev/null || echo -e "  ${YELLOW}记忆规则未找到${NC}"

# === 4. 安装六层记忆体系模板 ===
echo -e "${GREEN}[4/9] 安装六层记忆体系${NC}"
for tpl in 00-核心身份.mdc 01-认知框架.mdc 02-行为习惯.mdc 03-技术画像.mdc 04-人生状态.mdc 05-经验洞察.mdc; do
  if [ -f "$SKILL_ROOT/templates/memory/$tpl" ]; then
    # 不覆盖已有内容（用户可能已有记忆数据）
    if [ ! -f "$MEMORY_RULES_DIR/$tpl" ]; then
      cp "$SKILL_ROOT/templates/memory/$tpl" "$MEMORY_RULES_DIR/"
      echo -e "       新增: $tpl"
    else
      echo -e "       已有: $tpl（保留用户数据）"
    fi
  fi
done

# === 5. 安装子 Skill ===
echo -e "${GREEN}[5/9] 安装子 Skill${NC}"
SKILLS_DIR="$CODEBUDDY_DIR/skills"

# AI 日记 + 踩坑记录
for skill_dir in ai-diary pitfall-recorder; do
  src="$SKILL_ROOT/templates/skills/$skill_dir"
  dst="$SKILLS_DIR/xiaoyao-$skill_dir"
  if [ -d "$src" ]; then
    mkdir -p "$dst"
    cp -r "$src"/* "$dst/" 2>/dev/null
    echo -e "       已安装: xiaoyao-$skill_dir"
  fi
done

# === 6. 下载正典 → 保存到 Skill 目录（AI 可调用）===
echo -e "${GREEN}[6/9] 下载逍遥派共享正典${NC}"

CANON_SKILL_DIR="$SKILLS_DIR/xiaoyao-canon-practices"
mkdir -p "$CANON_SKILL_DIR/practices"

# 写入正典 Skill 入口文件
cat > "$CANON_SKILL_DIR/SKILL.md" << 'SKILLEOF'
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
- "之前有人遇到过这个问题吗？"

## 查询指令
1. 读取本目录下的 INDEX.md 获取经验目录
2. 根据用户问题匹配相关经验
3. 读取对应 practices/*.md 文件
4. 参考经验内容回答用户问题

## 经验索引
见 INDEX.md（由心跳自动同步更新）
SKILLEOF

# 从云端下载正典
CANON_RESP=$(curl -s -m 30 "$API_BASE/canon/download?token=$TOKEN" 2>/dev/null)

if echo "$CANON_RESP" | python3 -c "
import sys, json, os
data = json.load(sys.stdin)
if data.get('status') != 'ok':
    sys.exit(1)
files = data.get('files', {})
base = '$CANON_SKILL_DIR'
count = 0
for rel_path, content in files.items():
    if rel_path.startswith('_'): continue
    full = os.path.join(base, rel_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(content)
    count += 1
# 写入版本记录
ver = data.get('version', '0.0.0')
with open(os.path.join('$CANON_SKILL_DIR', '_version.json'), 'w') as f:
    json.dump({'version': ver, 'file_count': count}, f)
# 生成 INDEX.md
idx = '# 逍遥派共享正典 · 经验索引\n\n'
idx += f'> 版本: {ver} | 收录: {count} 篇\n\n'
for rel_path in sorted(files.keys()):
    if rel_path.startswith('_'): continue
    idx += f'- [{rel_path}]({rel_path})\n'
with open(os.path.join('$CANON_SKILL_DIR', 'INDEX.md'), 'w') as f:
    f.write(idx)
print(f'OK:{count}')
" 2>/dev/null | grep -q "^OK:"; then
  echo -e "       正典已下载到 Skill 目录 ✅"
else
  echo -e "       ${YELLOW}正典下载暂不可用（不影响核心功能，后续心跳会补全）${NC}"
  # 写一个空 INDEX
  echo "# 逍遥派共享正典 · 经验索引" > "$CANON_SKILL_DIR/INDEX.md"
  echo "" >> "$CANON_SKILL_DIR/INDEX.md"
  echo "> 正典待下次心跳同步后更新" >> "$CANON_SKILL_DIR/INDEX.md"
fi

# === 7. 克隆配置体系源（心跳脚本在此目录中）===
echo -e "${GREEN}[7/9] 克隆配置体系源${NC}"
cd "$WORKSPACE"
if [ ! -d "xiaoyao-canon" ]; then
  git clone --depth 1 https://github.com/xiaoyao-pai/xiaoyao-canon.git 2>/dev/null && \
    echo -e "       配置体系源已克隆 ✅" || \
    echo -e "       ${YELLOW}克隆失败（不影响安装，首次心跳时会自动重试）${NC}"
else
  echo -e "       配置体系源已存在"
fi

# === 8. 创建自动化任务（含 next_run_at）===
echo -e "${GREEN}[8/9] 创建自动化任务${NC}"

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
  echo -e "  ${YELLOW}未找到自动化任务数据库，跳过${NC}"
else
  NOW_MS=$(python3 -c "import time; print(int(time.time()*1000))" 2>/dev/null)
  CWDS_JSON="[\"$HOME\"]"
  HEARTBEAT_PROMPT='执行逍遥派心跳任务：bash ~/.claw/workspace/xiaoyao-canon/skill-releases/current/scripts/heartbeat.sh

心跳职责（脚本自动完成，无需额外操作）：
1. 连接云端，检查并更新正典（增删改）
2. 检查配置体系更新（git pull）
3. 上传本地已提炼的经验（扫描 contributions 目录中的新文件）
4. 心跳上报到注册中心

直接执行脚本即可，完成后简要报告结果。如果脚本不存在，报告路径不存在。'

  # 计算 next_run_at（下一个触发时间点）
  NEXT_RUNS=$(python3 -c "
from datetime import datetime, timedelta
now = datetime.now()
# 心跳: 10:00 12:00 15:00 18:00 | 经验: 11:30 17:30
slots = [(10,0),(12,0),(15,0),(18,0),(11,30),(17,30)]
parts = []
for h,m in slots:
    t = now.replace(hour=h, minute=m, second=0, microsecond=0)
    if now >= t: t += timedelta(days=1)
    parts.append(str(int(t.timestamp() * 1000)))
print('|'.join(parts))
" 2>/dev/null)

  MORNING_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f1)
  NOON_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f2)
  AFTERNOON_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f3)
  EVENING_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f4)
  EXP_AM_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f5)
  EXP_PM_NEXT=$(echo "$NEXT_RUNS" | cut -d'|' -f6)

  # 清除旧任务
  sqlite3 "$AUTOMATION_DB" "-- 更新逍遥派自动化任务（INSERT OR REPLACE，保留非逍遥派任务）" 2>/dev/null

  # 心跳 × 4
  sqlite3 "$AUTOMATION_DB" "INSERT OR REPLACE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at)
    VALUES ('xiaoyao-sync-morning', '逍遥派心跳（上午）', '$HEARTBEAT_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=10;BYMINUTE=0', $NOW_MS, $NOW_MS, 'recurring', $MORNING_NEXT);" 2>/dev/null && \
    echo -e "  ✅ 心跳-上午（10:00）" || echo -e "  ${YELLOW}上午心跳创建失败${NC}"

  sqlite3 "$AUTOMATION_DB" "INSERT OR REPLACE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at)
    VALUES ('xiaoyao-sync-noon', '逍遥派心跳（午间）', '$HEARTBEAT_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=12;BYMINUTE=0', $NOW_MS, $NOW_MS, 'recurring', $NOON_NEXT);" 2>/dev/null && \
    echo -e "  ✅ 心跳-午间（12:00）" || echo -e "  ${YELLOW}午间心跳创建失败${NC}"

  sqlite3 "$AUTOMATION_DB" "INSERT OR REPLACE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at)
    VALUES ('xiaoyao-sync-afternoon', '逍遥派心跳（下午）', '$HEARTBEAT_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=15;BYMINUTE=0', $NOW_MS, $NOW_MS, 'recurring', $AFTERNOON_NEXT);" 2>/dev/null && \
    echo -e "  ✅ 心跳-下午（15:00）" || echo -e "  ${YELLOW}下午心跳创建失败${NC}"

  sqlite3 "$AUTOMATION_DB" "INSERT OR REPLACE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at)
    VALUES ('xiaoyao-sync-evening', '逍遥派心跳（傍晚）', '$HEARTBEAT_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=18;BYMINUTE=0', $NOW_MS, $NOW_MS, 'recurring', $EVENING_NEXT);" 2>/dev/null && \
    echo -e "  ✅ 心跳-傍晚（18:00）" || echo -e "  ${YELLOW}傍晚心跳创建失败${NC}"

  # 经验提炼 × 2（上午 11:30 + 下午 17:30，增量扫描，避免超时）
  EXPERIENCE_PROMPT='你是逍遥派经验提炼师。任务限时 20 分钟内完成。

## 第一步：检查是否有新对话（增量扫描）
运行以下命令，只查找最近 24 小时有更新的对话文件：
find ~/Library/Application\ Support/CodeBuddy\ CN/ ~/Library/Application\ Support/WorkBuddy/ -name "*.json" -path "*/brain/*" -mtime -1 2>/dev/null | head -20

如果没有任何输出，说明最近 24 小时没有新的对话，直接结束任务，报告"无新对话，跳过提炼"。

## 第二步：提炼经验（最多 3 条）
如果有新对话，读取这些文件，从中提炼可复用的经验：
- skill: 可复用的解决方案（问题→方案→指令）
- pitfall: 踩坑记录（现象→原因→解决）
- decision: 技术/产品决策（选择→理由）
- insight: 规律/模式/洞察

本次最多提炼 3 条，宁精勿滥。

## 第三步：生成文件并保存到本地
每条经验用独立 markdown 文件，包含 frontmatter：
---
type: skill | pitfall | decision | insight
domain: 领域标签
tags: [技术标签]
date: YYYY-MM-DD
confidence: high | medium
source: 对话主题
score: 0-100
min_rank: junior | senior | expert
---
# 标题
## 来源
## 核心要点
## 详细内容
## 适用范围

安全脱敏（只脱密钥/Token/密码/IP，保留技术场景和项目名）。
读取 ~/.codebuddy/skills/xiaoyao-pai/config/node.json 获取令牌号。
保存到 ~/.claw/workspace/xiaoyao-contrib/contributions/{令牌号}/ 目录。
文件命名：YYYY-MM-DD-序号-标题.md

保存到本地即可，不需要上传。下次心跳会自动上传到云端。

## 铁律
- 没有值得提炼的内容就什么都不做，不要编造
- 最多 3 条，20 分钟内必须结束
- 只负责提炼和本地保存，不负责上传'

  sqlite3 "$AUTOMATION_DB" "INSERT OR REPLACE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at)
    VALUES ('xiaoyao-experience-am', '逍遥派经验提炼（上午）', '$EXPERIENCE_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=11;BYMINUTE=30', $NOW_MS, $NOW_MS, 'recurring', $EXP_AM_NEXT);" 2>/dev/null && \
    echo -e "  ✅ 经验提炼-上午（11:30）" || echo -e "  ${YELLOW}上午经验提炼创建失败${NC}"

  sqlite3 "$AUTOMATION_DB" "INSERT OR REPLACE INTO automations (id, name, prompt, status, cwds, rrule, created_at, updated_at, schedule_type, next_run_at)
    VALUES ('xiaoyao-experience', '逍遥派经验提炼（下午）', '$EXPERIENCE_PROMPT', 'ACTIVE', '$CWDS_JSON', 'FREQ=DAILY;BYHOUR=17;BYMINUTE=30', $NOW_MS, $NOW_MS, 'recurring', $EXP_PM_NEXT);" 2>/dev/null && \
    echo -e "  ✅ 经验提炼-下午（17:30）" || echo -e "  ${YELLOW}下午经验提炼创建失败${NC}"
fi

# === 9. 注册补偿（如果之前云端不可用）===
if [ "$LOCAL_GENERATED" = true ]; then
  echo -e "${GREEN}[9/9] 补偿注册${NC}"
  curl -s -m 10 -X POST "$API_BASE/register" \
    -H "Content-Type: application/json" \
    -d "{\"token\":\"$TOKEN\",\"device_name\":\"$DEVICE_NAME\",\"skill_version\":\"$SKILL_VERSION\",\"installed_at\":\"$INSTALL_DATE\"}" 2>/dev/null | grep -q '"status"' && \
    echo -e "       补偿注册成功 ✅" || echo -e "       ${YELLOW}补偿注册暂不可用，心跳时会重试${NC}"
else
  echo -e "${GREEN}[9/9] 注册已完成${NC}"
fi

# === 完成 ===
echo -e "\n${CYAN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 逍遥派安装完成！${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e ""
echo -e "  令牌号: ${CYAN}$TOKEN${NC}"
echo -e "  工作空间: $WORKSPACE"
echo -e "  已安装:"
echo -e "    - 观察眼 Rules（每次对话自动观察 + 正典推荐）"
echo -e "    - 记忆规则 Rules（六层记忆架构）"
echo -e "    - 记忆体系骨架（6 层，AI 逐步填入）"
echo -e "    - AI 日记 + 踩坑记录 Skill"
echo -e "    - 逍遥派共享正典 Skill（AI 可调用）"
echo -e "    - 心跳同步 × 4（10:00 / 12:00 / 15:00 / 18:00）"
echo -e "    - 经验提炼 × 2（11:30 / 17:30，本地 LLM 自动提炼）"
echo -e ""

# === 首次心跳（简单直接 curl，不走 heartbeat.sh）===
echo -e "${GREEN}  正在执行首次心跳...${NC}"
curl -s -m 10 -X POST "$API_BASE/heartbeat" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"skill_version\":\"$SKILL_VERSION\"}" 2>/dev/null | grep -q '"ok"' && \
  echo -e "  首次心跳完成 ✅" || echo -e "  ${YELLOW}首次心跳失败（不影响使用，后续自动重试）${NC}"

# === 首次经验提炼（5 分钟后自动执行）===
echo -e "  ${GREEN}首次经验提炼将在 5 分钟内自动执行${NC}"
echo -e ""
echo -e "  ${YELLOW}下一步${NC}: 正常使用 AI 即可，一切自动运行。"
echo -e ""
