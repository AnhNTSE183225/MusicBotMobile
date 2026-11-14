# ==============================================================================
# Fast Production Runner (PowerShell / Windows) — MusicBotMobile
# ==============================================================================
# Runs ONLY pre-compiled/verified production artifacts and persists active
# process IDs in .pids so .\stop.ps1 can terminate them deterministically.
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
$env:Path = "$flutterBin;$adbBin;$env:Path"

# 1. Stop any previously running instance via stop.ps1
if (Test-Path $stopScript) {
    & $stopScript -Quiet
}

# 2. Ensure generated artifacts exist (auto-build only if missing)
$genDb = Join-Path $root "lib\core\database\app_database.g.dart"
if (-not (Test-Path $genDb)) {
    Write-Host "Generated artifacts missing. Running .\build.ps1 -SkipApk first..." -ForegroundColor Yellow
    & $buildScript -SkipApk
    if ($LASTEXITCODE -ne 0) {
        throw "Build script failed. Cannot start MusicBotMobile."
    }
}

Write-Host "Starting MusicBotMobile in 100% Optimized Release Mode (Profile: $resolvedProfile -> $configFile)..." -ForegroundColor Green

$flutterCmd = (Get-Command flutter.bat -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $flutterCmd) {
    $flutterCmd = Join-Path $flutterBin "flutter.bat"
}

$deviceArgs = if ($DeviceId) { "-d $DeviceId" } else { "" }
$runArgs = "run --release --dart-define-from-file=$configFile $deviceArgs"

$logOut = Join-Path $root ".mobile.log"
$logErr = Join-Path $root ".mobile.err.log"

$proc = Start-Process `
    -FilePath $flutterCmd `
    -ArgumentList $runArgs `
    -WorkingDirectory $root `
    -RedirectStandardOutput $logOut `
    -RedirectStandardError $logErr `
    -WindowStyle Hidden `
    -PassThru

$payload = [ordered]@{
    mobile_pid   = $proc.Id
    mobile_port  = $MobilePort
    log_file     = $logOut
    started_at   = (Get-Date).ToString("o")
    workspace    = $root
}
$payload | ConvertTo-Json | Set-Content -Path $pidFile -Encoding UTF8
Write-Host "  [PID State] Stored PID in $pidFile (Mobile Runner PID: $($proc.Id))" -ForegroundColor DarkGray
Write-Host "  [Live Logs] Get-Content .mobile.log -Wait" -ForegroundColor Cyan
Write-Host "  Run .\stop.ps1 to stop the runner process tree." -ForegroundColor Yellow
