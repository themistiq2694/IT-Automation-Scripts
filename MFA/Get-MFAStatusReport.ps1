# Get-MFAStatusReport.ps1
# Description : Generates a full MFA status report for all users in the tenant.
#               Shows per-user MFA state, default method, and registered methods.
#               Used during MFA rollout to track compliance progress.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used during org-wide MFA rollout (2018) and ongoing compliance audits
# Requires    : MSOnline module OR Microsoft.Graph.Authentication + Reports
# Usage       : .\Get-MFAStatusReport.ps1

param(
    [string]$OutputPath = "C:\Reports\MFA"
)

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$reportFile = Join-Path $OutputPath "MFA_StatusReport_$timestamp.csv"

# -- Connect to MSOnline --
try {
    Get-MsolDomain -ErrorAction Stop | Out-Null
    Write-Host "[INFO] Already connected to MSOnline." -ForegroundColor Gray
} catch {
    Write-Host "[INFO] Connecting to MSOnline..." -ForegroundColor Cyan
    Connect-MsolService -ErrorAction Stop
}

Write-Host "[INFO] Collecting MFA status for all users..." -ForegroundColor Cyan

$users = Get-MsolUser -All | Where-Object { $_.UserType -ne "Guest" }

$report = foreach ($user in $users) {
    $mfaState   = $user.StrongAuthenticationRequirements.State
    $defaultMethod = ($user.StrongAuthenticationMethods | Where-Object { $_.IsDefault }).MethodType
    $allMethods    = ($user.StrongAuthenticationMethods.MethodType) -join " | "

    [PSCustomObject]@{
        DisplayName      = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        Department        = $user.Department
        IsLicensed        = $user.IsLicensed
        BlockCredential   = $user.BlockCredential
        MFAState          = if ($mfaState) { $mfaState } else { "NotEnabled" }
        DefaultMethod     = if ($defaultMethod) { $defaultMethod } else { "None" }
        RegisteredMethods = if ($allMethods)    { $allMethods }    else { "None" }
    }
}

$report | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8

# -- Summary --
$enabled   = ($report | Where-Object { $_.MFAState -eq "Enabled"   }).Count
$enforced  = ($report | Where-Object { $_.MFAState -eq "Enforced"  }).Count
$disabled  = ($report | Where-Object { $_.MFAState -eq "NotEnabled" -or $_.MFAState -eq "Disabled" }).Count

Write-Host "`n=== MFA Compliance Summary ===" -ForegroundColor Cyan
Write-Host "  Enforced  : $enforced" -ForegroundColor Green
Write-Host "  Enabled   : $enabled"  -ForegroundColor Yellow
Write-Host "  Not Enabled: $disabled" -ForegroundColor Red
Write-Host "  Total Users: $($report.Count)"
Write-Host "`n[REPORT] $reportFile" -ForegroundColor Gray
