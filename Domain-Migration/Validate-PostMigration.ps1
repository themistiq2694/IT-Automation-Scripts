# Validate-PostMigration.ps1
# Description : Compares pre-migration snapshot with current AD state to confirm
#               all UPNs were successfully migrated to the new domain suffix.
#               Generates a discrepancy report for any failures.
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Validate-PostMigration.ps1 -SnapshotCsv "C:\Reports\PreMigration_Snapshot.csv" -NewSuffix "domain_name.com"

param(
    [Parameter(Mandatory)]
    [string]$SnapshotCsv,

    [Parameter(Mandatory)]
    [string]$NewSuffix,

    [string]$OutputPath = "C:\Reports\DomainMigration"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $SnapshotCsv)) {
    Write-Error "Snapshot CSV not found: $SnapshotCsv"
    exit 1
}

$timestamp    = Get-Date -Format 'yyyyMMdd_HHmm'
$reportFile   = Join-Path $OutputPath "PostMigration_Validation_$timestamp.csv"
$snapshot     = Import-Csv -Path $SnapshotCsv
$results      = @()

Write-Host "[INFO] Validating $($snapshot.Count) users against current AD state..." -ForegroundColor Cyan

foreach ($row in $snapshot) {
    $adUser = Get-ADUser -Identity $row.SamAccountName `
        -Properties UserPrincipalName, EmailAddress, Enabled -ErrorAction SilentlyContinue

    if (-not $adUser) {
        $validationStatus = "USER NOT FOUND IN AD"
    } elseif ($adUser.UserPrincipalName -like "*@$NewSuffix") {
        $validationStatus = "OK – Migrated"
    } else {
        $validationStatus = "NOT MIGRATED – UPN still: $($adUser.UserPrincipalName)"
    }

    $results += [PSCustomObject]@{
        SamAccountName  = $row.SamAccountName
        DisplayName     = $row.DisplayName
        UPN_Before      = $row.UPN_Before
        UPN_Current     = if ($adUser) { $adUser.UserPrincipalName } else { "N/A" }
        ValidationStatus = $validationStatus
    }
}

$results | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8

$ok      = ($results | Where-Object { $_.ValidationStatus -like "OK*" }).Count
$issues  = ($results | Where-Object { $_.ValidationStatus -notlike "OK*" }).Count

Write-Host "`n[SUMMARY] OK: $ok | Issues: $issues" -ForegroundColor Cyan

if ($issues -gt 0) {
    Write-Host "[ATTENTION] Users with issues:" -ForegroundColor Red
    $results | Where-Object { $_.ValidationStatus -notlike "OK*" } |
        Format-Table SamAccountName, UPN_Before, UPN_Current, ValidationStatus -AutoSize
}

Write-Host "[REPORT] $reportFile" -ForegroundColor Gray
