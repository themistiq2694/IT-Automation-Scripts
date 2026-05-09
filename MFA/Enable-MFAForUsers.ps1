# Enable-MFAForUsers.ps1
# Description : Enables or enforces MFA for a list of users supplied via CSV.
#               Supports bulk operations with dry-run mode and full audit logging.
#               Can target individual users or entire departments.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used during org-wide MFA rollout to manage phased enforcement
# Requires    : MSOnline module (Connect-MsolService)
# Usage       : .\Enable-MFAForUsers.ps1 -CsvPath "C:\users.csv" [-Enforce] [-WhatIf]
#               CSV must have column: UserPrincipalName

param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    # If set, state becomes "Enforced" instead of "Enabled"
    [switch]$Enforce,

    [switch]$WhatIf,

    [string]$OutputPath = "C:\Reports\MFA"
)

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }
if (-not (Test-Path $CsvPath))    { Write-Error "CSV not found: $CsvPath"; exit 1 }

# -- Connect --
try {
    Get-MsolDomain -ErrorAction Stop | Out-Null
} catch {
    Connect-MsolService -ErrorAction Stop
}

$targetState = if ($Enforce) { "Enforced" } else { "Enabled" }
$timestamp   = Get-Date -Format 'yyyyMMdd_HHmm'
$logFile     = Join-Path $OutputPath "MFA_Enable_Log_$timestamp.csv"

$users   = Import-Csv -Path $CsvPath
$results = @()

if ($WhatIf) { Write-Host "[DRY RUN] No changes will be made." -ForegroundColor Yellow }

Write-Host "[INFO] Processing $($users.Count) users | Target state: $targetState" -ForegroundColor Cyan

$mfaRequirement = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
$mfaRequirement.RelyingParty = "*"
$mfaRequirement.State        = $targetState

foreach ($row in $users) {
    $upn = $row.UserPrincipalName.Trim()
    try {
        $user = Get-MsolUser -UserPrincipalName $upn -ErrorAction Stop
        $currentState = $user.StrongAuthenticationRequirements.State
        if (-not $currentState) { $currentState = "NotEnabled" }

        if (-not $WhatIf) {
            Set-MsolUser -UserPrincipalName $upn `
                -StrongAuthenticationRequirements @($mfaRequirement) `
                -ErrorAction Stop
        }

        $status = if ($WhatIf) { "WhatIf – would set to $targetState" } else { "Success – set to $targetState" }
        Write-Host "  [OK] $upn ($currentState → $targetState)" -ForegroundColor Green

    } catch {
        $status       = "FAILED: $($_.Exception.Message)"
        $currentState = "Unknown"
        Write-Warning "  [FAIL] $upn – $($_.Exception.Message)"
    }

    $results += [PSCustomObject]@{
        UserPrincipalName = $upn
        PreviousState     = $currentState
        TargetState       = $targetState
        Status            = $status
        Timestamp         = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
}

$results | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8

$success = ($results | Where-Object { $_.Status -like "Success*" -or $_.Status -like "WhatIf*" }).Count
$failed  = ($results | Where-Object { $_.Status -like "FAILED*" }).Count

Write-Host "`n[SUMMARY] Success: $success | Failed: $failed" -ForegroundColor Cyan
Write-Host "[LOG] $logFile" -ForegroundColor Gray
