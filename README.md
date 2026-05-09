# IT Automation Scripts – PowerShell Portfolio

**Author:** Mihail-Petre Dragutoiu  
**Role:** Senior IT Support Technician | Microsoft & Cloud Platforms  
**Environment:** Windows 11, Microsoft 365, Azure AD (Entra ID), Exchange Online/2016, Autopilot

---

## Overview

This repository contains PowerShell scripts developed and used during 10+ years of enterprise IT support at "Company Name"*, covering ~270 users in a hybrid Windows/cloud environment. Scripts are organized by domain and reflect real-world operational scenarios, including migrations, identity management, and endpoint automation.

---

## Repository Structure

```
IT-Automation-Scripts/
│
├── AD-Group-Management/
│   ├── Export-ADGroups.ps1                  # Export all AD groups to CSV
│   ├── Get-NestedGroupMembers.ps1           # List members recursively
│   └── Bulk-AddRemove-GroupMembers.ps1      # Bulk add/remove from CSV
│
├── Exchange-Online/
│   ├── Convert-SharedMailboxToSecurity.ps1  # Mailbox type conversion
│   └── Get-MailboxAccessAudit.ps1           # Full access / Send As / Send on Behalf audit
│
├── Domain-Migration/
│   ├── Export-PreMigration-Snapshot.ps1     # Pre-migration AD/UPN audit
│   ├── Migrate-UPNSuffix.ps1                # Bulk UPN change subdomain → parent domain
│   └── Validate-PostMigration.ps1           # Post-migration validation report
│
├── OneDrive-Migration/
│   ├── Pre-Migration-SizeReport.ps1         # User storage size report before migration
│   ├── Trigger-KFM-Policy.ps1              # Known Folder Move via registry/policy
│   └── Validate-OneDriveSync.ps1           # Post-migration sync status check
│
├── Windows11-Autopilot/
│   ├── Get-AutopilotHardwareHash.ps1        # Collect and upload hardware hash
│   ├── Validate-AutopilotEnrollment.ps1     # Confirm device registered in Intune/Autopilot
│   └── Post-Wipe-Checklist.ps1             # Pre-wipe checklist + Autopilot trigger
│
├── MFA/
│   ├── Get-MFAStatusReport.ps1              # Full tenant MFA compliance report
│   ├── Enable-MFAForUsers.ps1               # Bulk enable/enforce MFA from CSV
│   └── Get-MFANonCompliant.ps1             # Find unregistered users + optional email reminder
│
├── User-Lifecycle/
│   ├── New-UserOnboarding.ps1               # End-to-end new hire provisioning
│   ├── Remove-UserOffboarding.ps1           # Secure leaver offboarding (disable, revoke, convert mailbox)
│   ├── Update-UserRoleChange.ps1            # Internal transfer/role change handler
│   └── templates/
│       └── onboarding_template.csv          # CSV template for bulk onboarding
│
└── docs/
    ├── Domain-Migration-Runbook.md
    ├── OneDrive-Migration-Runbook.md
    ├── Windows11-Autopilot-Runbook.md
    ├── MFA-Rollout-Runbook.md
    └── UserLifecycle-Runbook.md
```

---

## Key Projects

| Project | Year | Scope | Outcome |
|---|---|---|---|
| Domain Migration (`europe.domain_name.com`** → `domain_name.com`***) | 2023 | 200+ users | Zero data loss, zero downtime |
| OneDrive Migration (File Server → OneDrive for Business) | 2021 | ~200 users | Smooth rollout with adoption training |
| Windows 11 + Autopilot Migration | 2025 | 270+ devices | Zero critical incidents, Entra-only management |
| MFA Rollout | 2018 | Org-wide | Full compliance achieved, zero compromises |
| User Onboarding / Offboarding Automation | 2015–2026 | ~270 users | Reduced provisioning time, consistent audited lifecycle |

---

## Requirements

- PowerShell 5.1 or PowerShell 7+
- RSAT: Active Directory module (`Import-Module ActiveDirectory`)
- Exchange Online Management Shell (`Connect-ExchangeOnline`)
- MSOnline module (`Connect-MsolService`) — for MFA scripts
- SharePoint Online Management Shell (`Connect-SPOService`) — for OneDrive scripts
- Microsoft Graph PowerShell SDK — for Intune/Autopilot scripts
- Appropriate admin permissions per script (Global Admin or delegated roles)

---

* Company name is irrelevant for this repo's purpose.

** DomainName is irrelevant for this repo's purpose.

*** DomainName is irrelevant for this repo's purpose.

## Disclaimer

Scripts are sanitized and anonymized for portfolio purposes. Domain names, OUs, and tenant IDs are placeholders. Always test in a non-production environment before running at scale.
