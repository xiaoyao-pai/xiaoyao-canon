#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# 逍遥派 · 卸载脚本
# ═══════════════════════════════════════════════════════════════
#
# 🔒 安全说明：
#   - 仅删除逍遥派安装的文件和自动化任务
#   - 不影响 CodeBuddy 其他 Skill、Rules 或自动化任务
#   - 可选保留记忆文件（你的 AI 记忆不会丢失）
#
# 用法: curl -sL <url>/uninstall.sh | bash
#   或: bash uninstall.sh --keep-memory  （保留记忆文件）

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

KEEP_MEMORY=false
if [ "$1" = "--keep-memory" ]; then
  KEEP_MEMORY=true
fi

echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${RED}  逍遥派 · 卸载${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo ""

CODEBUDDY_DIR="$HOME/.codebuddy"
SKILLS_DIR="$CODEBUDDY_DIR/skills"
RULES_DIR="$CODEBUDDY_DIR/rules"
MEMORY_DIR="$RULES_DIR/memory"
WORKSPACE="$HOME/.claw/workspace"

# === 1. 读取令牌号 ===
TOKEN=""
NODE_CONFIG="$SKILLS_DIR/xiaoyao-pai/config/node.json"
if [ -f "$NODE_CONFIG" ]; then
  TOKEN=$(python3 -c "import json; print(json.load(open('$NODE_CONFIG'))['token'])" 2>/dev/null || echo "")
fi
if [ -n "$TOKEN" ]; then
  echo -e "  令牌号: ${CYAN}$TOKEN${NC}"
else
  echo -e "  ${YELLOW}未找到令牌号（可能未安装或已卸载）${NC}"
fi

# === 2. 删除自动化任务 ===
echo -e "\n${GREEN}[1/5] 清理自动化任务...${NC}"
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
  COUNT=$(sqlite3 "$AUTOMATION_DB" "SELECT COUNT(*) FROM automations WHERE id LIKE 'xiaoyao-%';" 2>/dev/null || echo "0")
  sqlite3 "$AUTOMATION_DB" "DELETE FROM automations WHERE id LIKE 'xiaoyao-%';" 2>/dev/null
  echo -e "  已删除 ${COUNT} 个自动化任务 ✅"
else
  echo -e "  ${YELLOW}未找到自动化数据库，跳过${NC}"
fi

# === 3. 删除 Skill 目录 ===
echo -e "${GREEN}[2/5] 清理 Skill 文件...${NC}"
REMOVED=0

# 主 Skill
if [ -d "$SKILLS_DIR/xiaoyao-pai" ]; then
  rm -rf "$SKILLS_DIR/xiaoyao-pai"
  echo -e "  删除 xiaoyao-pai ✅"
  REMOVED=$((REMOVED + 1))
fi

# 正典 Skill
if [ -d "$SKILLS_DIR/xiaoyao-canon-practices" ]; then
  rm -rf "$SKILLS_DIR/xiaoyao-canon-practices"
  echo -e "  删除 xiaoyao-canon-practices ✅"
  REMOVED=$((REMOVED + 1))
fi

# 独立正典 Skill（canon-* 开头的）
for d in "$SKILLS_DIR"/canon-*; do
  if [ -d "$d" ]; then
    rm -rf "$d"
    REMOVED=$((REMOVED + 1))
  fi
done

if [ $REMOVED -gt 0 ]; then
  echo -e "  共删除 ${REMOVED} 个 Skill 目录 ✅"
else
  echo -e "  ${YELLOW}无 Skill 目录需要删除${NC}"
fi

# === 4. 删除 Rules ===
echo -e "${GREEN}[3/5] 清理 Rules 文件...${NC}"
RULES_REMOVED=0

for rule in "xiaoyao-observer.mdc" "xiaoyao-memory.mdc"; do
  if [ -f "$RULES_DIR/$rule" ]; then
    rm -f "$RULES_DIR/$rule"
    echo -e "  删除 $rule ✅"
    RULES_REMOVED=$((RULES_REMOVED + 1))
  fi
done

# 记忆文件
if [ "$KEEP_MEMORY" = true ]; then
  echo -e "  ${YELLOW}保留记忆文件（--keep-memory）${NC}"
else
  if [ -d "$MEMORY_DIR" ]; then
    MEMORY_COUNT=$(ls "$MEMORY_DIR"/*.mdc 2>/dev/null | wc -l | tr -d ' ')
    if [ "$MEMORY_COUNT" -gt 0 ]; then
      rm -f "$MEMORY_DIR"/*.mdc
      echo -e "  删除 ${MEMORY_COUNT} 个记忆文件 ✅"
      RULES_REMOVED=$((RULES_REMOVED + MEMORY_COUNT))
      # 如果目录空了就删掉
      rmdir "$MEMORY_DIR" 2>/dev/null || true
    fi
  fi
fi

if [ $RULES_REMOVED -eq 0 ]; then
  echo -e "  ${YELLOW}无 Rules 文件需要删除${NC}"
fi

# === 5. 清理 Hooks ===
echo -e "${GREEN}[4/6] 清理自动审批 Hooks...${NC}"
if [ -f "$CODEBUDDY_DIR/hooks/auto_approve.py" ]; then
  rm -f "$CODEBUDDY_DIR/hooks/auto_approve.py"
  echo -e "  删除 auto_approve.py ✅"
  # 从 settings.json 中移除 hooks 配置
  if [ -f "$CODEBUDDY_DIR/settings.json" ]; then
    python3 -c "
import json
f='$CODEBUDDY_DIR/settings.json'
d=json.load(open(f))
if 'hooks' in d: del d['hooks']
json.dump(d,open(f,'w'),indent=4,ensure_ascii=False)
" 2>/dev/null && echo -e "  hooks 配置已清理 ✅"
  fi
else
  echo -e "  ${YELLOW}无 hooks 需要清理${NC}"
fi

# === 6. 清理工作区 ===
echo -e "${GREEN}[5/6] 清理工作区...${NC}"
WS_REMOVED=0

for ws_dir in "xiaoyao-canon" "xiaoyao-contrib" "xiaoyao-canon-harvest"; do
  if [ -d "$WORKSPACE/$ws_dir" ]; then
    rm -rf "$WORKSPACE/$ws_dir"
    echo -e "  删除 $ws_dir ✅"
    WS_REMOVED=$((WS_REMOVED + 1))
  fi
done

if [ $WS_REMOVED -eq 0 ]; then
  echo -e "  ${YELLOW}无工作区目录需要删除${NC}"
fi

# === 6. 完成 ===
echo -e "${GREEN}[6/6] 卸载完成${NC}"
echo ""
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "${GREEN}  ✅ 逍遥派已卸载${NC}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo ""
if [ -n "$TOKEN" ]; then
  echo -e "  你的令牌号 ${CYAN}$TOKEN${NC} 仍保留在云端注册表中"
  echo -e "  如需重新安装，令牌号会自动复用"
fi
if [ "$KEEP_MEMORY" = true ]; then
  echo -e "  ${YELLOW}记忆文件已保留在 $MEMORY_DIR${NC}"
fi
echo ""
echo -e "  重新安装: curl -sL https://raw.githubusercontent.com/xiaoyao-pai/xiaoyao-canon/main/skill-releases/current/scripts/install.sh | bash"
echo ""
