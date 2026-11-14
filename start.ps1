# ==============================================================================
# Fast Production Runner (PowerShell / Windows) — MusicBotMobile
# ==============================================================================
# Deploys and launches the pre-compiled production APK onto the connected
# Android emulator/device in <2s, attaches a background logcat stream to
# .mobile.log, and records the PID in .pids for .\stop.ps1.
# ==============================================================================

param(
    [switch]$Background,
    [string]$DeviceId = "",
    [string]$Profile = "",
    [int]$MobilePort = 8090
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Default environment profile when neither -Profile nor .env is set (DEV | PROD)
$DEFAULT_PROFILE = "PROD"
$APP_ID = "com.musicbot.musicbot_mobile"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $root ".pids"
$stopScript = Join-Path $root "stop.ps1"
$buildScript = Join-Path $root "build.ps1"
$envFile = Join-Path $root ".env"

# Resolve PROFILE from CLI param -> .env -> $env:PROFILE -> $DEFAULT_PROFILE
$resolvedProfile = $Profile
if (-not $resolvedProfile -and (Test-Path $envFile)) {
    foreach ($line in (Get-Content $envFile)) {
        if ($line -match '^\s*PROFILE\s*=\s*([^\s#]+)') {
            $resolvedProfile = $Matches[1].Trim().ToUpper()
            break
        }
    }
}
if (-not $resolvedProfile -and $env:PROFILE) {
    $resolvedProfile = $env:PROFILE.Trim().ToUpper()
}
if (-not $resolvedProfile) {
    $resolvedProfile = $DEFAULT_PROFILE
}

$configFile = if ($resolvedProfile -eq "PROD" -or $resolvedProfile -eq "PRODUCTION") {
    "config/prod.json"
} else {
    "config/default.json"
}

$flutterBin = Join-Path $env:USERPROFILE "flutter\bin"
$androidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
$adbBin = Join-Path $androidSdk "platform-tools"
$adbExe = Join-Path $adbBin "adb.exe"
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_SDK_ROOT = $androidSdk
$env:Path = "$flutterBin;$adbBin;$env:Path"

# 1. Stop any previously running instance via stop.ps1
if (Test-Path $stopScript) {
    & $stopScript -Quiet
}

# 2. Auto-detect connected Android emulator/device via adb if -DeviceId is not specified
if (-not $DeviceId -and (Test-Path $adbExe)) {
    $adbLines = & $adbExe devices 2>$null
    foreach ($line in $adbLines) {
        if ($line -match '^([^\s]+)\s+device\b') {
            $DeviceId = $Matches[1].Trim()
            break
        }
    }
}

if (-not $DeviceId) {
    throw "No active Android emulator or device detected via adb. Please start your emulator first."
}

# 3. Determine device CPU ABI and locate matching pre-built release APK
$abiRaw = (& $adbExe -s $DeviceId shell getprop ro.product.cpu.abi 2>$null | Out-String).Trim()
$abi = if ($abiRaw) { $abiRaw } else { "x86_64" }
$apkDir = Join-Path $root "build\app\outputs\flutter-apk"
$apkPath = Join-Path $apkDir "app-$abi-release.apk"

if (-not (Test-Path $apkPath)) {
    $fallbackApk = Get-ChildItem -Path $apkDir -Filter "*-release.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($fallbackApk) {
        $apkPath = $fallbackApk.FullName
    } else {
        Write-Host "Release APK not found. Running .\build.ps1 -Profile $resolvedProfile first..." -ForegroundColor Yellow
        & $buildScript -Profile $resolvedProfile
        if ($LASTEXITCODE -ne 0) {
            throw "Build script failed. Cannot start MusicBotMobile."
        }
    }
}

Write-Host "Deploying MusicBotMobile ($resolvedProfile -> $configFile) to $DeviceId ($abi)..." -ForegroundColor Cyan
& $adbExe -s $DeviceId install -r $apkPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install $apkPath onto $DeviceId."
}

# 4. Clear stale logcat buffer and launch MainActivity on emulator/device
& $adbExe -s $DeviceId logcat -c 2>$null
Write-Host "Launching $APP_ID/.MainActivity on $DeviceId..." -ForegroundColor Green
& $adbExe -s $DeviceId shell am start -n "$APP_ID/.MainActivity" | Out-Null

# 5. Attach persistent background logcat listener streaming Flutter & FSM logs to .mobile.log
$logOut = Join-Path $root ".mobile.log"
$logErr = Join-Path $root ".mobile.err.log"

$proc = Start-Process `
    -FilePath $adbExe `
    -ArgumentList "-s $DeviceId logcat -v time flutter:V *:E" `
    -WorkingDirectory $root `
    -RedirectStandardOutput $logOut `
    -RedirectStandardError $logErr `
    -WindowStyle Hidden `
    -PassThru

$payload = [ordered]@{
    mobile_pid   = $proc.Id
    device_id    = $DeviceId
    app_id       = $APP_ID
    profile      = $resolvedProfile
    mobile_port  = $MobilePort
    log_file     = $logOut
    started_at   = (Get-Date).ToString("o")
    workspace    = $root
}
$payload | ConvertTo-Json | Set-Content -Path $pidFile -Encoding UTF8
Write-Host "  [OK] MusicBotMobile is now running on $DeviceId!" -ForegroundColor Green
Write-Host "  [PID State] Stored PID in $pidFile (Log Stream PID: $($proc.Id))" -ForegroundColor DarkGray
Write-Host "  [Live Logs] Get-Content .mobile.log -Wait" -ForegroundColor Cyan
Write-Host "  Run .\stop.ps1 to stop the app and log stream." -ForegroundColor Yellow
