# Validate-AutopilotEnrollment.ps1
# Description : Confirms that a device is registered in Windows Autopilot / Intune
#               BEFORE performing the OS wipe. Prevents wiping devices that are not yet enrolled.
# Author      : Mihail-Petre Dragutoiu
# Context     : Gate check before Windows 10 → Windows 11 wipe (270+ devices)
# Usage       : .\Validate-AutopilotEnrollment.ps1 -DeviceSerial "XXXXX" OR run on the device itself.

param(
    [string]$DeviceSerial = (Get-WmiObject Win32_BIOS).SerialNumber
)

Write-Host "`n=== Autopilot Enrollment Validation ===" -ForegroundColor Cyan
Write-Host "Device Serial: $DeviceSerial" -ForegroundColor Gray

$checks = @()

# -- Check 1: Autopilot registry keys --
$apKey  = "HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotPolicy"
$apPresent = Test-Path $apKey
$checks += [PSCustomObject]@{
    Check  = "Autopilot Policy Registry Key"
    Result = if ($apPresent) { "OK – Key found" } else { "MISSING – Device may not be enrolled" }
}

# -- Check 2: Azure AD / Entra join status --
$dsregOutput = dsregcmd /status 2>&1
$aadJoined   = $dsregOutput | Where-Object { $_ -match "AzureAdJoined\s*:\s*YES" }
$checks += [PSCustomObject]@{
    Check  = "Azure AD (Entra) Joined"
    Result = if ($aadJoined) { "OK – Device is Entra joined" } else { "NOT JOINED" }
}

# -- Check 3: Intune MDM enrolled --
$mdmEnrolled = $dsregOutput | Where-Object { $_ -match "MDMEnrolled\s*:\s*YES" }
$checks += [PSCustomObject]@{
    Check  = "Intune MDM Enrolled"
    Result = if ($mdmEnrolled) { "OK – Enrolled" } else { "NOT ENROLLED" }
}

# -- Check 4: Autopilot enrollment profile assigned (via MDM registry) --
$mdmKey   = "HKLM:\SOFTWARE\Microsoft\Enrollments"
$enrolled = (Get-ChildItem $mdmKey -ErrorAction SilentlyContinue) | Where-Object {
    (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).EnrollmentType -eq 6
}
$checks += [PSCustomObject]@{
    Check  = "MDM Enrollment Record (Type 6 – Autopilot)"
    Result = if ($enrolled) { "OK – Profile record found" } else { "NOT FOUND – verify Autopilot assignment" }
}

# -- Display --
$checks | Format-Table Check, Result -AutoSize -Wrap

$issues = $checks | Where-Object { $_.Result -notlike "OK*" }

if ($issues.Count -eq 0) {
    Write-Host "[PASS] Device $DeviceSerial is ready for wipe and Autopilot re-provisioning." -ForegroundColor Green
} else {
    Write-Host "[HOLD] $($issues.Count) issue(s) found. DO NOT wipe this device until resolved." -ForegroundColor Red
    Write-Host "       Resolve issues in Intune/Entra portal, then re-run this script." -ForegroundColor Yellow
}
