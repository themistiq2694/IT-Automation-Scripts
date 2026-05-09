# Post-Wipe-Checklist.ps1
# Description : Interactive pre-wipe checklist to confirm all data is safe
#               before resetting a device via Windows Autopilot.
#               Guides the technician through each mandatory step, then
#               optionally initiates the Autopilot reset.
# Author      : Mihail-Petre Dragutoiu
# Context     : Windows 10 → Windows 11 migration (270+ devices, Entra-only, zero incidents)
# Usage       : .\Post-Wipe-Checklist.ps1

$hostname = $env:COMPUTERNAME
$user     = $env:USERNAME
$logFile  = "C:\Autopilot\PreWipe_Checklist_${hostname}_$(Get-Date -f 'yyyyMMdd_HHmm').txt"

if (-not (Test-Path "C:\Autopilot")) { New-Item -ItemType Directory "C:\Autopilot" | Out-Null }

function Write-Log {
    param([string]$Msg)
    Add-Content -Path $logFile -Value "$(Get-Date -f 'HH:mm:ss') $Msg"
}

function Confirm-Step {
    param([string]$StepName, [string]$Description)
    Write-Host "`n  [$StepName]" -ForegroundColor Yellow
    Write-Host "  $Description" -ForegroundColor Gray
    do {
        $answer = Read-Host "  Confirmed? (Y/N)"
    } while ($answer -notin @("Y","y","N","n"))

    $confirmed = $answer -in @("Y","y")
    $status    = if ($confirmed) { "CONFIRMED" } else { "SKIPPED/NOT DONE" }
    Write-Log "  $StepName – $status"
    return $confirmed
}

Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host "  PRE-WIPE CHECKLIST – $hostname" -ForegroundColor Cyan
Write-Host "  Technician: $user | $(Get-Date -f 'yyyy-MM-dd HH:mm')" -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan

Write-Log "=== Pre-Wipe Checklist – $hostname – $user – $(Get-Date) ==="

$steps = @(
    @{ Name = "OneDrive Sync"; Desc = "OneDrive is fully synced (no pending files, sync icon is green)." },
    @{ Name = "Desktop Backup"; Desc = "Desktop, Documents, Pictures confirmed redirected to OneDrive (KFM active)." },
    @{ Name = "Browser Data"; Desc = "User has signed in to browser with M365 account (bookmarks/passwords synced)." },
    @{ Name = "Local Apps"; Desc = "Any locally installed apps that need re-provisioning have been noted." },
    @{ Name = "Autopilot Enrolled"; Desc = "Device serial confirmed in Autopilot/Intune. (Run Validate-AutopilotEnrollment.ps1 first)" },
    @{ Name = "User Notified"; Desc = "User has been informed of the wipe and confirmed data is safe." },
    @{ Name = "Ticket Updated"; Desc = "ITSM ticket updated with device details and migration status." }
)

$allPassed = $true
foreach ($step in $steps) {
    $result   = Confirm-Step -StepName $step.Name -Description $step.Desc
    if (-not $result) { $allPassed = $false }
}

Write-Host "`n------------------------------------------" -ForegroundColor Gray

if ($allPassed) {
    Write-Host "`n[ALL CHECKS PASSED] Device is ready for wipe." -ForegroundColor Green
    Write-Log "ALL CHECKS PASSED – Device approved for wipe."

    $initReset = Read-Host "`nInitiate Autopilot Reset now? This will WIPE the device. (Y/N)"
    if ($initReset -in @("Y","y")) {
        Write-Log "Technician initiated Autopilot Reset."
        Write-Host "[INFO] Initiating Windows Autopilot Reset..." -ForegroundColor Yellow
        # Autopilot reset via MDM enrollment / local command
        # Note: In Intune, this can also be triggered remotely via portal or Graph API
        & systemreset --factoryreset 2>&1 | Out-Null
        # Alternative for Autopilot self-deploying:
        # Start-Process "ms-settings:recovery"
    } else {
        Write-Host "[INFO] Wipe NOT initiated. Checklist saved." -ForegroundColor Cyan
    }
} else {
    Write-Host "`n[HOLD] Not all checks passed. Resolve outstanding items before wiping." -ForegroundColor Red
    Write-Log "HOLD – Not all steps confirmed. Wipe not initiated."
}

Write-Host "`n[LOG] $logFile`n" -ForegroundColor Gray
