#Requires -Version 5.1
<#
.SYNOPSIS
    狐狸影视 Flutter APK 构建脚本
    开发者：杰哥网络科技 (qq: 2711793818)
.DESCRIPTION
    自动检查环境并构建 Flutter APK
    支持 Debug 和 Release 模式
.PARAMETER ApiBaseUrl
    API 基础地址，默认使用你的域名
.PARAMETER Release
    是否构建 Release 版本（默认 Debug）
.PARAMETER Install
    构建完成后是否自动安装到连接的设备
.EXAMPLE
    .\build_apk.ps1
    .\build_apk.ps1 -Release
    .\build_apk.ps1 -ApiBaseUrl "https://your-domain.com/api.php" -Release -Install
#>

Param(
    [string]$ApiBaseUrl = "https://ys.ddgg888.my/api.php",
    [switch]$Release,
    [switch]$Install
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-Info { param([string]$msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param([string]$msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warning { param([string]$msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Error { param([string]$msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Host "========================================" -ForegroundColor Green
Write-Host "  狐狸影视 APK 构建工具" -ForegroundColor Green
Write-Host "  开发者：杰哥网络科技" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 路径配置
$flutterBat = "E:\phpstudy_pro\WWW\ys\flutter\bin\flutter.bat"
$projRoot = "E:\phpstudy_pro\WWW\ys\ys_movie_app"
$javaHome = "E:\java17\jdk-17.0.17+10"

# ==================== 环境检查 ====================
Write-Info "检查构建环境..."

# 检查 Flutter
if (!(Test-Path $flutterBat)) {
    Write-Error "未找到 Flutter: $flutterBat"
    Write-Info "请确认 flutter 文件夹存在于项目目录中"
    exit 1
}
Write-Success "Flutter 路径: $flutterBat"

# 检查项目目录
if (!(Test-Path $projRoot)) {
    Write-Error "未找到项目目录: $projRoot"
    exit 1
}
Write-Success "项目目录: $projRoot"

# 检查 JDK
if (!(Test-Path "$javaHome\bin\java.exe")) {
    Write-Warning "未找到 JDK: $javaHome"
    Write-Info "尝试查找其他 JDK..."

    $possibleJdks = @(
        "E:\java17\jdk-17.0.17+10",
        "E:\jdk17\jdk-17.0.17+10",
        "C:\Program Files\Java\jdk-17",
        "C:\Program Files\Eclipse Adoptium\jdk-17*"
    )

    $foundJdk = $null
    foreach ($jdk in $possibleJdks) {
        $matches = Get-Item $jdk -ErrorAction SilentlyContinue
        if ($matches) {
            $foundJdk = $matches.FullName
            break
        }
    }

    if ($foundJdk) {
        $javaHome = $foundJdk
        Write-Success "找到 JDK: $javaHome"
    } else {
        Write-Error "未找到 JDK 17，请安装 JDK 17 或修改脚本中的 `$javaHome 路径"
        exit 1
    }
} else {
    Write-Success "JDK 路径: $javaHome"
}

# 设置环境变量
$env:JAVA_HOME = $javaHome
$env:Path = "$($javaHome)\bin;" + $env:Path

# 检查 Android SDK
$androidHome = $env:ANDROID_HOME
if ([string]::IsNullOrEmpty($androidHome)) {
    $androidHome = $env:ANDROID_SDK_ROOT
}

if ([string]::IsNullOrEmpty($androidHome) -or !(Test-Path "$androidHome\cmdline-tools")) {
    Write-Warning "未找到 Android SDK 或 cmdline-tools"
    Write-Info "正在尝试查找 Android SDK..."

    $possibleSdkPaths = @(
        "$env:LOCALAPPDATA\Android\Sdk",
        "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk",
        "C:\Android\Sdk",
        "D:\Android\Sdk",
        "E:\Android\Sdk"
    )

    $foundSdk = $null
    foreach ($sdkPath in $possibleSdkPaths) {
        if (Test-Path $sdkPath) {
            $foundSdk = $sdkPath
            break
        }
    }

    if ($foundSdk) {
        $env:ANDROID_HOME = $foundSdk
        $env:ANDROID_SDK_ROOT = $foundSdk
        Write-Success "找到 Android SDK: $foundSdk"
    } else {
        Write-Error @"
未找到 Android SDK！请按以下步骤安装：

方法 1：安装 Android Studio（推荐）
1. 下载 Android Studio：https://developer.android.com/studio
2. 安装时勾选 "Android SDK"、"Android SDK Command-line Tools"、"Android SDK Build-Tools"
3. 安装完成后重新运行此脚本

方法 2：仅安装命令行工具
1. 下载：https://developer.android.com/studio#command-line-tools-only
2. 解压到 C:\Android\Sdk\cmdline-tools\latest\
3. 运行：sdkmanager "platforms;android-34" "build-tools;34.0.0"
4. 设置环境变量 ANDROID_HOME = C:\Android\Sdk
"@
        exit 1
    }
} else {
    Write-Success "Android SDK: $androidHome"
}

# 检查 Flutter 环境
Write-Info "检查 Flutter 环境..."
Push-Location $projRoot
$flutterDoctor = & $flutterBat doctor --android-licenses 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Flutter 环境检查发现问题，尝试继续构建..."
}
Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  开始构建 APK" -ForegroundColor Green
Write-Host "  模式: $(if ($Release) { 'Release' } else { 'Debug' })" -ForegroundColor Green
Write-Host "  API地址: $ApiBaseUrl" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# ==================== 构建 APK ====================
Push-Location $projRoot

try {
    # 清理旧构建
    Write-Info "清理旧构建文件..."
    & $flutterBat clean
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "清理命令返回非零退出码，继续构建..."
    }

    # 获取依赖
    Write-Info "获取 Flutter 依赖..."
    & $flutterBat pub get
    if ($LASTEXITCODE -ne 0) {
        Write-Error "获取依赖失败"
        exit 1
    }
    Write-Success "依赖获取完成"

    # 构建 APK
    Write-Info "开始构建 APK..."
    $buildMode = if ($Release) { "--release" } else { "--debug" }

    & $flutterBat build apk $buildMode --dart-define=API_BASE_URL=$ApiBaseUrl

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Flutter 构建失败"
        Write-Info "尝试使用 Gradle 直接构建查看详细错误..."

        Push-Location "$projRoot\android"
        & .\gradlew.bat assembleDebug --stacktrace
        Pop-Location

        exit 1
    }

    Write-Success "APK 构建成功！"

    # 查找生成的 APK
    $apkDir = "$projRoot\build\app\outputs\flutter-apk"
    $apkFile = if ($Release) {
        Get-ChildItem -Path $apkDir -Filter "app-release.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
    } else {
        Get-ChildItem -Path $apkDir -Filter "app-debug.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if ($apkFile) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Success "APK 文件: $($apkFile.FullName)"
        Write-Success "文件大小: $([math]::Round($apkFile.Length / 1MB, 2)) MB"
        Write-Host "========================================" -ForegroundColor Green

        # 安装到设备
        if ($Install) {
            Write-Info "正在安装到设备..."
            & $flutterBat install
            if ($LASTEXITCODE -eq 0) {
                Write-Success "安装成功！"
            } else {
                Write-Warning "安装失败，请手动安装 APK"
            }
        }
    } else {
        Write-Warning "未找到生成的 APK 文件，请检查 $apkDir 目录"
    }

} finally {
    Pop-Location
}

Write-Host ""
Write-Host "构建完成！" -ForegroundColor Green
