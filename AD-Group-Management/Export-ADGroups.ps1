# Export-ADGroups.ps1
# Description : Exports all Active Directory groups with key metadata to CSV.
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Export-ADGroups.ps1 [-OutputPath "C:\Reports"]

param(
    [string]$OutputPath = "C:\Reports"
)

Import-Module ActiveDirectory -ErrorAction Stop

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$outputFile = Join-Path $OutputPath "AD_Groups_Export_$timestamp.csv"

Write-Host "[INFO] Collecting AD groups..." -ForegroundColor Cyan

$groups = Get-ADGroup -Filter * -Properties Description, ManagedBy, GroupScope, GroupCategory, Members, Created, Modified |
    Select-Object `
        Name,
        SamAccountName,
        GroupScope,
        GroupCategory,
        Description,
        @{N='ManagedBy';     E={ try { (Get-ADUser $_.ManagedBy -EA Stop).Name } catch { $_.ManagedBy } }},
        @{N='MemberCount';   E={ ($_.Members).Count }},
        @{N='Created';       E={ $_.Created }},
        @{N='LastModified';  E={ $_.Modified }}

$groups | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8

Write-Host "[OK] Exported $($groups.Count) groups to: $outputFile" -ForegroundColor Green
