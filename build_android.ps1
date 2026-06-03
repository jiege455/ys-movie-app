Param(
  [string]$ApiBaseUrl = "https://ys.ddgg888.my/api.php",
  [switch]$Release
)

Write-Host "[杰哥] 开始打包 Android APK" -ForegroundColor Green

$flutterBat = "E:\phpstudy_pro\WWW\ys\flutter\bin\flutter.bat"
$projRoot = "E:\phpstudy_pro\WWW\ys\ys_movie_app"
# 使用本地 E:\java17 JDK 作为构建 JDK，避免 Android Studio JBR 问题
$javaHome = "E:\java17\jdk-17.0.17+10"

if (!(Test-Path $flutterBat)) { Write-Error "未找到 flutter.bat: $flutterBat"; exit 1 }
if (!(Test-Path $projRoot)) { Write-Error "未找到项目目录: $projRoot"; exit 1 }
if (!(Test-Path "$javaHome\bin\java.exe")) { Write-Error "未找到 JDK: $javaHome"; exit 1 }

$env:JAVA_HOME = $javaHome
$env:Path = "$($javaHome)\bin;" + $env:Path

Write-Host "[杰哥] JAVA_HOME = $env:JAVA_HOME" -ForegroundColor Cyan

Push-Location $projRoot

# 尝试构建 Debug/Release
if ($Release) {
  & $flutterBat build apk --release --dart-define API_BASE_URL=$ApiBaseUrl
} else {
  & $flutterBat build apk --debug --dart-define API_BASE_URL=$ApiBaseUrl
}

if ($LASTEXITCODE -ne 0) {
  Write-Warning "Flutter 构建失败，尝试使用 Gradle 直接构建 assembleDebug 查看详细错误..."
  Push-Location "$projRoot\android"
  & "$projRoot\android\gradlew.bat" assembleDebug --stacktrace
  Pop-Location
}

Pop-Location

$apkDebug = "$projRoot\build\app\outputs\flutter-apk\app-debug.apk"
$apkRelease = "$projRoot\build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkRelease) { Write-Host "[杰哥] Release 包: $apkRelease" -ForegroundColor Green }
if (Test-Path $apkDebug) { Write-Host "[杰哥] Debug 包:   $apkDebug" -ForegroundColor Green }

Write-Host "[杰哥] 完成，如失败请先在 Android Studio 安装 SDK 并执行 flutter doctor --android-licenses" -ForegroundColor Green
