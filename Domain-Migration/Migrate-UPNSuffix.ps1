# Migrate-UPNSuffix.ps1
# Description : Migrates user UPNs and proxy addresses from a subdomain suffix
#               to the parent domain suffix in bulk.
#               Includes dry-run mode, logging, and rollback CSV generation.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used during migration from europe.temenosgroup.com → temenosgroup.com
# Usage       : .\Migrate-UPNSuffix.ps1 -OldSuffix "europe.domain_name.com" -NewSuffix "domain_name.com" [-WhatIf]

param(
    [Parameter(Mandatory)]
    [string]$OldSuffix,

    [Parameter(Mandatory)]
    [string]$NewSuffix,

    [switch]$WhatIf,

    [string]$OutputPath = "C:\Reports\DomainMigration"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$logFile    = Join-Path $OutputPath "UPNMigration_Log_$timestamp.csv"
$rollbackFile = Join-Path $OutputPath "UPNMigration_Rollback_$timestamp.csv"

if ($WhatIf) {
    Write-Host "[DRY RUN MODE] No changes will be made." -ForegroundColor Yellow
}

Write-Host "[INFO] Collecting users with UPN suffix: @$OldSuffix" -ForegroundColor Cyan

$users = Get-ADUser -Filter { Enabled -eq $true } `
    -Properties UserPrincipalName, EmailAddress, ProxyAddresses |
    Where-Object { $_.UserPrincipalName -like "*@$OldSuffix" }

Write-Host "[INFO] Found $($users.Count) users to process." -ForegroundColor Cyan

$results  = @()
$rollback = @()

foreach ($user in $users) {
    $oldUPN   = $user.UserPrincipalName
    $newUPN   = $oldUPN -replace [regex]::Escape($OldSuffix), $NewSuffix

    # Build updated proxy addresses
    $newProxies = $user.ProxyAddresses | ForEach-Object {
        $_ -replace [regex]::Escape($OldSuffix), $NewSuffix
    }

    $rollback += [PSCustomObject]@{
        SamAccountName = $user.SamAccountName
        OldUPN         = $oldUPN
        OldProxies     = ($user.ProxyAddresses -join " | ")
    }

    try {
        if (-not $WhatIf) {
            Set-ADUser -Identity $user.SamAccountName `
                -UserPrincipalName $newUPN `
                -Replace @{ proxyAddresses = $newProxies } `
                -ErrorAction Stop
        }

        $status = if ($WhatIf) { "WhatIf – would change" } else { "Success" }
        Write-Host "  [OK] $oldUPN → $newUPN" -ForegroundColor Green

    } catch {
        $status = "FAILED: $($_.Exception.Message)"
        Write-Warning "  [FAIL] $oldUPN – $status"
    }

    $results += [PSCustomObject]@{
        SamAccountName = $user.SamAccountName
        UPN_Before     = $oldUPN
        UPN_After      = $newUPN
        Status         = $status
        Timestamp      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
}

$results  | Export-Csv -Path $logFile    -NoTypeInformation -Encoding UTF8
$rollback | Export-Csv -Path $rollbackFile -NoTypeInformation -Encoding UTF8

$success = ($results | Where-Object { $_.Status -like "Success*" }).Count
$failed  = ($results | Where-Object { $_.Status -like "FAILED*" }).Count

Write-Host "`n[SUMMARY] Processed: $($users.Count) | Success: $success | Failed: $failed" -ForegroundColor Cyan
Write-Host "[LOG]      $logFile" -ForegroundColor Gray
Write-Host "[ROLLBACK] $rollbackFile" -ForegroundColor Gray
