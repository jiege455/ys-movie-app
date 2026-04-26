# 宝塔面板部署配置

## 部署步骤

### 1. 构建项目
```bash
npm run build
```

### 2. 宝塔面板配置

#### 创建网站
1. 登录宝塔面板
2. 点击"网站" -> "添加站点"
3. 填写域名（如：movie.yourdomain.com）
4. 选择PHP版本（选择纯静态即可）
5. 网站目录指向项目根目录

#### Nginx配置
在宝塔面板中，进入网站设置 -> 配置文件，添加以下配置：

```nginx
server {
    listen 80;
    server_name movie.yourdomain.com;
    
    # 强制HTTPS（可选）
    # return 301 https://$server_name$request_uri;
    
    root /www/wwwroot/movie/dist;
    index index.html index.htm;
    
    # 前端路由支持
    location / {
        try_files $uri $uri/ /index.html;
    }
    
    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # API代理（如果需要）
    location /api/ {
        proxy_pass https://api.themoviedb.org/3/;
        proxy_set_header Host api.themoviedb.org;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 视频文件代理（如果需要）
    location /video/ {
        proxy_pass http://your-video-server.com/;
        proxy_set_header Host your-video-server.com;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

#### SSL证书配置（可选）
1. 在宝塔面板中申请Let's Encrypt免费证书
2. 开启强制HTTPS
3. 更新Nginx配置为HTTPS版本

### 3. 环境变量配置
在宝塔面板中，可以设置环境变量：

```bash
# 在网站设置 -> 配置文件 -> 添加
# 或者在项目根目录创建 .env.production 文件

VITE_API_KEY=your_real_api_key_here
VITE_API_BASE_URL=https://api.themoviedb.org/3
```

### 4. 构建优化

#### 修改package.json添加构建脚本
```json
{
  "scripts": {
    "build": "vite build",
    "build:prod": "vite build --mode production",
    "preview": "vite preview"
  }
}
```

#### 构建命令
```bash
# 开发环境构建
npm run build

# 生产环境构建
npm run build:prod
```

### 5. 部署验证

#### 检查项目结构
```
dist/
├── index.html
├── assets/
│   ├── index-xxx.js
│   ├── index-xxx.css
│   └── ...
└── ...
```

#### 访问测试
- 首页：http://movie.yourdomain.com
- 详情页：http://movie.yourdomain.com/movie/1
- 播放页：http://movie.yourdomain.com/player/1

### 6. 性能优化

#### CDN配置（可选）
```nginx
# 在Nginx配置中添加CDN支持
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header X-Cache-Status $upstream_cache_status;
}
```

#### Gzip压缩
```nginx
gzip on;
gzip_vary on;
gzip_min_length 1024;
gzip_proxied any;
gzip_comp_level 6;
gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/javascript
    application/xml+rss
    application/json;
```

### 7. 安全设置

#### 基本安全配置
```nginx
# 安全头
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# 隐藏Nginx版本
server_tokens off;
```

### 8. 监控和日志

#### 访问日志
宝塔面板默认会记录访问日志，可以在网站设置中查看

#### 错误日志
同样在网站设置中可以查看错误日志

### 9. 备份策略

#### 定期备份
1. 网站文件备份
2. 数据库备份（如果有）
3. 配置文件备份

### 10. 更新维护

#### 代码更新
```bash
# 拉取最新代码
git pull origin main

# 重新构建
npm install
npm run build:prod

# 重启Nginx
nginx -s reload
```

## 注意事项

1. **API Key安全**：确保在客户端代码中不要暴露真实的API key
2. **CORS配置**：如果跨域访问，需要正确配置CORS
3. **视频资源**：确保视频资源服务器支持跨域访问
4. **移动端适配**：已在代码中实现响应式设计
5. **SEO优化**：考虑添加meta标签和结构化数据

## 故障排查

### 常见问题

1. **页面空白**：检查浏览器控制台错误，通常是路径问题
2. **视频无法播放**：检查视频URL是否支持跨域，格式是否正确
3. **API调用失败**：检查网络连接和API key配置
4. **样式异常**：确认Tailwind CSS是否正确构建

### 调试方法

1. 使用浏览器开发者工具
2. 查看Nginx错误日志
3. 检查网络请求状态
4. 验证API响应数据