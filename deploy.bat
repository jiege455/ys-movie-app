@echo off
echo 🎬 开始部署影视App...

REM 1. 构建项目
echo 📦 正在构建项目...
call npm run build

if %errorlevel% neq 0 (
    echo ❌ 项目构建失败，请检查错误信息
    pause
    exit /b 1
)

echo ✅ 项目构建成功

REM 2. 设置部署目录（请根据实际情况修改）
set "DEPLOY_DIR=C:\wwwroot\movie"
set "DIST_DIR=dist"

echo 📁 准备部署文件...

REM 检查dist目录是否存在
if not exist "%DIST_DIR%" (
    echo ❌ dist目录不存在，请先运行npm run build
    pause
    exit /b 1
)

REM 3. 备份现有文件（如果存在）
if exist "%DEPLOY_DIR%" (
    echo 💾 备份现有文件...
    set "BACKUP_DIR=%DEPLOY_DIR%_backup_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
    set "BACKUP_DIR=%BACKUP_DIR: =0%"
    xcopy /E /I /Y "%DEPLOY_DIR%" "%BACKUP_DIR%"
    echo ✅ 备份完成：%BACKUP_DIR%
)

REM 4. 创建部署目录
echo 📤 复制文件到部署目录...
if not exist "%DEPLOY_DIR%" (
    mkdir "%DEPLOY_DIR%"
)

REM 5. 复制文件
xcopy /E /Y "%DIST_DIR%\*" "%DEPLOY_DIR%\"

REM 6. 部署完成
echo.
echo 🎉 部署完成！
echo 📱 请访问你的网站查看效果
echo 🔧 如果出现问题，请检查宝塔面板日志
echo.
echo 📋 部署信息：
echo    部署目录：%DEPLOY_DIR%
echo    部署时间：%date% %time%
echo.

REM 7. 显示下一步操作提示
echo 💡 下一步操作：
echo    1. 登录宝塔面板
echo    2. 创建新网站或修改现有网站
echo    3. 将网站根目录设置为：%DEPLOY_DIR%
echo    4. 参考 nginx_baota.conf 文件配置Nginx
echo.

pause