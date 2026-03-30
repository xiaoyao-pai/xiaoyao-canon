# Docker 部署实战经验

> 来源：逍遥派经验沉淀 | 脱敏版

## 部署方案选型

| 方案 | 适用 | 成本 |
|------|------|------|
| GitHub Pages | 纯静态页面 | 免费 |
| Vercel/Netlify | 前端 + Serverless | 免费/低 |
| 轻量云服务器 + Docker | 全栈项目 | ~50元/月 |

## Docker 部署标准流程

```
1. 项目分析（确认技术栈和依赖）
2. 编写 Dockerfile（多阶段构建减小镜像）
3. 构建镜像：docker compose build --no-cache
4. 端口分配（避开已有服务）
5. 启动容器：docker compose up -d
6. Nginx 反向代理配置
7. 验证全链路
```

## Nginx 反向代理模板

```nginx
location /项目路径/ {
    proxy_pass http://127.0.0.1:端口/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

## 踩坑记录

- **macOS 5000 端口被占**：AirPlay Receiver 默认占用，改用其他端口（如 5050）
- **Express trust proxy**：Nginx 反代后 express-rate-limit 报错，需 `app.set('trust proxy', 1)`
- **Docker 构建超时**：大项目用 `nohup docker compose build --no-cache &` 后台执行
- **端口配置不集中**：改端口时搜索所有文件（Flask/前端proxy/Docker/env），不要只改一处
- **Dockerfile 用 root 运行**：生产环境必须创建非 root 用户

## 多项目共存

- 每个项目分配独立端口段（3000-3099 Web应用）
- Nginx location 注意匹配顺序，避免冲突
- 新增规则前先检查与现有配置是否冲突
