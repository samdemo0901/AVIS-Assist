# =====================================================================
# AVIS Mobile APK Compilation Script
# Packages Android build output cleanly into build/mobile/
# Prevents any disruption to existing desktop Windows build pipelines
# =====================================================================

param (
    [switch]$Release = $true,
    [string]$OutputDir = "..\build\mobile"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   AVIS Next-Gen Mobile: Android APK Compilation Pipeline  " -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan

# 0. Configure Environment
if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    if (Test-Path "C:\Android\jdk-17") {
        $env:JAVA_HOME = "C:\Android\jdk-17"
        $env:PATH = "C:\Android\jdk-17\bin;" + $env:PATH
    }
}
if (-not $env:ANDROID_HOME) {
    if (Test-Path "$env:LOCALAPPDATA\Android\Sdk") {
        $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
        $env:ANDROID_SDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk"
    } elseif (Test-Path "C:\Android\Sdk") {
        $env:ANDROID_HOME = "C:\Android\Sdk"
        $env:ANDROID_SDK_ROOT = "C:\Android\Sdk"
    }
}

# 1. Verify Flutter SDK
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Write-Warning "[!] Flutter SDK was not detected in PATH."
    Write-Host "Please ensure Flutter 3.x+ is installed and configured in your environment PATH." -ForegroundColor Yellow
    exit 1
}

# 2. Prepare Output Directory
$targetAbsPath = [System.IO.Path]::GetFullPath((Join-Path $scriptPath $OutputDir))
if (-not (Test-Path $targetAbsPath)) {
    New-Item -ItemType Directory -Path $targetAbsPath -Force | Out-Null
}

# 3. Retrieve Dependencies
Write-Host "`n[*] Resolving pub.dev dependencies..." -ForegroundColor Cyan
flutter pub get

# 4. Compile APK
$buildMode = if ($Release) { "release" } else { "debug" }
Write-Host "[*] Compiling Android APK in $buildMode mode..." -ForegroundColor Cyan
flutter build apk --$buildMode

# 5. Output Management: Route artifact directly into build/mobile/
$builtApk = "build\app\outputs\flutter-apk\app-$buildMode.apk"
$destinationApk = Join-Path $targetAbsPath "avis-mobile-$buildMode.apk"

if (Test-Path $builtApk) {
    Copy-Item -Path $builtApk -Destination $destinationApk -Force
    Write-Host "`n[+] SUCCESS: Mobile APK compiled and routed to isolated location:" -ForegroundColor Green
    Write-Host "    $destinationApk" -ForegroundColor White
} else {
    Write-Error "[-] Build finished but output APK not found at: $builtApk"
}
