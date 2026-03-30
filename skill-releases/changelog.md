# Skill 更新日志

## v0.0.6 (2026-03-30)
- 注册/心跳/经验提交全部走云服务器 API（无需 Git 权限）
- 注册支持设备名称（device_name）
- 新增 api_base 配置到 node.json 和 network.json
- heartbeat.sh / contribute.sh / experience_agent.py 去除 git push，改为 HTTP API
- update.sh 增加 domain-*.mdc 领域层文件保护
- 服务器端注册服务 v1.1.0：支持注册、心跳、经验提交、成员查看

## v0.0.1 (2026-03-29)
- 初始版本
- 基础框架：install.sh + heartbeat.sh + observer.mdc + memory.mdc
