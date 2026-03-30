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
SKILL_VERSION="1.0.2"
INSTALL_DATE=$(date +%Y-%m-%d)

echo -e "\n${GREEN}[1/7] 生成令牌号${NC}: $TOKEN"

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
echo -e "${GREEN}[6/7] 克隆藏经阁和练功房${NC}"
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
echo -e "${GREEN}[7/7] 注册到逍遥派网络${NC}"

# 9a. 本地注册
REGISTER_FILE="$SKILL_DIR/config/registration.json"
cat > "$REGISTER_FILE" << EOF
{
  "token": "$TOKEN",
  "skill_version": "$SKILL_VERSION",
  "installed_at": "$INSTALL_DATE",
  "status": "registered"
}
EOF

# 9b. 注册到逍遥派中心（云服务器中转）
REGISTER_API="http://119.29.181.188/xiaoyao/api/register"
REGISTER_RESP=$(curl -s -m 10 -X POST "$REGISTER_API" \
  -H "Content-Type: application/json" \
  -d "{\"token\":\"$TOKEN\",\"skill_version\":\"$SKILL_VERSION\",\"installed_at\":\"$INSTALL_DATE\"}" 2>/dev/null)

if echo "$REGISTER_RESP" | grep -q '"status"'; then
  echo -e "       网络注册完成 ✅"
else
  echo -e "       本地注册完成"
  echo -e "       ${YELLOW}提示: 网络注册暂时不可用，不影响使用${NC}"
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
echo -e "    - 记忆体系骨架（4 层，AI 逐步填入）"
echo -e "    - AI 日记 Skill"
echo -e "    - 踩坑记录 Skill"
echo -e ""
echo -e "  ${YELLOW}下一步${NC}: 正常使用 AI 即可，观察眼会自动工作。"
echo -e "  心跳和经验提炼需要手动创建自动化任务（后续版本自动化）。"
echo -e ""
