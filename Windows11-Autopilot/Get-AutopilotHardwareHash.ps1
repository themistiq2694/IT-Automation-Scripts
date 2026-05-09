# Get-AutopilotHardwareHash.ps1
# Description : Collects the hardware hash from a device and uploads it to
#               Microsoft Intune / Windows Autopilot via the Get-WindowsAutopilotInfo script.
#               This must run on the TARGET device BEFORE the OS wipe.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used during Windows 10 → Windows 11 migration (270+ devices, Entra-only)
# Usage       : Run as Administrator on target device.
#               .\Get-AutopilotHardwareHash.ps1 -TenantId "your-tenant-id"
# Requires    : Internet access, NuGet / PowerShellGet

param(
    [Parameter(Mandatory)]
    [string]$TenantId,

    [string]$OutputPath = "C:\Autopilot"
)

# -- Elevation check --
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must run as Administrator."
    exit 1
}

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

$hostname   = $env:COMPUTERNAME
$hashFile   = Join-Path $OutputPath "${hostname}_AutopilotHash.csv"
$logFile    = Join-Path $OutputPath "${hostname}_AutopilotLog.txt"

function Write-Log {
    param([string]$Msg, [string]$Level = "INFO")
    $entry = "$(Get-Date -f 'HH:mm:ss') [$Level] $Msg"
    Add-Content $logFile -Value $entry
    $color = switch ($Level) { "OK" { "Green" } "WARN" { "Yellow" } "ERROR" { "Red" } default { "Cyan" } }
    Write-Host $entry -ForegroundColor $color
}

Write-Log "=== Autopilot Hardware Hash Collection – $hostname ==="

# -- Install Get-WindowsAutopilotInfo if needed --
if (-not (Get-Module -ListAvailable -Name "Get-WindowsAutopilotInfo" -ErrorAction SilentlyContinue)) {
    Write-Log "Installing Get-WindowsAutopilotInfo module..."
    try {
        Install-Script -Name Get-WindowsAutopilotInfo -Force -Scope AllUsers -ErrorAction Stop
        Write-Log "Module installed." -Level "OK"
    } catch {
        Write-Log "Failed to install module: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

# -- Collect hardware hash locally --
Write-Log "Collecting hardware hash..."
try {
    Get-WindowsAutopilotInfo -OutputFile $hashFile -ErrorAction Stop
    Write-Log "Hash saved to: $hashFile" -Level "OK"
} catch {
    Write-Log "Hash collection failed: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# -- Upload to Intune (optional – requires MgGraph) --
Write-Log "Uploading hash to Autopilot (Intune)..."
try {
    Install-Module Microsoft.Graph.Intune -Force -Scope AllUsers -ErrorAction Stop
    Connect-MSGraph -ErrorAction Stop
    Get-WindowsAutopilotInfo -Online -TenantId $TenantId -OutputFile $hashFile -ErrorAction Stop
    Write-Log "Hash uploaded successfully to Intune." -Level "OK"
} catch {
    Write-Log "Online upload failed (manual import may be required): $($_.Exception.Message)" -Level "WARN"
    Write-Log "Hash file for manual import: $hashFile" -Level "WARN"
}

Write-Log "=== Done. Device: $hostname | File: $hashFile ==="
