# New-UserOnboarding.ps1
# Description : Full end-to-end onboarding automation for a new employee.
#               Creates AD account, assigns groups, provisions M365 license,
#               creates shared mailbox access, and generates a welcome summary.
# Author      : Mihail-Petre Dragutoiu
# Context     : Used to standardise and accelerate user provisioning in the Company I used to work for (~270 users)
# Requires    : ActiveDirectory module, MSOnline, ExchangeOnlineManagement
# Usage       : .\New-UserOnboarding.ps1 -CsvPath "C:\Onboarding\new_hires.csv"
#
# CSV columns required:
#   FirstName, LastName, Department, JobTitle, Manager, OfficeLocation,
#   LicenseSku, BaseGroupTemplate, SharedMailboxAccess (optional, comma-separated)

param(
    [Parameter(Mandatory)]
    [string]$CsvPath,

    [string]$DefaultOU      = "OU=Users,OU=CORP,DC=domain_name,DC=com",
    [string]$DefaultDomain  = "domain_name.com",
    [string]$TempPassword   = "Welcome@2025!",   # Force change on first login
    [string]$OutputPath     = "C:\Reports\Onboarding"
)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath | Out-Null }
if (-not (Test-Path $CsvPath))    { Write-Error "CSV not found: $CsvPath"; exit 1 }

# -- Connect to cloud services --
try { Get-MsolDomain -EA Stop | Out-Null } catch { Connect-MsolService }
try { Get-OrganizationConfig -EA Stop | Out-Null } catch { Connect-ExchangeOnline }

$timestamp = Get-Date -Format 'yyyyMMdd_HHmm'
$logFile   = Join-Path $OutputPath "Onboarding_Log_$timestamp.csv"
$newHires  = Import-Csv -Path $CsvPath
$results   = @()

foreach ($hire in $newHires) {

    $firstName  = $hire.FirstName.Trim()
    $lastName   = $hire.LastName.Trim()
    $displayName = "$firstName $lastName"
    $samAccount  = ($firstName.Substring(0,1) + $lastName).ToLower() -replace '[^a-z0-9]',''
    $upn         = "$samAccount@$DefaultDomain"
    $steps       = @()

    Write-Host "`n[ONBOARDING] $displayName ($upn)" -ForegroundColor Cyan

    # ── Step 1: Create AD User ──────────────────────────────────────────────
    try {
        $managerDN = (Get-ADUser -Filter { DisplayName -eq $hire.Manager } -EA Stop).DistinguishedName

        $adParams = @{
            GivenName             = $firstName
            Surname               = $lastName
            Name                  = $displayName
            DisplayName           = $displayName
            SamAccountName        = $samAccount
            UserPrincipalName     = $upn
            Department            = $hire.Department
            Title                 = $hire.JobTitle
            Office                = $hire.OfficeLocation
            Manager               = $managerDN
            Path                  = $DefaultOU
            AccountPassword       = (ConvertTo-SecureString $TempPassword -AsPlainText -Force)
            ChangePasswordAtLogon = $true
            Enabled               = $true
        }

        New-ADUser @adParams -ErrorAction Stop
        $steps += "AD Account: Created"
        Write-Host "  [OK] AD account created" -ForegroundColor Green

    } catch {
        $steps += "AD Account: FAILED – $($_.Exception.Message)"
        Write-Warning "  [FAIL] AD account – $($_.Exception.Message)"
    }

    # ── Step 2: Add to Department/Base Groups ───────────────────────────────
    if ($hire.BaseGroupTemplate) {
        $groups = $hire.BaseGroupTemplate -split ","
        foreach ($group in $groups) {
            $group = $group.Trim()
            try {
                Add-ADGroupMember -Identity $group -Members $samAccount -ErrorAction Stop
                $steps += "Group '$group': Added"
                Write-Host "  [OK] Added to group: $group" -ForegroundColor Green
            } catch {
                $steps += "Group '$group': FAILED – $($_.Exception.Message)"
                Write-Warning "  [FAIL] Group '$group' – $($_.Exception.Message)"
            }
        }
    }

    # ── Step 3: Assign M365 License ─────────────────────────────────────────
    if ($hire.LicenseSku) {
        try {
            # Allow time for AAD sync (in live env, consider a Wait-ADSync call)
            Start-Sleep -Seconds 10
            Set-MsolUser -UserPrincipalName $upn -UsageLocation "RO" -ErrorAction Stop
            $license = New-MsolLicenseOptions -AccountSkuId $hire.LicenseSku
            Set-MsolUserLicense -UserPrincipalName $upn -AddLicenses $hire.LicenseSku -ErrorAction Stop
            $steps += "License '$($hire.LicenseSku)': Assigned"
            Write-Host "  [OK] License assigned: $($hire.LicenseSku)" -ForegroundColor Green
        } catch {
            $steps += "License: FAILED – $($_.Exception.Message)"
            Write-Warning "  [FAIL] License – $($_.Exception.Message)"
        }
    }

    # ── Step 4: Shared Mailbox Access ───────────────────────────────────────
    if ($hire.SharedMailboxAccess) {
        $mailboxes = $hire.SharedMailboxAccess -split ","
        foreach ($mbx in $mailboxes) {
            $mbx = $mbx.Trim()
            try {
                Add-MailboxPermission -Identity $mbx -User $upn `
                    -AccessRights FullAccess -AutoMapping $true -ErrorAction Stop
                Add-RecipientPermission -Identity $mbx -Trustee $upn `
                    -AccessRights SendAs -Confirm:$false -ErrorAction Stop
                $steps += "Shared Mailbox '$mbx': FullAccess + SendAs granted"
                Write-Host "  [OK] Shared mailbox access granted: $mbx" -ForegroundColor Green
            } catch {
                $steps += "Shared Mailbox '$mbx': FAILED – $($_.Exception.Message)"
                Write-Warning "  [FAIL] Mailbox '$mbx' – $($_.Exception.Message)"
            }
        }
    }

    # ── Step 5: Enable MFA ──────────────────────────────────────────────────
    try {
        $mfaReq = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
        $mfaReq.RelyingParty = "*"
        $mfaReq.State        = "Enabled"
        Set-MsolUser -UserPrincipalName $upn -StrongAuthenticationRequirements @($mfaReq) -ErrorAction Stop
        $steps += "MFA: Enabled"
        Write-Host "  [OK] MFA enabled" -ForegroundColor Green
    } catch {
        $steps += "MFA: FAILED – $($_.Exception.Message)"
        Write-Warning "  [FAIL] MFA – $($_.Exception.Message)"
    }

    # ── Log row ─────────────────────────────────────────────────────────────
    $results += [PSCustomObject]@{
        DisplayName       = $displayName
        SamAccountName    = $samAccount
        UserPrincipalName = $upn
        Department        = $hire.Department
        Manager           = $hire.Manager
        Steps             = $steps -join " | "
        Timestamp         = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    }
}

$results | Export-Csv -Path $logFile -NoTypeInformation -Encoding UTF8
Write-Host "`n[DONE] Onboarding log: $logFile" -ForegroundColor Cyan
