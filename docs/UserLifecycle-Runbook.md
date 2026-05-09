# Runbook: User Lifecycle Management – Onboarding & Offboarding

**Author:** Mihail-Petre Dragutoiu  
**Scope:** All employee joiners, leavers, and internal transfers  
**Environment:** Active Directory + Microsoft 365 + Exchange Online (Hybrid)

---

## Overview

Standardised, audited procedures for the full user lifecycle: onboarding new hires, offboarding leavers, and handling internal role changes. Scripts automate ~90% of manual steps, reducing provisioning time and eliminating access errors.

---

## ONBOARDING

### Required Information (from HR)
- Full name, department, job title
- Start date, office location
- Reporting manager
- Required system access / groups
- Shared mailboxes needed

### Onboarding Script
```powershell
.\New-UserOnboarding.ps1 -CsvPath "C:\Onboarding\new_hires.csv"
```

See `templates/onboarding_template.csv` for the required CSV format.

### What the Script Does
1. Creates AD user account with standardised naming (`f.lastname@domain_name.com`)
2. Sets attributes: title, department, manager, office
3. Adds to department and role-based security groups
4. Assigns M365 license (usage location: RO)
5. Grants shared mailbox access (FullAccess + SendAs)
6. Enables MFA (state: Enabled – user must register on first login)

### Post-Script Manual Steps
- [ ] Send welcome email with initial credentials (temporary password)
- [ ] Confirm user registers MFA at https://aka.ms/mfasetup
- [ ] Provision any application-specific access (non-AD systems)
- [ ] Assign hardware (laptop, phone) and log asset in ITSM
- [ ] Update org chart / directory if applicable

### Naming Convention
| Field | Format | Example |
|---|---|---|
| SamAccountName | `firstinitiallastname` | `jdoe` |
| UPN | `f.lastname@domain_name.com` | `j.doe@domain_name.com` |
| Display Name | `First Last` | `John Doe` |

---

## OFFBOARDING

### Trigger Points
- Resignation accepted (last day confirmed)
- Immediate termination (same-day execution)
- End of contractor contract

### Offboarding Script
```powershell
# Standard offboarding with manager mailbox access
.\Remove-UserOffboarding.ps1 `
    -UserPrincipalName "john.doe@domain_name.com" `
    -ManagerUPN "jane.smith@domain_name.com"

# Dry run first for verification
.\Remove-UserOffboarding.ps1 `
    -UserPrincipalName "john.doe@domain_name.com" `
    -WhatIf
```

### What the Script Does
1. Disables the AD account immediately
2. Resets password to random (prevents re-enable bypass)
3. Revokes all active Microsoft 365 / Azure AD sessions
4. Blocks M365 sign-in
5. Clears MFA requirements
6. Captures full group membership snapshot (audit trail)
7. Removes from all AD security groups
8. Removes M365 licenses
9. Converts mailbox to Shared (preserves email history)
10. Grants manager full access to shared mailbox
11. Moves AD account to `OU=Disabled` container
12. Updates AD description with offboarding date and previous role

### Post-Script Manual Steps
- [ ] Collect hardware (laptop, access card, phone)
- [ ] Remove from any non-AD systems (HR platform, 3rd party SaaS)
- [ ] Disable VPN certificate / token if separate system
- [ ] Update asset register
- [ ] Notify relevant business stakeholders
- [ ] Set email auto-reply if required (business decision)
- [ ] Schedule mailbox deletion after retention period (typically 30–90 days)

### Mailbox Retention Policy
After offboarding, the shared mailbox is retained for **90 days** by default.  
After 90 days, request deletion via ITSM ticket to the Exchange/M365 team.

---

## ROLE CHANGES / INTERNAL TRANSFERS

### Role Change Script
```powershell
.\Update-UserRoleChange.ps1 `
    -UserPrincipalName "john.doe@domain_name.com" `
    -NewTitle "Senior Analyst" `
    -NewDepartment "Finance" `
    -NewManager "dan.ionescu@domain_name.com" `
    -GroupsToAdd "Finance-Team,Finance-SharePoint" `
    -GroupsToRemove "IT-Support,IT-SharePoint" `
    -SharedMailboxToAdd "finance@domain_name.com" `
    -SharedMailboxToRemove "it-support@domain_name.com"
```

### What the Script Does
1. Updates AD attributes (title, department, office, manager)
2. Adds user to new department/role groups
3. Removes user from old department/role groups
4. Grants access to new shared mailboxes (FullAccess + SendAs)
5. Revokes access from old shared mailboxes
6. Logs all changes with before/after state for audit

---

## Audit & Compliance

All scripts generate timestamped CSV logs saved to:
- Onboarding: `C:\Reports\Onboarding\`
- Offboarding: `C:\Reports\Offboarding\`
- Role Changes: `C:\Reports\RoleChanges\`

Logs capture: action taken, success/failure status, before/after values, and timestamps.  
These logs should be archived to a secure network share or SharePoint library for compliance.

---

## Key Contacts

| Role | Responsibility |
|---|---|
| IT Support | Script execution, AD/M365 provisioning |
| HR | Trigger onboarding/offboarding, provide user data |
| Manager | Confirm access requirements, receive mailbox access on offboarding |
| IT Security | Review offboarding audit logs, escalate anomalies |
