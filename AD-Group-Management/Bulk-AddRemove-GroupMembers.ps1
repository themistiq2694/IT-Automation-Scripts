# Bulk-AddRemove-GroupMembers.ps1
# Description : Adds or removes multiple users from an AD group using a CSV input file.
#               CSV must have a header column: SamAccountName
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Bulk-AddRemove-GroupMembers.ps1 -GroupName "HR-Team" -CsvPath "C:\users.csv" -Action Add

param(
    [Parameter(Mandatory)]
    [string]$GroupName,

    [Parameter(Mandatory)]
    [string]$CsvPath,

    [ValidateSet("Add", "Remove")]
    [string]$Action = "Add",

    [string]$LogPath = "C:\Reports"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

$users     = Import-Csv -Path $CsvPath
$timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
$logFile   = Join-Path $LogPath "GroupAction_${Action}_${GroupName}_$timestamp.csv"
$results   = @()

Write-Host "[INFO] Action: $Action | Group: $GroupName | Users: $($users.Count)" -ForegroundColor Cyan

foreach ($user in $users) {
    $sam = $user.SamAccountName.Trim()
    try {
        if ($Action -eq "Add") {
            Add-ADGroupMember -Identity $GroupName -Members $sam -ErrorAction Stop
        } else {
            Remove-ADGroupMember -Identity $GroupName -Members $sam -Confirm:$false -ErrorAction Stop
        }
        $status = "Success"
        Write-Host "  [OK] $sam" -ForegroundColor Green
    } catch {
        $status = "FAILED: $($_.Exception.Message)"
        Write-Warning "  [FAIL] $sam – $status"
    }

    $results += [PSCustomObject]@{
        SamAccountName = $sam
        Action         = $Action
        Group          = $GroupName
        Status         = $status
        Timestamp      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
}

$results | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8

$success = ($results | Where-Object { $_.Status -eq 'Success' }).Count
$failed  = ($results | Where-Object { $_.Status -ne 'Success' }).Count

Write-Host "`n[SUMMARY] Success: $success | Failed: $failed | Log: $logFile" -ForegroundColor Cyan
