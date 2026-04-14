param (
    [string]$bundleName = "Microsoft.WindowsNotepad_11.2510.14.0_neutral_~_8wekyb3d8bbwe.Msixbundle" # Package we're installing/updating
)

try {
    $bundle = Join-Path -Path $PSScriptRoot -ChildPath $bundleName
    $appxDependencies = Get-ChildItem -Path $PSScriptRoot -Filter "*.appx" | Select-Object -ExpandProperty FullName
    $msixDependencies = Get-ChildItem -Path $PSScriptRoot -Filter "*.msix" | Select-Object -ExpandProperty FullName

    foreach ($appx in $appxDependencies) {
        Add-AppxProvisionedPackage -Online -PackagePath $appx -SkipLicense
    }

    foreach ($msix in $msixDependencies) {
        Add-AppxProvisionedPackage -Online -PackagePath $msix -SkipLicense
    }

    Add-AppxProvisionedPackage -Online -PackagePath $bundle -SkipLicense
}
catch {
    if (-not (Test-Path -Path "C:\temp")) {
        New-Item -Path "C:\temp" -ItemType Directory | Out-Null
    }

    $timestamp = Get-Date -Format "ddMMMyyyy"
    $LogFile   = Join-Path "C:\temp" "Install-AppxPackage-$timestamp.log"

    Write-Output "ERROR - Could not install package $_" | Add-Content -Path $LogFile
}