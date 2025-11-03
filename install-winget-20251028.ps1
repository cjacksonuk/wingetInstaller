<#
    Install-WinGet-Repair.ps1
    Deploys or repairs WinGet (App Installer) + dependencies.
    Works in SYSTEM context (GPO Startup).
    Author: ICT Hero (Christian Jackson)
    Date: 2025-10-28
#>

# ===== CONFIGURATION =====
$LogFile = "C:\appinstall.log"
$Source  = "\\curric1\Install\App\winget"

$Packages = @{
    "VCLibs_x64" = "$Source\Microsoft.VCLibs.x64.14.00.Desktop.appx"
    "UIXaml_x64" = "$Source\Microsoft.UI.Xaml.2.8.x64.appx"
    "ApInstaller" = "$Source\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
}
# ==========================

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Add-Content -Path $LogFile -Value "$ts  $Message"
}

Write-Log "=============================================="
Write-Log "Starting WinGet install/repair"
Write-Log "Running as: $(whoami)"
Write-Log "Source path: $Source"

# --- Step 1: Detect current App Installer state ---
$apps = Get-AppxPackage -AllUsers Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue
$needsInstall = $true
if ($apps) {
    foreach ($a in $apps) {
        Write-Log ("Found {0} version {1} Status={2}" -f $a.PackageFullName, $a.Version, $a.Status)
        if ($a.Status -notmatch "DeploymentInProgress|NeedsRemediation|DependencyIssue") {
            Write-Log "App Installer appears healthy."
            $needsInstall = $false
        }
    }
}

# --- Step 2: Remove broken or old versions ---
if ($needsInstall) {
    Write-Log "Cleaning old or broken App Installer packages..."
    foreach ($a in $apps) {
        try {
            Remove-AppxPackage -AllUsers -Package $a.PackageFullName -ErrorAction SilentlyContinue
            Write-Log "Removed package: $($a.PackageFullName)"
        } catch {
            Write-Log ("Failed to remove {0}: {1}" -f $a.PackageFullName, $_)
        }
    }

    # Remove any provisioned copy
    try {
        dism /Online /Remove-ProvisionedAppxPackage /PackageName:Microsoft.DesktopAppInstaller_8wekyb3d8bbwe | Out-Null
        Write-Log "Removed provisioned App Installer package."
    } catch {
        Write-Log "No provisioned package or error removing."
    }
}

# --- Step 3: Validate file presence ---
foreach ($pkg in $Packages.Values) {
    if (-not (Test-Path $pkg)) {
        Write-Log "Missing file: $pkg"
        exit 1
    }
}

# --- Step 4: Install dependencies and App Installer ---
if ($needsInstall) {
    Write-Log "Installing dependencies and App Installer..."

    $order = @("VCLibs_x64","UIXaml_x64","AppInstaller")
    foreach ($key in $order) {
        $path = $Packages[$key]
        Write-Log "Installing $key -> $path"
        try {
            $proc = Start-Process -FilePath dism.exe `
                -ArgumentList "/Online","/Add-ProvisionedAppxPackage","/PackagePath:`"$path`"","/SkipLicense" `
                -Wait -NoNewWindow -PassThru
            Write-Log "DISM ($key) exit code: $($proc.ExitCode)"
        } catch {
            Write-Log ("Error installing {0}: {1}" -f $key, $_)
        }
    }
} else {
    Write-Log "No action required — WinGet already healthy."
    Write-Log "=============================================="
    exit 0
}

# --- Step 5: Verify installation ---
Start-Sleep -Seconds 3
$final = Get-AppxPackage -AllUsers Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue
if ($final) {
    Write-Log ("Installed App Installer version: {0}" -f $final.Version)
} else {
    Write-Log "App Installer still missing after provisioning."
}

Write-Log "WinGet deployment complete."
Write-Log "=============================================="
exit 0