# Runbook: Organisation-Wide MFA Rollout

**Project:** Multi-Factor Authentication – Full Organisation Enforcement  
**Scope:** All licensed users (~270)  
**Outcome:** Full compliance achieved, zero account compromises post-rollout  
**Author:** Mihail-Petre Dragutoiu

---

## Overview

Phased rollout of MFA across the entire organisation, including pre-rollout testing, user communication, pilot group, and full enforcement. Scripts automate status tracking, bulk enablement, and non-compliant user identification with reminder capability.

---

## Pre-Rollout Checklist

- [ ] Conditional Access policies reviewed (or per-user MFA approach confirmed)
- [ ] Trusted IP ranges configured (office networks, VPN) in Azure AD
- [ ] MFA registration portal tested: https://aka.ms/mfasetup
- [ ] Microsoft Authenticator app tested on iOS and Android
- [ ] Helpdesk team briefed on MFA reset procedures
- [ ] Communication plan approved by management

---

## Phased Rollout Plan

| Phase | Group | MFA State | Timeline |
|---|---|---|---|
| 0 – Pilot | IT Team (5–10 users) | Enforced | Week 1 |
| 1 – Admins | All admin accounts | Enforced | Week 1–2 |
| 2 – Dept A | First department | Enabled | Week 2–3 |
| 3 – Remaining | All remaining users | Enabled | Week 3–4 |
| 4 – Enforce All | Everyone | Enforced | Week 6+ |

**Enabled** = User can bypass MFA if not registered (grace period)  
**Enforced** = MFA required on every login, no bypass possible

---

## Step-by-Step

### Step 1 – Baseline Report
```powershell
.\Get-MFAStatusReport.ps1
```
Review how many users are already enabled/enforced vs not enabled. Save as baseline.

### Step 2 – Pilot Enablement
Create `pilot_users.csv` with IT team UPNs, then:
```powershell
.\Enable-MFAForUsers.ps1 -CsvPath "C:\MFA\pilot_users.csv" -Enforce
```
Ask pilot users to register at https://aka.ms/mfasetup and test login.

### Step 3 – Phased Bulk Enablement
```powershell
# Dry run first
.\Enable-MFAForUsers.ps1 -CsvPath "C:\MFA\phase2_users.csv" -WhatIf

# Then apply
.\Enable-MFAForUsers.ps1 -CsvPath "C:\MFA\phase2_users.csv"
```

### Step 4 – Track Non-Compliant Users
```powershell
# Report only
.\Get-MFANonCompliant.ps1

# Report + send reminder emails
.\Get-MFANonCompliant.ps1 -SendReminder -SenderAddress "it-support@temenosgroup.com"
```

### Step 5 – Final Enforcement
After registration deadline:
```powershell
.\Enable-MFAForUsers.ps1 -CsvPath "C:\MFA\all_users.csv" -Enforce
```

### Step 6 – Post-Rollout Compliance Report
```powershell
.\Get-MFAStatusReport.ps1
```
All users should show `Enforced`. Share summary with management.

---

## User Communication Templates

### Initial Announcement Email
```
Subject: Action Required – Multi-Factor Authentication Coming Soon

Dear [Name],

We are implementing Multi-Factor Authentication (MFA) to protect your account.

On [DATE], you will need MFA to sign in to your Microsoft 365 account.

Please take 5 minutes NOW to register:
1. Go to https://aka.ms/mfasetup
2. Sign in with your corporate account
3. Register the Microsoft Authenticator app (recommended)

Questions? Contact IT Support at it-support@temenosgroup.com

IT Support Team
```

### Reminder Email (sent via script)
Used automatically by `Get-MFANonCompliant.ps1 -SendReminder`

---

## MFA Reset Procedure (Helpdesk)

If a user loses access to their MFA method (new phone, lost device):

**Via MSOnline (PowerShell):**
```powershell
# Clear registered MFA methods (forces re-registration on next login)
Set-MsolUser -UserPrincipalName "user@temenosgroup.com" `
    -StrongAuthenticationMethods @()
```

**Via Azure Portal:**
`Azure AD > Users > [User] > Authentication Methods > Require re-register MFA`

---

## Common Issues

| Issue | Fix |
|---|---|
| User locked out after MFA enabled | Reset methods via PowerShell or portal |
| Authenticator app not receiving push | Check phone internet/notification settings; use OTP code instead |
| MFA prompt not appearing | Clear browser cache; check Conditional Access trusted IPs |
| Admin account locked out | Use break-glass account; reset via another Global Admin |
