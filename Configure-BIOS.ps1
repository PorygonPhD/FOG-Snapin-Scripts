[CmdletBinding()]
param(
    [string]$biosConfig         = "BiosConfigUtility64.exe",
    [string]$pwdUtility         = "HPQPswd64.exe",
    [string]$logDirectory       = "C:\temp\Logs", #Log location.
    [string]$pwdFile            = $null, # e.g. "Annual2026.bin"; Passwords have to be created with the HP password utility.
    [switch]$disableUSB         = $false,
    [switch]$disableSecureBoot  = $false
)
# todo: make a "create password" option if the tool is within the same directory.
# ----------------- Logging -----------------------

#region Logging
# Creates log directory (if it doesn't exist)
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

# Declares timestamp of the filename; creates the logfile.
$timestamp = Get-Date -Format "ddMMMyyyy"
$logFile   = Join-Path $logDirectory "Configure-BIOS-$timestamp.log"

# Function that well, writes logs. A little better than Write-Host because it puts a good amount of relevant info and structures it cleanly.
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = 'INFO',
        [string]$ComputerName = $env:ComputerName,
        [string]$logFile = $script:logfile
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$ts] [$Level] [$ComputerName] $Message"

    switch ($Level.ToUpper()) {
        'INFO'    { Write-Host $logEntry -ForegroundColor Gray }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
        'WARN'    { Write-Host $logEntry -ForegroundColor Yellow }
        'ERROR'   { Write-Host $logEntry -ForegroundColor Red }
        'DEBUG'   { Write-Host $logEntry -ForegroundColor Cyan }
        default   { Write-Host $logEntry }
    }
    Add-Content -Path $logFile -Value $logEntry
}
#endregion

# ----------------- Create File Paths -----------------------
#region File Paths

# We pull the current directory we are running from using $PSCommandPath instead of $PSScriptRoot
$scriptPath = Split-Path -Path $PSCommandPath -Parent

# We create paths (stored in vars) assuming these files exist in the same dir as the script. We verify later.
$biosConfigPath = Join-Path -Path "$scriptPath" -ChildPath "$biosConfig"
$pwdUtilityPath = Join-Path -Path "$scriptPath" -ChildPath "$pwdUtility"
$pwdFilePath = Join-Path -Path "$scriptPath" -ChildPath "$pwdFile"

#endregion

# ----------------- Functions -----------------------
#region Functions
function Test-BIOSConfigurationTool {
    param (
        [string]$biosConfig = "BiosConfigUtility64.exe" # 64-bit BIOS tool; doesn't need to be a param here but makes it easier to incorporate into other scripts.
    )
    # Does the BIOS configuration tool exist in the same dir as this script?
    $doesBiosConfigToolExist = Test-Path -Path $biosConfigPath

    # We create the path where the tool would be if it was installed.
    $defaultBiosToolInstallPath = Join-Path -Path $scriptPath -ChildPath $biosConfig

    # We take the path we just created and test it. If it doesn't exist (equals $false), it's not installed.
    $isBiosToolInstalled = Test-Path -Path $defaultBiosToolInstallPath

    # If the output of Test-Path equals $true, the tool is present.
    if ($doesBiosConfigToolExist) {
        Write-Log -Message "BIOS configuration tool is present within current directory. Proceeding..." -Level "INFO"
        return $true
    }

    elseif ($isBiosToolInstalled) {
        Write-Log -Message "BIOS configuration tool is not bundled but is installed locally. Shifting variables..." -Level "INFO"
        #* The "script:" part should edit the variable for the whole script? untested.
        $script:biosConfigPath = "C:\Program Files (x86)\HP\BIOS Configuration Utility\BiosConfigUtility64.exe"
        return $true
    }

    # The configuration tool does NOT exist in the current directory. We exit.
    elseif (!($doesBiosConfigToolExist) -and !($isBiosToolInstalled)) {
        Write-Log -Message "BIOS configuration tool is NOT present." -Level "ERROR"
        Write-Log -Message "The BIOS configuration tool `"BiosConfigUtility64.exe`" and its DLLs need to be in the current folder or installed." -Level "WARN"
        Write-Log -Message "Exiting script..." -Level "INFO"
        exit 404
    }
}

function Test-BIOSPasswordTool {
    param (
        [string]$pwdUtility = "HPQPswd64.exe" # 64-bit BIOS Password tool; doesn't need to be a param here but makes it easier to incorporate into other scripts.
    )
    # Does the password utility exist in the same dir as this script?
    $doesPasswordToolExist = Test-Path -Path $pwdUtilityPath

    # We create the path where the utility would be if it was installed.
    $defaultPwdUtilityInstallPath = Join-Path -Path $scriptPath -ChildPath $pwdUtility

    # We take the path we just created and test it. If it doesn't exist (equals $false), it's not installed.
    $isPasswordToolInstalled = Test-Path -Path $defaultPwdUtilityInstallPath

    # If the output of Test-Path equals $true, the utility is present.
    if ($doesPasswordToolExist) {
        Write-Log -Message "Password tool is present within current directory. Proceeding..." -Level "INFO"
        return $true
    }

    # If the tool isn't present with the script, is it installed?
    elseif ($isPasswordToolInstalled) {
        Write-Log -Message "Password tool is not bundled but is installed locally. Shifting variables..." -Level "INFO"
        $script:pwdUtilityPath = "C:\Program Files (x86)\HP\BIOS Configuration Utility\HPQPswd64.exe"
        return $true
    }

    # It doesn't exist but isn't needed in most contexts. We'll proceed but output $false to ease checks.
    elseif (!($doesPasswordToolExist) -and !($doesPasswordToolExist)) {
        Write-Log -Message "Password tool is not present but is not always necessary." -Level "WARN"
        Write-Log -Message "We won't be able to create encrypted password .bins, if necessary." -Level "DEBUG"
        return $false
    }
}

function Test-BIOSPassword {
    param (
        [string]$pwdFile = $null # The encrypted password file made by the password tool.
    )
    # If a password file is not specified, we will proceed but warn the user. Otherwise, we pass down the password file and test it.
    if ($null -eq $pwdFile) {
        Write-Log -Message "No password was provided." -Level "WARN"
        Write-Log -Message "If a BIOS password is set, all subsequent commands will fail." -Level "WARN"
        $arguments = @(
            "/setvalue:`"NumLock on at boot`",`"Enable`""
            "/cpwdfile:`"$pwdFile`""
        )
        try {
            Start-Process -FilePath "$biosConfigPath" -ArgumentList $arguments -Wait -WindowStyle Hidden
            Write-Log -Message "Password was not provided but password is not set." -Level "INFO"
        }
        catch {
            Write-Log -Message "A BIOS password is set and you haven't provided one." -Level "ERROR"
            Write-Log -Message "Please try providing a password and ensure you are using the correct `".bin`" password files." -Level "ERROR"
            Write-Log -Message "Exiting script..." -Level "ERROR"
            exit 10
        }
    }

    else {
        #Write-Log -Message "Passing password file $pwdFile to BIOS configuration utility and verifying..." -Level "INFO"
        Write-Log -Message "Checking if password is set..." -Level "INFO"
        $arguments = @(
            "/setvalue:`"NumLock on at boot`",`"Enable`""
        )

        # BIOS doesn't have a password but is successful anyway. We'll set it to the currently provided password file.
        Start-Process -FilePath "$biosConfigPath" -ArgumentList $arguments -Wait -WindowStyle Hidden
        if ($LASTEXITCODE -eq 0) {
            Write-Log -Message "Password is not set but a password was provided." -Level "INFO"
            Write-Log -Message "Setting password to $pwdFile" -Level "INFO"
            $arguments = @(
                "/npwdfile:`"$pwdFile`""
            )
            try {
                Start-Process -FilePath "$biosConfigPath" -ArgumentList $arguments -Wait -WindowStyle Hidden
            }
            catch {
                Write-Log -Message "Could not set password. $_" -Level "ERROR"
                exit 10
            }
        }

        elseif ($LASTEXITCODE -eq 10) {
            Write-Log -Message "Password is set on BIOS."
            Write-Log -Message "Testing password file $pwdFile..."
            $arguments = @(
                "/setvalue:`"NumLock on at boot`",`"Enable`""
                "/cpwdfile:`"$pwdFile`""
            )

            # Attempting current password file...
            Start-Process -FilePath "$biosConfigPath" -ArgumentList $arguments -Wait -WindowStyle Hidden
            if ($LASTEXITCODE -eq -0) {
                Write-Log -Message "The provided password is correct! Proceeding..." -Level "SUCCESS"
            }
            elseif ($LASTEXITCODE -eq 10) {
                Write-Log -Message "The provided password was incorrect. Please try another and ensure you are using the correct `".bin`" password files." -Level "ERROR"
                Write-Log -Message "Exiting script..." -Level "ERROR"
                exit 10
            }
        }
    }
}

#todo: make Import-BIOSConfiguration, implement /WarningAsErr, and define error codes with specific errors to console.
function Edit-BIOSConfiguration {
    param (
        [string]$biosConfigPath = $script:biosConfigPath,
        [string]$biosOption,
        [string]$biosOptionResult = "Enable", # Default is "enable"; This is a string because there are multiple different options, not just "Enable" or "Disable".
        [string]$pwdFile = $script:pwdFilePath
    )
    # the argument list we're going to pass to the below command.
    $arguments = @(
        "/setvalue:`"$biosOption`",`"$biosOptionResult`""
        "/cpwdfile:`"$pwdFile`""
    )
    Write-Log -Message "Setting $biosOption to $biosOptionResult..."
    Start-Process -FilePath "$biosConfigPath" -ArgumentList $arguments -Wait -WindowStyle Hidden
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "Successfully set $biosOption to $biosOptionResult." -Level "SUCCESS"
    }
    elseif ($LASTEXITCODE -eq 10) {
        Write-Log -Message "Valid password was not provided." -Level "ERROR"
    }
}
#endregion

# ----------------- Variable Checks -----------------------
#region Variable Checks

#* The functions should exit if an error occurs but I had coded this before I reworked some of the functions, this could probably be removed? untested.
# Does the BIOS configuration tool exist?
Test-BIOSConfigurationTool -biosConfig $biosConfig

# Does the BIOS password tool exist?
Test-BIOSPasswordTool -pwdUtility $pwdUtility

# Has a valid BIOS password been specified? Does it exist?
Test-BIOSPassword -pwdFile $pwdFilePath

#todo: make function (Currently not implemented!!)
if ($createPassword -eq $true) {
    Start-Process -FilePath "HPQPswd64.exe" -ArgumentList "/s /p $newPwd /f "$newPwdFile"" -Wait -WindowStyle Hidden
}

# USB devices are only disabled if $disableUSB is set to $true
if ($disableUSB) {
    Write-Log -Message "Disable USB option is enabled..." -Level "WARN"
    Write-Log -Message "All USB devices besides the keyboard and mouse WILL be disabled." -Level "WARN"
}

#endregion



# ----------------- Suspend BitLocker -----------------------
#region BitLocker
# We don't want to trigger BitLocker, that would suck.
Write-Log -Message "Suspending BitLocker for one reboot..."
Suspend-BitLocker -MountPoint "C:" -RebootCount 1 -ErrorAction SilentlyContinue | Out-Null
#endregion

# ----------------- Secure Boot Options -----------------------
#region Secure Boot

# Enables the Microsoft UEFI CA key
Edit-BIOSConfiguration -biosOption "Enable MS UEFI CA Key" -biosOptionResult "Yes"

# Enable Secure Boot
if (!($disableSecureBoot)) {
    Edit-BIOSConfiguration -biosOption "Secure Boot" -biosOptionResult "Enable"
}

# if $disableSecureboot is true, we disable Secure Boot.
elseif ($disableSecureBoot) {
    Edit-BIOSConfiguration -biosOption "Secure Boot" -biosOptionResult "Disable"
}

# Enable Trusted Execution Technology (TXT)
Edit-BIOSConfiguration -biosOption "Trusted Execution Technology (TXT)" -biosOptionResult "Enable"

# Enable Virtualization Technology (VTx)
Edit-BIOSConfiguration -biosOption "Virtualization Technology (VTx)" -biosOptionResult "Enable"

# Enable Virtualization Technology for Directed I/O (VTd)
Edit-BIOSConfiguration -biosOption "Virtualization Technology for Directed I/O (VTd)" -biosOptionResult "Enable"

# Enable Hyperthreading (if it was disabled for whatever reason)
Edit-BIOSConfiguration -biosOption "Hyperthreading" -biosOptionResult "Enable"

#endregion

# ----------------- BIOS Boot Options -----------------------
#region BIOS Boot Options

# Disable Fast Boot
Edit-BIOSConfiguration -biosOption "Fast Boot" -biosOptionResult "Disable"

# Force enable NumLock on boot
Edit-BIOSConfiguration -biosOption "NumLock on at boot" -biosOptionResult "Enable"

# Disable audio alerts during boot (can be turned back on, it's just annoying at times)
Edit-BIOSConfiguration -biosOption "Audio Alerts During Boot" -biosOptionResult "Disable"

# Go to previous state when power loss occurs
Edit-BIOSConfiguration -biosOption "After Power Loss" -biosOptionResult "Previous State"

# Disable USB storage boot
Edit-BIOSConfiguration -biosOption "USB Storage Boot" -biosOptionResult "Disable"

# Disable PXE booting from IPv6 (not really used anywhere)
Edit-BIOSConfiguration -biosOption "IPv6 during UEFI Boot" -biosOptionResult "Disable"

# ----------------- Disable BIOS Firmware Downgrading -----------------------
#region BIOS Downgrade and Rollback
# Disable BIOS Rollback
Edit-BIOSConfiguration -biosOption "BIOS Rollback Policy" -biosOptionResult "Restricted Rollback to older BIOS"

# Require BIOS password to downgrade firmware
Edit-BIOSConfiguration -biosOption "BIOS Update Credential Policy" -biosOptionResult "Require Credentials on Downgrade Only"

#endregion

# ----------------- Disable Onboard Devices -----------------------
#region Disable Onboard Devices
# if $disableUSB is set to $true, we'll disable all USB devices besides mice and keyboards.
if ($disableUSB) {
    Edit-BIOSConfiguration -biosOption "Restrict USB Devices" -biosOptionResult "Allow only keyboard and mouse"
}

# Disables embedded microphones (if they exist)
Edit-BIOSConfiguration -biosOption "Microphone" -biosOptionResult "Disable and Lock"

# Disables M.2 WLAN/BT, if present
Edit-BIOSConfiguration -biosOption "M.2 WLAN/BT" -biosOptionResult "Disable"

# Disables M.2 USB/Bluetooth, if present
Edit-BIOSConfiguration -biosOption "M.2 USB / Bluetooth" -biosOptionResult "Disable"

# ----------------- BIOS Event Log -----------------------
#region BIOS Event Log
# Disable clearing of the BIOS event log
Edit-BIOSConfiguration -biosOption "Clear BIOS Event Log" -biosOptionResult "Don't Clear"

#endregion

# ----------------- BIOS Password Authentication -----------------------
#region Password Authentication
# Requre password when entering Boot Menu "F9"
Edit-BIOSConfiguration -biosOption "Prompt for Admin authentication on F9 (Boot Menu)" -biosOptionResult "Enable"

# Requre password when entering System Recovery "F11"
Edit-BIOSConfiguration -biosOption "Prompt for Admin authentication on F11 (System Recovery)" -biosOptionResult "Enable"

#endregion

# ----------------- Misc. BIOS Settings -----------------------
#region Misc. BIOS Settings
# Prompt user when side panel is removed
Edit-BIOSConfiguration -biosOption "Cover Removal Sensor" -biosOptionResult "Notify user"

# Prompt user when RAM size changes
Edit-BIOSConfiguration -biosOption "Prompt on Memory Size Change" -biosOptionResult "Enable"

#endregion