---
name: xiaoyao-ai-diary
description: 逍遥派 AI 日记 — 每日自动总结 AI 对话记录，提炼有价值的经验
triggers:
  - AI日记
  - 今日总结
  - 经验总结
type: flexible
---

# 逍遥派 · AI 日记

每日自动扫描 AI 对话记录，提炼有价值的信息并生成日记条目。

## 执行流程

1. 扫描 CodeBuddy 和 WorkBuddy 的所有工作空间对话记录
   - 主数据源：sessions vscdb 数据库
   - 辅助：.codebuddy/memory/ 下的日期文件
2. 筛选当天有更新的会话
3. 读取有 brain/overview.md 的会话获取详细摘要
4. 提炼有价值的内容（代码修改、文档撰写、决策、部署等）
5. 生成日记条目追加到指定文件

## 日记格式

```markdown
## YYYY-MM-DD

### [工作空间名]
- 活动描述
- 关键产出
```

## 注意事项
- 只记录有实质产出的内容，不记录闲聊
- 保持简洁，每个工作空间最多 3-5 行
- 追加写入，不覆盖已有内容
