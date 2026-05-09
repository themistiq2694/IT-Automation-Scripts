# Get-NestedGroupMembers.ps1
# Description : Lists all members of an AD group, including members of nested groups (recursive).
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Get-NestedGroupMembers.ps1 -GroupName "IT-Support"

param(
    [Parameter(Mandatory)]
    [string]$GroupName,
    [string]$OutputPath = "C:\Reports"
)

Import-Module ActiveDirectory -ErrorAction Stop

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$outputFile = Join-Path $OutputPath "Members_${GroupName}_$timestamp.csv"

function Get-NestedGroupMembers {
    param([string]$Group)

    Get-ADGroupMember -Identity $Group -Recursive |
        Where-Object { $_.objectClass -eq 'user' } |
        Get-ADUser -Properties DisplayName, EmailAddress, Department, Title, Enabled |
        Select-Object `
            DisplayName,
            SamAccountName,
            @{N='Email';      E={ $_.EmailAddress }},
            Department,
            Title,
            Enabled
}

Write-Host "[INFO] Resolving members for group: $GroupName" -ForegroundColor Cyan

$members = Get-NestedGroupMembers -Group $GroupName

if ($members.Count -eq 0) {
    Write-Warning "No members found for group '$GroupName'."
} else {
    $members | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "[OK] $($members.Count) members exported to: $outputFile" -ForegroundColor Green
}
