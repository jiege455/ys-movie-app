# 开发者：杰哥网络科技 (qq: 2711793818)
# 功能：自动打包Flutter源码为zip文件，用于云端打包
# 说明：排除不需要的文件，减小源码包体积

Param(
    [string]$SourceDir = "E:\phpstudy_pro\WWW\ys\ys_movie_app",
    [string]$OutputFile = "E:\phpstudy_pro\WWW\ys\flutter_app_source.zip"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flutter源码打包工具" -ForegroundColor Cyan
Write-Host "  开发者：杰哥网络科技" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查源目录
if (!(Test-Path $SourceDir)) {
    Write-Error "错误：找不到源目录 $SourceDir"
    exit 1
}

Write-Host "[杰哥] 源目录: $SourceDir" -ForegroundColor Green
Write-Host "[杰哥] 输出文件: $OutputFile" -ForegroundColor Green
Write-Host ""

# 如果输出文件已存在，先删除
if (Test-Path $OutputFile) {
    Write-Host "[杰哥] 删除旧的源码包..." -ForegroundColor Yellow
    Remove-Item $OutputFile -Force
}

# 需要排除的文件和目录
$excludePatterns = @(
    "build",
    ".git",
    ".github",
    ".dart_tool",
    ".idea",
    ".vscode",
    "*.iml",
    "*.log",
    "*.tmp",
    "*.temp",
    "*.apk",
    "*.ipa",
    "*.aab",
    "android/build",
    "android/.gradle",
    "android/app/build",
    "ios/build",
    "ios/Pods",
    "ios/.symlinks",
    "ios/Flutter/Flutter.framework",
    "ios/Flutter/App.framework",
    "linux/build",
    "macos/build",
    "windows/build",
    "web/build",
    "test",
    "coverage",
    "node_modules",
    "*.lock",
    "pubspec.lock"
)

Write-Host "[杰哥] 开始打包..." -ForegroundColor Green
Write-Host "[杰哥] 排除以下文件/目录:" -ForegroundColor Gray
$excludePatterns | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
Write-Host ""

# 使用Compress-Archive打包
try {
    # 获取所有需要打包的文件
    $files = Get-ChildItem -Path $SourceDir -Recurse -File | Where-Object {
        $file = $_
        $relativePath = $file.FullName.Substring($SourceDir.Length + 1)
        
        # 检查是否在排除列表中
        $shouldExclude = $false
        foreach ($pattern in $excludePatterns) {
            if ($relativePath -like "*$pattern*") {
                $shouldExclude = $true
                break
            }
        }
        
        !$shouldExclude
    }
    
    Write-Host "[杰哥] 找到 $($files.Count) 个文件需要打包" -ForegroundColor Green
    Write-Host "[杰哥] 正在压缩..." -ForegroundColor Green
    
    # 创建临时目录用于打包
    $tempDir = Join-Path $env:TEMP "flutter_source_$(Get-Random)"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    
    # 复制文件到临时目录
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($SourceDir.Length + 1)
        $destPath = Join-Path $tempDir $relativePath
        $destDir = Split-Path $destPath -Parent
        
        if (!(Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        Copy-Item $file.FullName $destPath -Force
    }
    
    # 压缩临时目录
    Compress-Archive -Path "$tempDir\*" -DestinationPath $OutputFile -Force
    
    # 删除临时目录
    Remove-Item $tempDir -Recurse -Force
    
    # 显示结果
    $fileSize = (Get-Item $OutputFile).Length
    $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "[杰哥] ✅ 打包完成！" -ForegroundColor Green
    Write-Host "[杰哥] 文件路径: $OutputFile" -ForegroundColor Green
    Write-Host "[杰哥] 文件大小: $fileSizeMB MB" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "[杰哥] 下一步：" -ForegroundColor Cyan
    Write-Host "1. 确保文件已上传到服务器正确位置" -ForegroundColor White
    Write-Host "2. 访问云端打包页面测试" -ForegroundColor White
    
} catch {
    Write-Error "[杰哥] ❌ 打包失败: $_"
    exit 1
}
