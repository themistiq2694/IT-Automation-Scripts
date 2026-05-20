# Export-PreMigration-Snapshot.ps1
# Description : Captures a full snapshot of user UPNs, email addresses, group memberships,
#               and enabled status before a domain suffix migration.
#               Run BEFORE starting the migration. Save output as baseline reference.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used during migration from europe.domain_name.com → domain_name.com
# Usage       : .\Export-PreMigration-Snapshot.ps1 -OldSuffix "europe.domain_name.com"

param(
    [Parameter(Mandatory)]
    [string]$OldSuffix,

    [string]$OutputPath = "C:\Reports\DomainMigration"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

$timestamp = Get-Date -Format 'yyyyMMdd_HHmm'

Write-Host "[INFO] Collecting users with UPN suffix: @$OldSuffix" -ForegroundColor Cyan

$users = Get-ADUser -Filter { Enabled -eq $true } `
    -Properties UserPrincipalName, EmailAddress, DisplayName, Department,
                Title, Manager, MemberOf, ProxyAddresses, Enabled |
    Where-Object { $_.UserPrincipalName -like "*@$OldSuffix" }

$snapshot = foreach ($user in $users) {
    [PSCustomObject]@{
        DisplayName        = $user.DisplayName
        SamAccountName     = $user.SamAccountName
        UPN_Before         = $user.UserPrincipalName
        Email_Before       = $user.EmailAddress
        Department         = $user.Department
        Title              = $user.Title
        Manager            = try { (Get-ADUser $user.Manager -EA Stop).Name } catch { "" }
        GroupCount         = $user.MemberOf.Count
        ProxyAddresses     = ($user.ProxyAddresses -join " | ")
        Enabled            = $user.Enabled
    }
}

$snapshotFile = Join-Path $OutputPath "PreMigration_Snapshot_$timestamp.csv"
$snapshot | Export-Csv -Path $snapshotFile -NoTypeInformation -Encoding UTF8

Write-Host "[OK] Snapshot saved: $snapshotFile" -ForegroundColor Green
Write-Host "[OK] Total users captured: $($snapshot.Count)" -ForegroundColor Green
