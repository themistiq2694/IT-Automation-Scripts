# Validate-OneDriveSync.ps1
# Description : Checks OneDrive sync status on a local machine post-migration.
#               Verifies that Known Folders (Desktop, Documents, Pictures) are
#               redirected and that OneDrive is in a healthy sync state.
# Author      : Mihail-Petre Dragutoiu
# Usage       : .\Validate-OneDriveSync.ps1

$report = @()

# -- Check OneDrive process --
$odProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
$report += [PSCustomObject]@{ Check = "OneDrive Process Running"; Result = if ($odProcess) { "OK" } else { "NOT RUNNING" } }

# -- Check KFM registry values --
$regPath  = "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1\ScopeIdToMountPointPathCache"
$kfmPath  = "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1"

$tenantId = (Get-ItemProperty -Path $kfmPath -ErrorAction SilentlyContinue).ServiceEndpointUri
$report  += [PSCustomObject]@{ Check = "OneDrive Business Account Linked"; Result = if ($tenantId) { "OK" } else { "NOT LINKED" } }

# -- Check Known Folder redirection --
$knownFolders = @{
    "Desktop"   = [Environment]::GetFolderPath("Desktop")
    "Documents" = [Environment]::GetFolderPath("MyDocuments")
    "Pictures"  = [Environment]::GetFolderPath("MyPictures")
}

foreach ($folder in $knownFolders.Keys) {
    $path   = $knownFolders[$folder]
    $isOD   = $path -like "*OneDrive*"
    $report += [PSCustomObject]@{
        Check  = "KFM – $folder redirected to OneDrive"
        Result = if ($isOD) { "OK – $path" } else { "NOT REDIRECTED – $path" }
    }
}

# -- Check OneDrive sync status via shell --
$statusKey = "HKCU:\Software\Microsoft\OneDrive\Accounts\Business1"
$syncStatus = (Get-ItemProperty -Path $statusKey -ErrorAction SilentlyContinue).LastKnownFolderMoveError
$report    += [PSCustomObject]@{
    Check  = "KFM Last Error"
    Result = if ($null -eq $syncStatus -or $syncStatus -eq 0) { "OK – No errors" } else { "ERROR Code: $syncStatus" }
}

# -- Display results --
Write-Host "`n=== OneDrive Post-Migration Validation ===" -ForegroundColor Cyan
$report | Format-Table Check, Result -AutoSize

$issues = $report | Where-Object { $_.Result -notlike "OK*" }
if ($issues.Count -eq 0) {
    Write-Host "[PASS] All checks passed." -ForegroundColor Green
} else {
    Write-Host "[ATTENTION] $($issues.Count) issue(s) found – review above." -ForegroundColor Red
}
