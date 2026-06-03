Param(
  [string]$ApiBaseUrl = "http://localhost/api.php"
)

Write-Host "[杰哥] 开始安装/配置 Flutter 环境并创建原生影视App" -ForegroundColor Green

function Test-Flutter {
  try {
    flutter --version | Out-Null
    return $true
  } catch {
    return $false
  }
}

if (-not (Test-Flutter)) {
  Write-Host "[杰哥] 检测到本机未安装 Flutter，尝试使用 winget 安装..." -ForegroundColor Yellow
  try {
    winget install --id=Flutter.Flutter -e --source winget -h | Out-Null
  } catch {}
}

if (-not (Test-Flutter)) {
  Write-Host "[杰哥] winget 安装失败或不可用，请手动安装 Flutter 后再运行本脚本。" -ForegroundColor Red
  Write-Host "[杰哥] 手动安装指南： https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
  exit 1
}

Write-Host "[杰哥] Flutter 已可用" -ForegroundColor Green
flutter doctor
flutter config --enable-windows-desktop

$proj = Join-Path (Get-Location) "ys_movie_app"
if (-not (Test-Path $proj)) {
  Write-Host "[杰哥] 创建 Flutter 项目 ys_movie_app" -ForegroundColor Green
  flutter create ys_movie_app
}

# 覆盖模板代码
$template = Join-Path (Get-Location) "flutter_app_template"
if (-not (Test-Path $template)) {
  Write-Host "[杰哥] 未找到模板目录 flutter_app_template" -ForegroundColor Red
  exit 1
}

Copy-Item -Recurse -Force (Join-Path $template "lib") (Join-Path $proj "lib")
Copy-Item -Force (Join-Path $template "pubspec.yaml") (Join-Path $proj "pubspec.yaml")

Push-Location $proj
Write-Host "[杰哥] 安装依赖" -ForegroundColor Green
flutter pub get

Write-Host "[杰哥] 启动 Windows 桌面，后端地址：$ApiBaseUrl" -ForegroundColor Green
flutter run -d windows --dart-define API_BASE_URL=$ApiBaseUrl
Pop-Location

Write-Host "[杰哥] 完成" -ForegroundColor Green
