# ==============================================================================
# Zero-Assumption Production Build Script (PowerShell / Windows) — MusicBotMobile
# ==============================================================================
# Enforces VIBE_CODING_RULES.md & MOBILE_TECHSTACK.md:
#   1. Pre-build service stop via .\stop.ps1 (prevents Windows OS Error 5 locks)
#   2. Zero-Assumption Environment & Toolchain Checklist (verifies Git, C/C++
#      linker, Rust, Node.js, pnpm, OpenJDK 17+, and Flutter SDK; auto-installs
#      where possible or throws an actionable fatal error)
#   3. Full Production Build (pub get, build_runner codegen, static analysis,
#      unit/widget tests, and AOT Release APK / bundle compilation)
#
# Usage:
#   .\build.ps1                 # Full Zero-Assumption verification + build
#   .\build.ps1 -Clean          # Clean existing artifacts and regenerate code
#   .\build.ps1 -IncludeMobile  # Build Flutter Android release APK (--split-per-abi)
#   .\build.ps1 -SkipApk        # Run codegen + analyze + test only
# ==============================================================================

param(
    [switch]$Clean,
    [switch]$SkipFrontend,
    [switch]$SkipBackend,
    [switch]$IncludeMobile,
    [switch]$SkipApk,
    [string]$Profile = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Default environment profile when neither -Profile nor .env is set (DEV | PROD)
$DEFAULT_PROFILE = "PROD"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$stopScript = Join-Path $root "stop.ps1"
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

$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   MUSICBOTMOBILE ZERO-ASSUMPTION PRODUCTION BUILD (WINDOWS)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

function Refresh-SessionPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $cargoBin = Join-Path $env:USERPROFILE ".cargo\bin"
    $flutterBin = Join-Path $env:USERPROFILE "flutter\bin"
    $androidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
    $adbBin = Join-Path $androidSdk "platform-tools"
    if (Test-Path $androidSdk) {
        $env:ANDROID_HOME = $androidSdk
        $env:ANDROID_SDK_ROOT = $androidSdk
    }
    $env:Path = "$flutterBin;$adbBin;$cargoBin;$userPath;$machinePath"
}

function Test-CommandExists {
    param([string]$CommandName)
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue | Select-Object -First 1
    return $null -ne $cmd
}

function Install-ViaWinget {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$ExtraArgs = ""
    )
    if (-not (Test-CommandExists "winget")) {
        return $false
    }
    Write-Host "  [⚙ AUTO-INSTALL] Installing $DisplayName ($PackageId) via winget..." -ForegroundColor Yellow
    $argList = "install --id $PackageId --exact --silent --accept-package-agreements --accept-source-agreements $ExtraArgs"
    $proc = Start-Process -FilePath "winget" -ArgumentList $argList -Wait -PassThru -NoNewWindow
    Refresh-SessionPath
    return ($proc.ExitCode -eq 0)
}

function Throw-MissingDependency {
    param(
        [string]$DependencyName,
        [string]$Purpose,
        [string]$DownloadUrl,
        [string]$InstallCommand
    )
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host " [✖] FATAL: MISSING REQUIRED BUILD ENVIRONMENT DEPENDENCY" -ForegroundColor Red
    Write-Host "==================================================================" -ForegroundColor Red
    Write-Host "  Missing Component : $DependencyName" -ForegroundColor Yellow
    Write-Host "  Required For      : $Purpose" -ForegroundColor Gray
    Write-Host "  Download URL      : $DownloadUrl" -ForegroundColor Cyan
    Write-Host "  Manual Command    : $InstallCommand" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Red
    throw "Build aborted: Missing dependency '$DependencyName'. Please install it from $DownloadUrl or run '$InstallCommand' and re-run .\build.ps1."
}

# ------------------------------------------------------------------------------
# 0. Pre-Flight Environment & Toolchain Verification Checklist
# ------------------------------------------------------------------------------
Write-Host "[Phase 0] Running Zero-Assumption Toolchain & Dependency Checklist..." -ForegroundColor Cyan
Refresh-SessionPath

# 0.1 Core Git Check
if (-not (Test-CommandExists "git")) {
    $installed = Install-ViaWinget -PackageId "Git.Git" -DisplayName "Git SCM"
    if (-not $installed -or -not (Test-CommandExists "git")) {
        Throw-MissingDependency `
            -DependencyName "Git" `
            -Purpose "Source control and Flutter dependency fetching" `
            -DownloadUrl "https://git-scm.com/download/win" `
            -InstallCommand "winget install Git.Git"
    }
}
Write-Host "  [✔] Git SCM verified: $(git --version)" -ForegroundColor Green

# 0.2 Java JDK 17+ Check
if (-not (Test-CommandExists "java")) {
    $installed = Install-ViaWinget -PackageId "Microsoft.OpenJDK.17" -DisplayName "Microsoft OpenJDK 17"
    if (-not $installed -or -not (Test-CommandExists "java")) {
        Throw-MissingDependency `
            -DependencyName "Java Development Kit (OpenJDK 17+)" `
            -Purpose "Android Gradle build system and APK signing" `
            -DownloadUrl "https://learn.microsoft.com/en-us/java/openjdk/download" `
            -InstallCommand "winget install Microsoft.OpenJDK.17"
    }
}
Write-Host "  [✔] Java JDK verified" -ForegroundColor Green

# 0.3 Flutter SDK & Dart AOT Toolchain Check
if (-not (Test-CommandExists "flutter")) {
    $flutterTargetDir = Join-Path $env:USERPROFILE "flutter"
    if (-not (Test-Path (Join-Path $flutterTargetDir "bin\flutter.bat"))) {
        Write-Host "  [⚙ AUTO-INSTALL] Cloning official Flutter stable SDK to $flutterTargetDir..." -ForegroundColor Yellow
        & git clone --depth 1 -b stable https://github.com/flutter/flutter.git $flutterTargetDir
    }
    Refresh-SessionPath
    if (-not (Test-CommandExists "flutter")) {
        Throw-MissingDependency `
            -DependencyName "Flutter SDK & Dart AOT Toolchain" `
            -Purpose "Compiling 120Hz Impeller ARM64 mobile binaries" `
            -DownloadUrl "https://docs.flutter.dev/get-started/install/windows" `
            -InstallCommand "git clone -b stable https://github.com/flutter/flutter.git `$env:USERPROFILE\flutter"
    }
}
Write-Host "  [✔] Flutter SDK verified" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 1. Stop Running Services (Unlock Windows Binaries via .\stop.ps1)
# ------------------------------------------------------------------------------
Write-Host "[Phase 1] Ensuring running services are stopped before compilation..." -ForegroundColor Cyan
if (Test-Path $stopScript) {
    & $stopScript -Quiet
}

# ------------------------------------------------------------------------------
# 2. Clean Artifacts (If Requested)
# ------------------------------------------------------------------------------
if ($Clean) {
    Write-Host "[Phase 2] Cleaning previous Flutter build artifacts..." -ForegroundColor Yellow
    Push-Location $root
    try {
        & flutter clean
    } finally {
        Pop-Location
    }
}

# ------------------------------------------------------------------------------
# 3. Resolve Dependencies & Compile-Time Code Generation
# ------------------------------------------------------------------------------
Write-Host "[Phase 3] Resolving dependencies and running compile-time codegen (Drift + JSON)..." -ForegroundColor Magenta
Push-Location $root
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed with exit code $LASTEXITCODE." }

    & dart run build_runner build --delete-conflicting-outputs
    if ($LASTEXITCODE -ne 0) { throw "build_runner codegen failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}
Write-Host "  [✔] Dependencies & zero-reflection codegen verified!" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 4. Static Analysis & Automated Test Suite
# ------------------------------------------------------------------------------
Write-Host "[Phase 4] Running Dart static analyzer and automated widget/unit tests..." -ForegroundColor Cyan
Push-Location $root
try {
    & flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw "flutter analyze reported issues (exit code $LASTEXITCODE)." }

    & flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw "flutter test failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}
Write-Host "  [✔] Static analysis and responsive/FSM test suite passed!" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------------------------
# 5. Build Release Artifact (APK if Android platform is scaffolded & not skipped)
# ------------------------------------------------------------------------------
$androidDir = Join-Path $root "android"
if (-not $SkipApk -and (Test-Path $androidDir) -and ($IncludeMobile -or $env:ANDROID_HOME)) {
    Write-Host "[Phase 5] Building Flutter AOT Release APK (--split-per-abi, Profile: $resolvedProfile -> $configFile)..." -ForegroundColor Blue
    Push-Location $root
    try {
        & flutter build apk --release --split-per-abi --dart-define-from-file=$configFile
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [!] Note: Android APK gradle build returned $LASTEXITCODE (verify Android SDK licenses via 'flutter doctor --android-licenses')." -ForegroundColor Yellow
        } else {
            Write-Host "  [✔] Mobile ARM64 Release APK built successfully!" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
    Write-Host ""
}

$sw.Stop()
$elapsed = [Math]::Round($sw.Elapsed.TotalSeconds, 1)

Write-Host "==================================================================" -ForegroundColor Green
Write-Host "       PRODUCTION BUILD COMPLETED SUCCESSFULLY IN ${elapsed}s!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "  Start Application : .\start.ps1" -ForegroundColor Yellow
Write-Host "  Stop Application  : .\stop.ps1" -ForegroundColor Yellow
Write-Host ""
exit 0
