#!/usr/bin/env python3
"""
逍遥派 · 经验提炼 Agent（弟子端每日运行）

功能：读取 AI 对话记录 → 提炼经验 → 安全脱敏 → 输出到贡坊目录
数据源：sessions vscdb 为主，.codebuddy/memory 为辅
"""

import json
import os
import re
import sqlite3
import subprocess
from datetime import datetime, timedelta
from pathlib import Path


def get_node_config():
    """读取节点配置"""
    config_path = Path.home() / ".codebuddy" / "skills" / "xiaoyao-pai" / "config" / "node.json"
    if not config_path.exists():
        raise FileNotFoundError("未找到节点配置，请先运行 install.sh")
    return json.loads(config_path.read_text())


def get_today_sessions():
    """从 sessions 数据库获取今天有更新的会话"""
    sessions = []
    today_start = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    today_start_ms = int(today_start.timestamp() * 1000)

    db_paths = [
        Path.home() / "Library" / "Application Support" / "CodeBuddy CN" / "codebuddy-sessions.vscdb",
        Path.home() / "Library" / "Application Support" / "WorkBuddy" / "codebuddy-sessions.vscdb",
    ]

    for db_path in db_paths:
        if not db_path.exists():
            continue
        try:
            conn = sqlite3.connect(str(db_path))
            cursor = conn.execute("SELECT value FROM ItemTable WHERE key LIKE 'session:%'")
            for (value,) in cursor:
                try:
                    data = json.loads(value)
                    updated = data.get("updatedAt", 0)
                    if updated >= today_start_ms:
                        sessions.append({
                            "id": data.get("conversationId", ""),
                            "title": data.get("title", "")[:100],
                            "cwd": data.get("cwd", ""),
                            "updated": datetime.fromtimestamp(updated / 1000).strftime("%H:%M"),
                            "source": "CodeBuddy" if "CodeBuddy" in str(db_path) else "WorkBuddy",
                        })
                except (json.JSONDecodeError, KeyError):
                    pass
            conn.close()
        except Exception as e:
            print(f"  警告: 读取 {db_path.name} 失败: {e}")

    return sessions


def get_brain_overview(conversation_id):
    """读取会话的 brain overview"""
    brain_paths = [
        Path.home() / "Library" / "Application Support" / "CodeBuddy CN" / "User" / "globalStorage" / "tencent-cloud.coding-copilot" / "brain" / conversation_id / "overview.md",
        Path.home() / "Library" / "Application Support" / "WorkBuddy" / "User" / "globalStorage" / "tencent-cloud.coding-copilot" / "brain" / conversation_id / "overview.md",
    ]
    for path in brain_paths:
        if path.exists():
            return path.read_text(encoding="utf-8")[:2000]  # 截取前 2000 字符
    return None


def get_memory_files():
    """读取今日的 memory 文件作为补充"""
    today = datetime.now().strftime("%Y-%m-%d")
    memories = []
    search_dirs = [
        Path.home() / "CodeBuddy",
        Path.home() / "WorkBuddy",
        Path.home() / "Desktop",
    ]

    for base in search_dirs:
        if not base.exists():
            continue
        for memory_file in base.rglob(f"*/{today}.md"):
            if "node_modules" in str(memory_file):
                continue
            if ".memory" in str(memory_file) or ".codebuddy/memory" in str(memory_file):
                try:
                    content = memory_file.read_text(encoding="utf-8")[:1000]
                    memories.append({"path": str(memory_file), "content": content})
                except Exception:
                    pass

    return memories


def sanitize(text):
    """安全脱敏：只脱密钥/Token/密码/IP，保留技术场景"""
    # API Keys / Tokens
    text = re.sub(r'[a-zA-Z0-9_-]{20,}(?=[\s"\',\n])', "[REDACTED]", text)
    # IP 地址
    text = re.sub(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', "[IP]", text)
    # 密码字段
    text = re.sub(r'(?i)(password|secret|token|key)\s*[=:]\s*\S+', r'\1=[REDACTED]', text)
    return text


def generate_experience(sessions, memories):
    """生成经验总结"""
    today = datetime.now().strftime("%Y-%m-%d")
    lines = [f"# 经验提炼 {today}\n"]

    # 过滤掉自动化任务本身
    real_sessions = [s for s in sessions if "日记助手" not in s["title"] and "自动化" not in s["title"]]

    if not real_sessions and not memories:
        return None  # 无活动，不生成

    if real_sessions:
        lines.append("## 今日对话活动\n")
        for s in real_sessions:
            lines.append(f"- [{s['updated']}] ({s['source']}) {s['title']}")
            overview = get_brain_overview(s["id"])
            if overview:
                # 提取前几行作为摘要
                summary_lines = [l.strip() for l in overview.split("\n") if l.strip() and not l.startswith("#")][:3]
                for sl in summary_lines:
                    lines.append(f"  - {sl}")
        lines.append("")

    if memories:
        lines.append("## 补充记忆\n")
        for m in memories:
            lines.append(f"- 来源: {m['path']}")
            lines.append(f"  {m['content'][:200]}")
        lines.append("")

    return sanitize("\n".join(lines))


def main():
    print("[经验提炼] 开始执行...")

    config = get_node_config()
    token = config["token"]
    print(f"[经验提炼] 令牌号: {token}")

    # 收集数据
    sessions = get_today_sessions()
    print(f"[经验提炼] 今日会话: {len(sessions)} 个")

    memories = get_memory_files()
    print(f"[经验提炼] 今日记忆文件: {len(memories)} 个")

    # 生成经验
    experience = generate_experience(sessions, memories)

    if experience is None:
        print("[经验提炼] 今日无有效活动，跳过")
        return

    # 保存到贡坊目录
    today = datetime.now().strftime("%Y-%m-%d")
    contrib_dir = Path.home() / ".claw" / "workspace" / "xiaoyao-contrib" / "contributions" / token
    contrib_dir.mkdir(parents=True, exist_ok=True)

    output_file = contrib_dir / f"{today}-experience.md"
    output_file.write_text(experience, encoding="utf-8")
    print(f"[经验提炼] 已保存: {output_file}")

    # 尝试 git push
    contrib_root = Path.home() / ".claw" / "workspace" / "xiaoyao-contrib"
    if (contrib_root / ".git").exists():
        try:
            subprocess.run(["git", "add", "-A"], cwd=contrib_root, capture_output=True)
            subprocess.run(
                ["git", "commit", "-m", f"experience: {token} {today}"],
                cwd=contrib_root, capture_output=True
            )
            result = subprocess.run(
                ["git", "push", "origin", "main"],
                cwd=contrib_root, capture_output=True, text=True
            )
            if result.returncode == 0:
                print("[经验提炼] 已推送到贡坊")
            else:
                print(f"[经验提炼] 推送失败: {result.stderr[:200]}")
        except Exception as e:
            print(f"[经验提炼] Git 操作失败: {e}")

    print("[经验提炼] 完成")


if __name__ == "__main__":
    main()
