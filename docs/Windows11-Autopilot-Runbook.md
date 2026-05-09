# Runbook: Windows 10 → Windows 11 Migration via Autopilot

**Project:** Windows 11 + Autopilot Device Refresh  
**Scope:** 270+ devices  
**Management:** Entra ID-only (no on-prem domain join)  
**Outcome:** Zero critical incidents, phased rollout completed  
**Author:** Mihail-Petre Dragutoiu

---

## Overview

Phased device upgrade from Windows 10 to Windows 11 using Windows Autopilot self-deploying or user-driven mode. Devices were enrolled in Autopilot **before** OS wipe, ensuring automatic re-provisioning post-reset with Entra-only management (no domain join required).

---

## Why Full Reinstall (Not In-Place Upgrade)?

In-place upgrade was evaluated but rejected due to:
- Legacy software remnants and configuration drift accumulated over years
- Requirement for clean Entra-only join (removing legacy domain join)
- Opportunity to enforce standardized Intune baseline from scratch
- Hardware compatibility requirements for Windows 11 (TPM 2.0, Secure Boot)

---

## Prerequisites

### Device Requirements (Windows 11 Hardware)
- TPM 2.0 enabled (verify in BIOS/UEFI)
- Secure Boot enabled
- 64GB+ storage, 4GB+ RAM
- UEFI firmware (not legacy BIOS)
- CPU on Microsoft's supported list

### Environment Requirements
- [ ] Intune / Entra ID configured for Autopilot
- [ ] Autopilot deployment profile created (User-Driven or Self-Deploying)
- [ ] Entra ID group for Autopilot devices created
- [ ] Required apps and policies assigned to Autopilot group in Intune
- [ ] Windows 11 ESP (Enrollment Status Page) configured
- [ ] OneDrive KFM active on all devices before migration

---

## Migration Workflow (Per Device)

```
[1] Verify Windows 11 hardware compatibility
        ↓
[2] Confirm OneDrive sync complete (all data safe)
        ↓
[3] Collect & upload Autopilot hardware hash
        ↓
[4] Validate Autopilot enrollment in Intune portal
        ↓
[5] Run Pre-Wipe Checklist (interactive confirmation)
        ↓
[6] Perform factory reset (Settings > Recovery > Reset this PC)
        ↓
[7] Device boots into OOBE → Autopilot kicks in automatically
        ↓
[8] User signs in with Entra ID credentials
        ↓
[9] Intune deploys apps, policies, and configurations
        ↓
[10] Post-enrollment validation
```

---

## Step-by-Step

### Step 1 – Hardware Compatibility Check
Run on device:
```powershell
# Quick check via PC Health Check tool or:
$tpm = Get-WmiObject -Namespace "Root\CIMv2\Security\MicrosoftTpm" -Class Win32_Tpm
Write-Host "TPM Present: $($tpm.IsPresent())"
Write-Host "TPM Enabled: $($tpm.IsEnabled())"
Write-Host "TPM Version: $($tpm.SpecVersion)"

$secureBoot = Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
Write-Host "Secure Boot: $secureBoot"
```

### Step 2 – Verify OneDrive & Data Safety
- Confirm OneDrive sync icon is green
- Run `.\Validate-OneDriveSync.ps1` and confirm all checks pass
- Verify KFM is active (Desktop/Documents/Pictures → OneDrive)

### Step 3 – Collect Hardware Hash
```powershell
.\Get-AutopilotHardwareHash.ps1 -TenantId "your-tenant-id"
```
Or upload CSV manually in Intune: `Devices > Windows > Windows Enrollment > Devices > Import`

### Step 4 – Validate Enrollment
```powershell
.\Validate-AutopilotEnrollment.ps1
```
All checks must show **OK** before proceeding.

Also verify in Intune Portal:
`Devices > Windows > Windows Enrollment > Devices` → Serial number must appear

### Step 5 – Run Pre-Wipe Checklist
```powershell
.\Post-Wipe-Checklist.ps1
```
All checklist items must be confirmed by the technician. Log is saved automatically.

### Step 6 – Initiate Reset
Via Settings (user-friendly):
`Settings > System > Recovery > Reset this PC > Remove everything`

Via MDM/Intune (remote):
`Intune > Devices > [Device] > Wipe`

### Step 7 – Autopilot Provisioning (Automatic)
After reset, the device:
1. Connects to network (Ethernet recommended for reliability)
2. Detects Autopilot profile via hardware hash
3. Applies organization branding on OOBE screen
4. User signs in with Entra ID (`firstname.lastname@temenosgroup.com`)
5. Enrollment Status Page shows app/policy deployment progress

### Step 8 – Post-Enrollment Validation
- Confirm device shows in Intune as **Compliant**
- Verify apps deployed (check Intune app status)
- Confirm Entra ID join: `dsregcmd /status` → `AzureAdJoined: YES`
- Confirm OneDrive signs in automatically and syncs user data

---

## Phased Rollout Plan

| Phase | Group | Timeline | Notes |
|---|---|---|---|
| Pilot | IT team (5 devices) | Week 1 | Full process validation |
| Phase 1 | Dept A (50 devices) | Week 2–3 | Refine ESP timing |
| Phase 2 | Dept B–C (100 devices) | Week 4–5 | Batch by floor/location |
| Phase 3 | Remaining (115 devices) | Week 6–8 | Accelerated if smooth |

---

## Common Issues & Fixes

| Issue | Cause | Fix |
|---|---|---|
| Device not picking up Autopilot profile | Hash not uploaded / not synced | Wait 15 min after import; verify in Intune portal |
| ESP stuck at app installation | App dependency issue | Check Intune app deployment status; fix assignment |
| Entra join fails | Network/proxy issue | Use Ethernet; check proxy exceptions for MS endpoints |
| User can't sign in at OOBE | UPN not matching Entra account | Verify UPN migration completed before device wipe |
| OneDrive not signing in automatically | SSO not configured | Check Intune OneDrive config profile (silent sign-in setting) |

---

## Notes & Lessons Learned

- **Always register Autopilot BEFORE wiping** — without the hash in Intune, the device won't self-provision
- Ethernet > Wi-Fi during OOBE for Autopilot to avoid profile detection failures
- Coordinate UPN migration (domain migration) before device refresh — Entra login must match
- ESP timeout settings need tuning for larger app packages; increase to 60–90 min
- Communicate the "reset screen" to users in advance — it can be alarming without context
