# Remove-UserOffboarding.ps1
# Description : Secure, audited offboarding of a departing employee.
#               Disables account, resets password, revokes sessions, removes group memberships,
#               converts mailbox to shared, and generates full audit report.
#               Designed to be run same-day as the employee's last working day.
# Author      : Mihail-Petre Dragutoiu
# Context     : Part of standard offboarding SOP at the COmpany I used to work for
# Requires    : ActiveDirectory, MSOnline, ExchangeOnlineManagement
# Usage       : .\Remove-UserOffboarding.ps1 -UserPrincipalName "john.doe@domain_name.com" [-ManagerUPN "jane.smith@domain_name.com"]

param(
    [Parameter(Mandatory)]
    [string]$UserPrincipalName,

    # If provided, manager gets full access to the converted shared mailbox
    [string]$ManagerUPN,

    [switch]$WhatIf,

    [string]$OutputPath = "C:\Reports\Offboarding"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

$timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
$logFile   = Join-Path $OutputPath "Offboarding_$(($UserPrincipalName -split '@')[0])_$timestamp.csv"
$steps     = @()

if ($WhatIf) { Write-Host "[DRY RUN] No changes will be made." -ForegroundColor Yellow }

# -- Connect --
try { Get-MsolDomain -EA Stop | Out-Null } catch { Connect-MsolService }
try { Get-OrganizationConfig -EA Stop | Out-Null } catch { Connect-ExchangeOnline }

# -- Resolve AD user --
$samAccount = $null
try {
    $adUser     = Get-ADUser -Filter { UserPrincipalName -eq $UserPrincipalName } `
                    -Properties MemberOf, DisplayName, Department, Title, Manager -ErrorAction Stop
    $samAccount = $adUser.SamAccountName
    Write-Host "`n[OFFBOARDING] $($adUser.DisplayName) ($UserPrincipalName)" -ForegroundColor Cyan
} catch {
    Write-Error "User not found in AD: $UserPrincipalName"
    exit 1
}

function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    try {
        if (-not $WhatIf) { & $Action }
        $status = if ($WhatIf) { "WhatIf – would execute" } else { "Success" }
        Write-Host "  [OK] $Name" -ForegroundColor Green
    } catch {
        $status = "FAILED: $($_.Exception.Message)"
        Write-Warning "  [FAIL] $Name – $($_.Exception.Message)"
    }
    $script:steps += [PSCustomObject]@{ Step = $Name; Status = $status }
}

# ── Step 1: Disable AD Account ──────────────────────────────────────────────
Invoke-Step "Disable AD Account" {
    Disable-ADAccount -Identity $samAccount
}

# ── Step 2: Reset Password to Random (prevent re-enable login) ──────────────
Invoke-Step "Reset AD Password" {
    $newPwd = [System.Web.Security.Membership]::GeneratePassword(20, 4)
    Set-ADAccountPassword -Identity $samAccount `
        -NewPassword (ConvertTo-SecureString $newPwd -AsPlainText -Force) `
        -Reset
}

# ── Step 3: Revoke all Azure AD / M365 Sessions ─────────────────────────────
Invoke-Step "Revoke M365 Sessions" {
    Revoke-MsolAllUserSessions -UserPrincipalName $UserPrincipalName
}

# ── Step 4: Block M365 Sign-In ──────────────────────────────────────────────
Invoke-Step "Block M365 Sign-In" {
    Set-MsolUser -UserPrincipalName $UserPrincipalName -BlockCredential $true
}

# ── Step 5: Remove MFA requirements (cleanup) ───────────────────────────────
Invoke-Step "Clear MFA Requirements" {
    Set-MsolUser -UserPrincipalName $UserPrincipalName `
        -StrongAuthenticationRequirements @()
}

# ── Step 6: Capture group memberships (before removal) ──────────────────────
$groupsBefore = $adUser.MemberOf | ForEach-Object {
    (Get-ADGroup -Identity $_ -ErrorAction SilentlyContinue).Name
}
$steps += [PSCustomObject]@{
    Step   = "Group Membership Snapshot"
    Status = "Captured $($groupsBefore.Count) groups: $($groupsBefore -join ', ')"
}
Write-Host "  [INFO] Captured $($groupsBefore.Count) group memberships" -ForegroundColor Gray

# ── Step 7: Remove all AD Group Memberships ─────────────────────────────────
Invoke-Step "Remove All AD Group Memberships" {
    $adUser.MemberOf | ForEach-Object {
        Remove-ADGroupMember -Identity $_ -Members $samAccount -Confirm:$false -ErrorAction SilentlyContinue
    }
}

# ── Step 8: Remove M365 Licenses ─────────────────────────────────────────────
Invoke-Step "Remove M365 Licenses" {
    $msolUser = Get-MsolUser -UserPrincipalName $UserPrincipalName
    foreach ($lic in $msolUser.Licenses) {
        Set-MsolUserLicense -UserPrincipalName $UserPrincipalName -RemoveLicenses $lic.AccountSkuId
    }
}

# ── Step 9: Convert mailbox to Shared ──────────────────────────────────────
Invoke-Step "Convert Mailbox to Shared" {
    Set-Mailbox -Identity $UserPrincipalName -Type Shared
}

# ── Step 10: Grant Manager access to shared mailbox (if provided) ───────────
if ($ManagerUPN) {
    Invoke-Step "Grant Manager ($ManagerUPN) Full Access to Shared Mailbox" {
        Add-MailboxPermission -Identity $UserPrincipalName -User $ManagerUPN `
            -AccessRights FullAccess -AutoMapping $true -ErrorAction Stop
        Add-RecipientPermission -Identity $UserPrincipalName -Trustee $ManagerUPN `
            -AccessRights SendAs -Confirm:$false -ErrorAction Stop
    }
}

# ── Step 11: Move AD account to Disabled OU ─────────────────────────────────
Invoke-Step "Move AD Account to Disabled OU" {
    Move-ADObject -Identity $adUser.DistinguishedName `
        -TargetPath "OU=Disabled,DC=temenosgroup,DC=com"
}

# ── Step 12: Update AD Description ──────────────────────────────────────────
Invoke-Step "Update AD Description (offboarding date)" {
    Set-ADUser -Identity $samAccount `
        -Description "DISABLED – Offboarded $(Get-Date -f 'yyyy-MM-dd') | Was: $($adUser.Title), $($adUser.Department)"
}

# -- Export audit log --
$steps | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8

$success = ($steps | Where-Object { $_.Status -like "Success*" -or $_.Status -like "Captured*" }).Count
$failed  = ($steps | Where-Object { $_.Status -like "FAILED*" }).Count

Write-Host "`n[SUMMARY] Steps OK: $success | Failed: $failed" -ForegroundColor Cyan
Write-Host "[AUDIT LOG] $logFile" -ForegroundColor Gray

if ($failed -gt 0) {
    Write-Host "`n[ATTENTION] The following steps require manual review:" -ForegroundColor Red
    $steps | Where-Object { $_.Status -like "FAILED*" } | Format-Table Step, Status -AutoSize -Wrap
}
