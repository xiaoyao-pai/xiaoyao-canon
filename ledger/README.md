# 贡献账本

> Git SHA hash 链 + Branch Protection 保证不可篡改

## 规则
- 每条贡献记录是一次 commit
- SHA hash 链式连接，篡改任何历史导致 hash 链断裂
- 只有掌门/Bot 有写入权限

## 结构
- `members/XYP-xxxx.json` — 成员贡献档案
- `records/YYYY-MM-DD.jsonl` — 每日贡献明细
- `scores/weekly-YYYY-wNN.json` — 周评分快照
