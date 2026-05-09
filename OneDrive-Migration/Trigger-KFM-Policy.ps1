# Trigger-KFM-Policy.ps1
# Description : Configures Known Folder Move (KFM) registry settings on a local machine
#               to redirect Desktop, Documents, and Pictures to OneDrive for Business.
#               Can be deployed via Intune as a remediation script or run locally.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used during OneDrive migration rollout (~200 users)
# Usage       : .\Trigger-KFM-Policy.ps1 -TenantId "your-tenant-id"

param(
    [Parameter(Mandatory)]
    [string]$TenantId
)

$registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive"
$logFile      = "C:\Windows\Logs\OneDrive_KFM_$(Get-Date -f 'yyyyMMdd').log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $entry = "$(Get-Date -f 'yyyy-MM-dd HH:mm:ss') [$Level] $Message"
    Add-Content -Path $logFile -Value $entry
    switch ($Level) {
        "OK"    { Write-Host $entry -ForegroundColor Green }
        "WARN"  { Write-Host $entry -ForegroundColor Yellow }
        "ERROR" { Write-Host $entry -ForegroundColor Red }
        default { Write-Host $entry }
    }
}

Write-Log "Starting KFM policy configuration for TenantId: $TenantId"

# -- Ensure registry path exists --
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
    Write-Log "Created registry path: $registryPath"
}

# -- Apply KFM settings --
$settings = @{
    "KFMSilentOptIn"                  = $TenantId   # Silently move known folders
    "KFMSilentOptInWithNotification"  = 1            # Show notification after move
    "DisablePersonalSync"             = 0            # Allow personal OneDrive (set 1 to block)
}

foreach ($key in $settings.Keys) {
    try {
        $type  = if ($settings[$key] -is [int]) { "DWord" } else { "String" }
        Set-ItemProperty -Path $registryPath -Name $key -Value $settings[$key] -Type $type -Force
        Write-Log "Set $key = $($settings[$key])" -Level "OK"
    } catch {
        Write-Log "Failed to set $key – $($_.Exception.Message)" -Level "ERROR"
    }
}

# -- Restart OneDrive to apply --
Write-Log "Restarting OneDrive process..."
Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Process -FilePath "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
Write-Log "OneDrive restarted." -Level "OK"

Write-Log "KFM policy configuration complete."
