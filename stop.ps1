# ==============================================================================
# Deterministic PID Stop Script (PowerShell / Windows) — MusicBotMobile
# ==============================================================================
# Stops running application/mobile runner processes deterministically using the
# stored .pids file written by .\start.ps1, with fallback port & process-tree
# cleanup.
#
# Usage:
#   .\stop.ps1          # Stop services by stored PID and clean up .pids
#   .\stop.ps1 -Quiet   # Suppress non-essential output (used by build/start)
# ==============================================================================

param(
    [switch]$Quiet,
    [int[]]$FallbackPorts = @(8090)
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $root ".pids"

function Write-StopLog {
    param([string]$Message, [string]$Color = "Yellow")
    if (-not $Quiet) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Stop-PidTree {
    param(
        [int]$TargetPid,
        [string]$Label
    )
    if (-not $TargetPid -or $TargetPid -le 4) { return $false }

    $proc = Get-Process -Id $TargetPid -ErrorAction SilentlyContinue
    if ($null -eq $proc) {
        Write-StopLog "  [$Label] PID $TargetPid is already stopped." "DarkGray"
        return $false
    }

    Write-StopLog "  [$Label] Stopping process tree for PID $TargetPid ($($proc.ProcessName))..." "Yellow"
    try {
        & taskkill.exe /PID $TargetPid /T /F 2>$null | Out-Null
        Stop-Process -Id $TargetPid -Force -ErrorAction SilentlyContinue
    } catch {}

    Start-Sleep -Milliseconds 200
    return $true
}

$stoppedAny = $false

# 1. Primary: Stop by stored PIDs in .pids file
if (Test-Path $pidFile) {
    Write-StopLog "Reading stored PIDs from $pidFile..." "Cyan"
    try {
        $pidData = Get-Content -Path $pidFile -Raw | ConvertFrom-Json

        foreach ($prop in @("mobile_pid", "frontend_pid", "backend_pid")) {
            if ($pidData.$prop) {
                if (Stop-PidTree -TargetPid ([int]$pidData.$prop) -Label $prop) {
                    $stoppedAny = $true
                }
            }
        }
        if ($pidData.device_id -and $pidData.app_id) {
            $adbExe = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
            if (Test-Path $adbExe) {
                Write-StopLog "  [Device] Stopping $($pidData.app_id) on $($pidData.device_id)..." "Yellow"
                & $adbExe -s $pidData.device_id shell am force-stop $pidData.app_id 2>$null
                $stoppedAny = $true
            }
        }
        if ($pidData.mobile_port -and ($FallbackPorts -notcontains [int]$pidData.mobile_port)) {
            $FallbackPorts += [int]$pidData.mobile_port
        }
    } catch {
        Write-StopLog "  Warning: Could not parse .pids file; falling back to port sweep." "Red"
    }

    Remove-Item -Path $pidFile -Force -ErrorAction SilentlyContinue
    Write-StopLog "  Removed PID state file ($pidFile)." "DarkGray"
} else {
    Write-StopLog "No .pids file found at $pidFile. Checking for orphaned port listeners..." "DarkGray"
}

# 2. Secondary Safety Sweep: Ensure no orphaned child processes hold project ports
foreach ($port in $FallbackPorts) {
    $listeners = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($owningPid in $listeners) {
        if ($owningPid -and $owningPid -gt 4) {
            if (Stop-PidTree -TargetPid $owningPid -Label "Orphaned Port $port") {
                $stoppedAny = $true
            }
        }
    }
}

if ($stoppedAny) {
    Start-Sleep -Milliseconds 300
    Write-StopLog "[✔] All MusicBotMobile services stopped cleanly." "Green"
} else {
    Write-StopLog "[✔] No active MusicBotMobile services were running." "Green"
}
