# Runbook: Domain Migration – Subdomain to Parent Domain

**Project:** `europe.temenosgroup.com` → `temenosgroup.com`  
**Scope:** 200+ users  
**Outcome:** Zero data loss, zero unplanned outages  
**Author:** Mihail-Petre Dragutoiu

---

## Overview

Migration of all user accounts from a regional subdomain (`europe.temenosgroup.com`) to the corporate parent domain (`temenosgroup.com`), including UPN changes, proxy address updates, and email routing reconfiguration in Exchange Hybrid.

---

## Pre-Migration Checklist

- [ ] New UPN suffix (`temenosgroup.com`) added to Azure AD / Entra ID custom domains
- [ ] New suffix verified (DNS TXT record confirmed)
- [ ] Exchange Online hybrid connector updated for new domain
- [ ] MX and Autodiscover DNS records updated
- [ ] Pre-migration snapshot captured (`Export-PreMigration-Snapshot.ps1`)
- [ ] Rollback plan documented
- [ ] Change window approved (low-traffic hours, weekend recommended)
- [ ] Stakeholders notified (IT, HR, business leads)

---

## Migration Steps

### Step 1 – Export Baseline Snapshot
```powershell
.\Export-PreMigration-Snapshot.ps1 -OldSuffix "europe.temenosgroup.com"
```
Save the output CSV in a safe location. This is your rollback reference.

---

### Step 2 – Dry Run (WhatIf)
```powershell
.\Migrate-UPNSuffix.ps1 `
    -OldSuffix "europe.temenosgroup.com" `
    -NewSuffix "temenosgroup.com" `
    -WhatIf
```
Review the WhatIf log. Confirm the user list and expected UPN changes are correct.

---

### Step 3 – Execute Migration (Phased)
Run in batches (e.g. 50 users at a time) to allow validation between groups.

```powershell
.\Migrate-UPNSuffix.ps1 `
    -OldSuffix "europe.temenosgroup.com" `
    -NewSuffix "temenosgroup.com"
```

Monitor for FAILED entries in the log CSV after each batch.

---

### Step 4 – Post-Migration Validation
```powershell
.\Validate-PostMigration.ps1 `
    -SnapshotCsv "C:\Reports\DomainMigration\PreMigration_Snapshot.csv" `
    -NewSuffix "temenosgroup.com"
```

All users should show `OK – Migrated`. Investigate any exceptions immediately.

---

### Step 5 – Exchange / Mail Flow Verification
- Send test emails from new UPN addresses (internal + external)
- Verify Autodiscover resolves correctly for new suffix
- Confirm Outlook re-prompts and accepts new credentials (or SSO flows seamlessly)
- Check shared mailbox and distribution list memberships

---

### Step 6 – User Communication
Send post-migration notice:
- New login: `firstname.lastname@temenosgroup.com`
- Old address still receives mail (proxy address retained) for transition period
- Outlook may prompt to re-enter credentials – use new UPN

---

## Rollback Procedure

If critical failures occur during migration:

1. Open `UPNMigration_Rollback_<timestamp>.csv` (generated automatically)
2. Use the `UPN_Before` values to reverse changes:

```powershell
Import-Csv "C:\Reports\DomainMigration\UPNMigration_Rollback.csv" | ForEach-Object {
    Set-ADUser -Identity $_.SamAccountName -UserPrincipalName $_.OldUPN
}
```

---

## Notes & Lessons Learned

- Always verify the new suffix is confirmed in Entra ID **before** running the migration
- Keep the old suffix as a proxy address for 30–60 days to avoid mail loss
- Batch processing significantly reduces blast radius in case of errors
- Coordinate with Exchange team for hybrid mail flow changes — UPN and SMTP are separate
