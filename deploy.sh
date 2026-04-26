#!/bin/bash

# 宝塔面板部署脚本
# 用于自动化部署影视App到宝塔面板

echo "🎬 开始部署影视App..."

# 1. 构建项目
echo "📦 正在构建项目..."
npm run build

if [ $? -ne 0 ]; then
    echo "❌ 项目构建失败，请检查错误信息"
    exit 1
fi

echo "✅ 项目构建成功"

# 2. 创建部署目录（假设宝塔网站目录为 /www/wwwroot/movie）
DEPLOY_DIR="/www/wwwroot/movie"
DIST_DIR="dist"

echo "📁 准备部署文件..."

# 检查dist目录是否存在
if [ ! -d "$DIST_DIR" ]; then
    echo "❌ dist目录不存在，请先运行npm run build"
    exit 1
fi

# 3. 备份现有文件（如果存在）
if [ -d "$DEPLOY_DIR" ]; then
    echo "💾 备份现有文件..."
    BACKUP_DIR="${DEPLOY_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    cp -r "$DEPLOY_DIR" "$BACKUP_DIR"
    echo "✅ 备份完成：$BACKUP_DIR"
fi

# 4. 复制文件到部署目录
echo "📤 复制文件到部署目录..."
mkdir -p "$DEPLOY_DIR"
cp -r "$DIST_DIR"/* "$DEPLOY_DIR/"

# 5. 设置权限
echo "🔒 设置文件权限..."
chown -R www:www "$DEPLOY_DIR"
chmod -R 755 "$DEPLOY_DIR"

# 6. 重启Nginx服务
echo "🔄 重启Nginx服务..."
service nginx reload

if [ $? -eq 0 ]; then
    echo "✅ Nginx重启成功"
else
    echo "⚠️  Nginx重启失败，请手动检查"
fi

# 7. 部署完成
echo ""
echo "🎉 部署完成！"
echo "📱 请访问你的网站查看效果"
echo "🔧 如果出现问题，请查看宝塔面板日志"
echo ""
echo "📋 部署信息："
echo "   部署目录：$DEPLOY_DIR"
echo "   备份目录：${BACKUP_DIR:-无}"
echo "   部署时间：$(date)"
echo ""

# 8. 可选：显示Nginx配置建议
echo "💡 Nginx配置建议："
echo "   1. 登录宝塔面板"
echo "   2. 进入网站设置"
echo "   3. 点击'配置文件'"
echo "   4. 参考 nginx_baota.conf 文件进行配置"
echo ""

exit 0