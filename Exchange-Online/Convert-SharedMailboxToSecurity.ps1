# Convert-SharedMailboxToSecurity.ps1
# Description : Converts a Shared Mailbox to a Regular mailbox (optionally disabling it),
#               then creates a corresponding Security Group in Active Directory.
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Convert-SharedMailboxToSecurity.ps1 -Identity "teambox@domain.com" -TargetOU "OU=SecurityGroups,DC=domain,DC=com"
# Requires    : Exchange Online Management Shell, RSAT AD module

param(
    [Parameter(Mandatory)]
    [string]$Identity,

    [Parameter(Mandatory)]
    [string]$TargetOU,

    [switch]$DisableMailbox
)

Import-Module ActiveDirectory -ErrorAction Stop

# -- Connect to Exchange Online if not already connected --
try {
    Get-OrganizationConfig -ErrorAction Stop | Out-Null
    Write-Host "[INFO] Already connected to Exchange Online." -ForegroundColor Gray
} catch {
    Write-Host "[INFO] Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ErrorAction Stop
}

# -- Validate mailbox --
$mailbox = Get-Mailbox -Identity $Identity -ErrorAction SilentlyContinue
if (-not $mailbox) {
    Write-Error "Mailbox not found: $Identity"
    exit 1
}

Write-Host "[INFO] Found mailbox: $($mailbox.DisplayName) | Type: $($mailbox.RecipientTypeDetails)" -ForegroundColor Cyan

# -- Convert Shared → Regular --
if ($mailbox.RecipientTypeDetails -eq "SharedMailbox") {
    Set-Mailbox -Identity $Identity -Type Regular
    Write-Host "[OK] Mailbox converted to Regular." -ForegroundColor Green

    if ($DisableMailbox) {
        Disable-Mailbox -Identity $Identity -Confirm:$false
        Write-Host "[OK] Mailbox disabled (AD account retained)." -ForegroundColor Yellow
    }
} else {
    Write-Warning "Mailbox type is '$($mailbox.RecipientTypeDetails)' – skipping type conversion."
}

# -- Create AD Security Group --
$groupName = ($Identity -split '@')[0]

$existingGroup = Get-ADGroup -Filter { Name -eq $groupName } -ErrorAction SilentlyContinue
if ($existingGroup) {
    Write-Warning "AD group '$groupName' already exists. Skipping creation."
} else {
    New-ADGroup `
        -Name           $groupName `
        -SamAccountName $groupName `
        -GroupScope     Global `
        -GroupCategory  Security `
        -Description    "Migrated from Shared Mailbox: $Identity" `
        -Path           $TargetOU

    Write-Host "[OK] Security Group '$groupName' created in: $TargetOU" -ForegroundColor Green
}

Write-Host "`n[DONE] Conversion complete for: $Identity" -ForegroundColor Cyan
