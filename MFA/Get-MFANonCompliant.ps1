# Get-MFANonCompliant.ps1
# Description : Identifies users who have not registered MFA methods
#               and optionally sends them a reminder email via Exchange Online.
#               Useful for tracking rollout compliance and chasing stragglers.
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Get-MFANonCompliant.ps1 [-SendReminder] [-ExcludeAdmins]

param(
    [switch]$SendReminder,
    [switch]$ExcludeAdmins,
    [string]$OutputPath    = "C:\Reports\MFA",
    [string]$SenderAddress = "teambox@domain_name.com"
)

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }

# -- Connect --
try { Get-MsolDomain -ErrorAction Stop | Out-Null } catch { Connect-MsolService }
if ($SendReminder) {
    try { Get-OrganizationConfig -ErrorAction Stop | Out-Null } catch { Connect-ExchangeOnline }
}

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$reportFile = Join-Path $OutputPath "MFA_NonCompliant_$timestamp.csv"

Write-Host "[INFO] Identifying non-MFA-registered users..." -ForegroundColor Cyan

$allUsers = Get-MsolUser -All | Where-Object {
    $_.IsLicensed -eq $true -and
    $_.BlockCredential -eq $false -and
    $_.UserType -ne "Guest" -and
    ($_.StrongAuthenticationMethods.Count -eq 0)
}

if ($ExcludeAdmins) {
    $adminRoles = Get-MsolRole | ForEach-Object { Get-MsolRoleMember -RoleObjectId $_.ObjectId } |
        Select-Object -ExpandProperty EmailAddress
    $allUsers = $allUsers | Where-Object { $_.UserPrincipalName -notin $adminRoles }
}

$nonCompliant = foreach ($user in $allUsers) {
    [PSCustomObject]@{
        DisplayName       = $user.DisplayName
        UserPrincipalName = $user.UserPrincipalName
        Department        = $user.Department
        MFAState          = if ($user.StrongAuthenticationRequirements.State) {
                                $user.StrongAuthenticationRequirements.State
                            } else { "NotEnabled" }
        LastDirSyncTime   = $user.LastDirSyncTime
    }
}

$nonCompliant | Export-Csv -Path $reportFile -NoTypeInformation -Encoding UTF8
Write-Host "[OK] $($nonCompliant.Count) non-compliant users found. Report: $reportFile" -ForegroundColor Yellow

# -- Optional: Send reminder emails --
if ($SendReminder -and $nonCompliant.Count -gt 0) {
    Write-Host "[INFO] Sending reminder emails..." -ForegroundColor Cyan
    $reminderBody = @"
Dear {NAME},

As part of our organisation's security requirements, all accounts must have
Multi-Factor Authentication (MFA) registered.

Our records show your account does not yet have MFA set up.

Please register your MFA methods as soon as possible:
1. Go to: https://aka.ms/mfasetup
2. Sign in with your corporate account
3. Follow the on-screen instructions to register at least one method
   (Authenticator app recommended)

If you need assistance, please contact the IT Support team.

IT Support Team
"@

    $sent = 0
    foreach ($user in $nonCompliant) {
        try {
            $body = $reminderBody -replace '{NAME}', $user.DisplayName
            Send-MailMessage `
                -From    $SenderAddress `
                -To      $user.UserPrincipalName `
                -Subject "Action Required: Please register MFA for your account" `
                -Body    $body `
                -SmtpServer "smtp.office365.com" `
                -Port 587 `
                -UseSsl `
                -ErrorAction Stop
            $sent++
            Write-Host "  [OK] Reminder sent to: $($user.UserPrincipalName)" -ForegroundColor Green
        } catch {
            Write-Warning "  [FAIL] Could not send to $($user.UserPrincipalName): $($_.Exception.Message)"
        }
    }
    Write-Host "[INFO] Reminders sent: $sent / $($nonCompliant.Count)" -ForegroundColor Cyan
}
