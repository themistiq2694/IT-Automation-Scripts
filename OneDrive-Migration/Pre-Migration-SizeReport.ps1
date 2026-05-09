# Pre-Migration-SizeReport.ps1
# Description : Generates a storage size report for all users before OneDrive migration.
#               Helps identify large accounts, estimate migration duration, and plan batches.
# Author      : Mihail-Petre Dragutoiu
# Requires    : SharePoint Online Management Shell (Connect-SPOService)
# Usage       : .\Pre-Migration-SizeReport.ps1 -AdminUrl "https://tenant-admin.sharepoint.com"

param(
    [Parameter(Mandatory)]
    [string]$AdminUrl,

    [string]$OutputPath = "C:\Reports\OneDriveMigration"
)

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

# -- Connect --
try {
    Get-SPOTenant -ErrorAction Stop | Out-Null
    Write-Host "[INFO] Already connected to SharePoint Online." -ForegroundColor Gray
} catch {
    Write-Host "[INFO] Connecting to SharePoint Online..." -ForegroundColor Cyan
    Connect-SPOService -Url $AdminUrl -ErrorAction Stop
}

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$reportFile = Join-Path $OutputPath "OneDrive_SizeReport_$timestamp.csv"

Write-Host "[INFO] Collecting OneDrive site data..." -ForegroundColor Cyan

$sites = Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'"

$report = foreach ($site in $sites) {
    [PSCustomObject]@{
        Owner          = $site.Owner
        Url            = $site.Url
        StorageUsedGB  = [math]::Round($site.StorageUsageCurrent / 1024, 2)
        StorageQuotaGB = [math]::Round($site.StorageQuota / 1024, 2)
        LastContentModified = $site.LastContentModifiedDate
        Status         = $site.Status
    }
}

$report | Sort-Object StorageUsedGB -Descending |
    Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8

$totalGB   = ($report | Measure-Object -Property StorageUsedGB -Sum).Sum
$largeAcct = ($report | Where-Object { $_.StorageUsedGB -gt 50 }).Count

Write-Host "[OK] Report saved: $reportFile" -ForegroundColor Green
Write-Host "[INFO] Total storage in use: $([math]::Round($totalGB,2)) GB" -ForegroundColor Cyan
Write-Host "[INFO] Accounts over 50 GB: $largeAcct (consider separate migration batch)" -ForegroundColor Yellow
