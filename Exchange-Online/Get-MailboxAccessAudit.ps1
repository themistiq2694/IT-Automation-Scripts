# Get-MailboxAccessAudit.ps1
# Description : Audits all permission types on a Shared Mailbox:
#               Full Access, Send As, Send on Behalf.
#               Useful for offboarding, compliance, and access reviews.
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Get-MailboxAccessAudit.ps1 -SharedMailbox "teambox@domain.com"

param(
    [Parameter(Mandatory)]
    [string]$SharedMailbox,

    [string]$OutputPath = "C:\Reports"
)

# -- Connect to Exchange Online if needed --
try {
    Get-OrganizationConfig -ErrorAction Stop | Out-Null
} catch {
    Write-Host "[INFO] Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ErrorAction Stop
}

$timestamp  = Get-Date -Format 'yyyyMMdd_HHmm'
$outputFile = Join-Path $OutputPath "MailboxAudit_$(($SharedMailbox -split '@')[0])_$timestamp.csv"
$results    = @()

Write-Host "`n[INFO] Auditing mailbox: $SharedMailbox" -ForegroundColor Cyan

# -- Full Access --
Write-Host "`n  [Full Access]" -ForegroundColor Yellow
$fullAccess = Get-MailboxPermission -Identity $SharedMailbox |
    Where-Object { $_.IsInherited -eq $false -and $_.User -notlike "NT AUTHORITY*" }

foreach ($perm in $fullAccess) {
    Write-Host "    $($perm.User) – $($perm.AccessRights)"
    $results += [PSCustomObject]@{
        Mailbox     = $SharedMailbox
        PermType    = "FullAccess"
        Trustee     = $perm.User
        Rights      = ($perm.AccessRights -join ", ")
    }
}

# -- Send As --
Write-Host "`n  [Send As]" -ForegroundColor Yellow
$sendAs = Get-RecipientPermission -Identity $SharedMailbox |
    Where-Object { $_.Trustee -notlike "NT AUTHORITY*" }

foreach ($perm in $sendAs) {
    Write-Host "    $($perm.Trustee)"
    $results += [PSCustomObject]@{
        Mailbox     = $SharedMailbox
        PermType    = "SendAs"
        Trustee     = $perm.Trustee
        Rights      = "SendAs"
    }
}

# -- Send on Behalf --
Write-Host "`n  [Send on Behalf]" -ForegroundColor Yellow
$sob = (Get-Mailbox -Identity $SharedMailbox).GrantSendOnBehalfTo
foreach ($delegate in $sob) {
    Write-Host "    $delegate"
    $results += [PSCustomObject]@{
        Mailbox     = $SharedMailbox
        PermType    = "SendOnBehalf"
        Trustee     = $delegate
        Rights      = "SendOnBehalf"
    }
}

# -- Export --
if ($results.Count -gt 0) {
    $results | Export-Csv -Path $outputFile -NoTypeInformation -Encoding UTF8
    Write-Host "`n[OK] Audit exported to: $outputFile" -ForegroundColor Green
} else {
    Write-Warning "No explicit permissions found on mailbox: $SharedMailbox"
}
