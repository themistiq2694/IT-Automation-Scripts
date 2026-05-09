# Runbook: OneDrive for Business Migration

**Project:** File Server / Local Storage → OneDrive for Business  
**Scope:** ~200 users  
**Outcome:** Successful migration with user adoption training  
**Author:** Mihail-Petre Dragutoiu

---

## Overview

Migration of user data from on-premises file shares and local storage to OneDrive for Business, using Known Folder Move (KFM) to silently redirect Desktop, Documents, and Pictures folders, supplemented by targeted user adoption sessions.

---

## Pre-Migration Checklist

- [ ] Microsoft 365 licenses confirmed for all users (OneDrive included)
- [ ] Storage size report generated (`Pre-Migration-SizeReport.ps1`)
- [ ] Users with >50 GB identified for separate handling
- [ ] KFM policy tested on pilot group (5–10 users)
- [ ] SharePoint Online storage quota verified per user
- [ ] Change window and communication plan approved

---

## Migration Approach

### Phase 1 – Pilot (Week 1)
- Select 10 representative users across departments
- Deploy KFM policy (`Trigger-KFM-Policy.ps1`)
- Monitor sync status for 48 hours (`Validate-OneDriveSync.ps1`)
- Gather feedback before broad rollout

### Phase 2 – Batch Rollout (Weeks 2–4)
- Deploy KFM via Intune Configuration Profile or Group Policy
- Batch by department (50 users/week recommended)
- Validate each batch before proceeding to next

### Phase 3 – Validation & Adoption (Week 4–5)
- Run `Validate-OneDriveSync.ps1` on all migrated machines
- Conduct user training sessions (sharing, co-authoring, version history)
- Provide quick reference guide

---

## KFM Deployment Options

### Option A – Via Script (Intune Remediation)
```powershell
.\Trigger-KFM-Policy.ps1 -TenantId "your-tenant-id"
```

### Option B – Via Intune Configuration Profile
1. Navigate to: `Devices > Configuration > Create > Windows 10 and later`
2. Profile type: `Settings Catalog`
3. Search: `OneDrive` → Enable **Silently move known folders to OneDrive**
4. Enter Tenant ID

### Option C – Via Group Policy (Hybrid environments)
- GPO Path: `Computer Configuration > Administrative Templates > OneDrive`
- Setting: **Silently move Windows known folders to OneDrive**

---

## Post-Migration Validation

Run on each migrated device (or deploy as Intune detection script):

```powershell
.\Validate-OneDriveSync.ps1
```

Expected results:
- OneDrive process: **Running**
- Business account: **Linked**
- Desktop, Documents, Pictures: **Redirected to OneDrive path**
- KFM last error: **No errors**

---

## User Training Topics

| Topic | Key Points |
|---|---|
| Accessing files | OneDrive in File Explorer, web at office.com |
| Sharing | Right-click > Share, link permissions |
| Sync status icons | Green checkmark = synced, Blue arrows = syncing |
| Version history | Right-click > Version History |
| Offline access | Right-click > Always keep on this device |

---

## Common Issues & Fixes

| Issue | Fix |
|---|---|
| OneDrive not starting | Run: `%LOCALAPPDATA%\Microsoft\OneDrive\OneDrive.exe` |
| KFM not applying | Verify TenantID in registry; check Intune policy sync |
| Files stuck syncing | Check file name for special characters or path >260 chars |
| Account not linked | Sign out and back in to OneDrive with M365 account |
