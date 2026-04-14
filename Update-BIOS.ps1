#* Script assumes that you don't have a BIOS password assigned!
$biosSoftPaq = "sp170175.exe"
$biosUpdate = "HpFirmwareUpdRec64.exe"
$biosDeployFolder = "C:\temp\BIOS"

# We don't want to trigger BitLocker
Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -ErrorAction SilentlyContinue

# Create the temp BIOS folder if it doesn't exist
if (-not (Test-Path -Path $biosDeployFolder)) {
    New-Item -Path $biosDeployFolder -ItemType Directory | Out-Null
}

# /s is silent and /e extracts the bios updater without running it (needs to be run separately)
Start-Process -FilePath "$PSScriptRoot\$biosSoftPaq" -ArgumentList "/s /e /f `"C:\temp\BIOS`"" -Wait -WindowStyle Hidden

# /s is silent and /b suspends bitlocker just in case it wasn't above
#* Script assumes that you don't have a BIOS password assigned (would need to be pointed at with `/p "password.bin"`)
Start-Process -FilePath "$biosDeployFolder\$biosUpdate" -ArgumentList "/s /b" -Wait -WindowStyle Hidden