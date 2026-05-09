# Update-UserRoleChange.ps1
# Description : Handles internal user transfers and role changes.
#               Updates AD attributes, swaps group memberships, adjusts mailbox
#               permissions, and logs all changes for audit purposes.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used for department transfers and promotions at Temenos Group
# Requires    : ActiveDirectory, ExchangeOnlineManagement
# Usage       : .\Update-UserRoleChange.ps1 -UserPrincipalName "john.doe@temenosgroup.com" `
#                   -NewTitle "Senior Analyst" -NewDepartment "Finance" `
#                   -NewManager "jane.smith@temenosgroup.com" `
#                   -GroupsToAdd "Finance-Team,Finance-SharePoint" `
#                   -GroupsToRemove "IT-Support,IT-SharePoint" `
#                   -SharedMailboxToAdd "finance@temenosgroup.com" `
#                   -SharedMailboxToRemove "it-support@temenosgroup.com"

param(
    [Parameter(Mandatory)]
    [string]$UserPrincipalName,

    [string]$NewTitle,
    [string]$NewDepartment,
    [string]$NewManager,
    [string]$NewOfficeLocation,

    # Comma-separated group names
    [string]$GroupsToAdd,
    [string]$GroupsToRemove,

    # Shared mailbox UPNs (comma-separated)
    [string]$SharedMailboxToAdd,
    [string]$SharedMailboxToRemove,

    [switch]$WhatIf,
    [string]$OutputPath = "C:\Reports\RoleChanges"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

$sam = $null
try {
    $adUser = Get-ADUser -Filter { UserPrincipalName -eq $UserPrincipalName } `
                -Properties DisplayName, Title, Department, Manager, Office -ErrorAction Stop
    $sam    = $adUser.SamAccountName
} catch {
    Write-Error "User not found: $UserPrincipalName"
    exit 1
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
$logFile   = Join-Path $OutputPath "RoleChange_${sam}_$timestamp.csv"
$steps     = @()

if ($WhatIf) { Write-Host "[DRY RUN] No changes will be made." -ForegroundColor Yellow }
Write-Host "`n[ROLE CHANGE] $($adUser.DisplayName) ($UserPrincipalName)" -ForegroundColor Cyan

# -- Connect Exchange if mailbox changes needed --
if ($SharedMailboxToAdd -or $SharedMailboxToRemove) {
    try { Get-OrganizationConfig -EA Stop | Out-Null } catch { Connect-ExchangeOnline }
}

function Log-Step {
    param([string]$Name, [string]$Status)
    $steps += [PSCustomObject]@{ Step = $Name; Status = $Status; Timestamp = (Get-Date -f 'HH:mm:ss') }
    $script:steps = $steps
}

# ── Step 1: Update AD Attributes ─────────────────────────────────────────────
$adChanges = @{}
if ($NewTitle)          { $adChanges['Title']      = $NewTitle }
if ($NewDepartment)     { $adChanges['Department'] = $NewDepartment }
if ($NewOfficeLocation) { $adChanges['Office']     = $NewOfficeLocation }

if ($adChanges.Count -gt 0) {
    try {
        # Snapshot before
        $before = "Title=$($adUser.Title) | Dept=$($adUser.Department) | Office=$($adUser.Office)"

        if (-not $WhatIf) { Set-ADUser -Identity $sam -Replace $adChanges }

        $after = ($adChanges.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join " | "
        Write-Host "  [OK] AD attributes updated: $after" -ForegroundColor Green
        Log-Step "Update AD Attributes" "Success | Before: $before | After: $after"
    } catch {
        Write-Warning "  [FAIL] AD attributes – $($_.Exception.Message)"
        Log-Step "Update AD Attributes" "FAILED: $($_.Exception.Message)"
    }
}

# ── Step 2: Update Manager ───────────────────────────────────────────────────
if ($NewManager) {
    try {
        $newMgrDN = (Get-ADUser -Filter { UserPrincipalName -eq $NewManager } -EA Stop).DistinguishedName
        if (-not $WhatIf) { Set-ADUser -Identity $sam -Manager $newMgrDN }
        Write-Host "  [OK] Manager updated to: $NewManager" -ForegroundColor Green
        Log-Step "Update Manager" "Success – $NewManager"
    } catch {
        Write-Warning "  [FAIL] Manager update – $($_.Exception.Message)"
        Log-Step "Update Manager" "FAILED: $($_.Exception.Message)"
    }
}

# ── Step 3: Add to New Groups ────────────────────────────────────────────────
if ($GroupsToAdd) {
    foreach ($group in ($GroupsToAdd -split ",")) {
        $group = $group.Trim()
        try {
            if (-not $WhatIf) { Add-ADGroupMember -Identity $group -Members $sam -ErrorAction Stop }
            Write-Host "  [OK] Added to group: $group" -ForegroundColor Green
            Log-Step "Add to Group: $group" "Success"
        } catch {
            Write-Warning "  [FAIL] Add group '$group' – $($_.Exception.Message)"
            Log-Step "Add to Group: $group" "FAILED: $($_.Exception.Message)"
        }
    }
}

# ── Step 4: Remove from Old Groups ──────────────────────────────────────────
if ($GroupsToRemove) {
    foreach ($group in ($GroupsToRemove -split ",")) {
        $group = $group.Trim()
        try {
            if (-not $WhatIf) { Remove-ADGroupMember -Identity $group -Members $sam -Confirm:$false -ErrorAction Stop }
            Write-Host "  [OK] Removed from group: $group" -ForegroundColor Green
            Log-Step "Remove from Group: $group" "Success"
        } catch {
            Write-Warning "  [FAIL] Remove group '$group' – $($_.Exception.Message)"
            Log-Step "Remove from Group: $group" "FAILED: $($_.Exception.Message)"
        }
    }
}

# ── Step 5: Grant Shared Mailbox Access ──────────────────────────────────────
if ($SharedMailboxToAdd) {
    foreach ($mbx in ($SharedMailboxToAdd -split ",")) {
        $mbx = $mbx.Trim()
        try {
            if (-not $WhatIf) {
                Add-MailboxPermission -Identity $mbx -User $UserPrincipalName `
                    -AccessRights FullAccess -AutoMapping $true -ErrorAction Stop
                Add-RecipientPermission -Identity $mbx -Trustee $UserPrincipalName `
                    -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            }
            Write-Host "  [OK] Shared mailbox access granted: $mbx" -ForegroundColor Green
            Log-Step "Grant Mailbox Access: $mbx" "Success"
        } catch {
            Write-Warning "  [FAIL] Mailbox access '$mbx' – $($_.Exception.Message)"
            Log-Step "Grant Mailbox Access: $mbx" "FAILED: $($_.Exception.Message)"
        }
    }
}

# ── Step 6: Revoke Old Shared Mailbox Access ─────────────────────────────────
if ($SharedMailboxToRemove) {
    foreach ($mbx in ($SharedMailboxToRemove -split ",")) {
        $mbx = $mbx.Trim()
        try {
            if (-not $WhatIf) {
                Remove-MailboxPermission -Identity $mbx -User $UserPrincipalName `
                    -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
                Remove-RecipientPermission -Identity $mbx -Trustee $UserPrincipalName `
                    -AccessRights SendAs -Confirm:$false -ErrorAction Stop
            }
            Write-Host "  [OK] Shared mailbox access revoked: $mbx" -ForegroundColor Green
            Log-Step "Revoke Mailbox Access: $mbx" "Success"
        } catch {
            Write-Warning "  [FAIL] Revoke mailbox '$mbx' – $($_.Exception.Message)"
            Log-Step "Revoke Mailbox Access: $mbx" "FAILED: $($_.Exception.Message)"
        }
    }
}

# -- Save log --
$steps | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8

$success = ($steps | Where-Object { $_.Status -like "Success*" }).Count
$failed  = ($steps | Where-Object { $_.Status -like "FAILED*" }).Count

Write-Host "`n[SUMMARY] Steps OK: $success | Failed: $failed" -ForegroundColor Cyan
Write-Host "[AUDIT LOG] $logFile" -ForegroundColor Gray
