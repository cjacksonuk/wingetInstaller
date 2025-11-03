<#
    WinGet Maintenance & App Installer Script
    -----------------------------------------
    - 2025-10-21 by Christian Jackson, ICT Hero
    - With assistance from OpenAI (ChatGPT)
    - Installs or updates applications in $apps
    - Logs all activity to C:\appinstall.log
    - Includes timeout control per app
    - Logs user context (whoami)
    - Rotates logs when >1 MB
    - Waits for WinGet to be available (handles first-login delay)
#>

# ==========[ Configurable Section ]==========
$LogFile = "C:\appinstall.log"
$LogFileArchive = "C:\appinstallArchive.log"
$MaxLogSizeBytes = 1MB

$apps = @(
    #"Microsoft.EdgeWebView2Runtime", # Required for Cloud Drive Mapper
    #"Microsoft.DotNet.Framework.DeveloperPack_4",
    #"Microsoft.DotNet.DesktopRuntime.8",
    "VideoLAN.VLC",
    "7zip.7zip",
    "Notepad++.Notepad++",
    "Oracle.JavaRuntimeEnvironment"
)

$PerAppTimeoutMin = 5  # Max runtime per app (minutes)
$WingetTimeoutSec  = 180 # Max time to wait for winget.exe (seconds)
# ============================================

function Rotate-Log {
    if (Test-Path $LogFile) {
        $size = (Get-Item $LogFile).Length
        if ($size -gt $MaxLogSizeBytes) {
            try {
                if (Test-Path $LogFileArchive) {
                    Remove-Item $LogFileArchive -Force -ErrorAction SilentlyContinue
                }
                Rename-Item -Path $LogFile -NewName $LogFileArchive -Force
                Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Log rotated to $LogFileArchive" |
                    Out-File -FilePath $LogFile -Encoding UTF8
            }
            catch {
                Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Log rotation failed: $($_.Exception.Message)" |
                    Out-File -FilePath $LogFile -Encoding UTF8
            }
        }
    }
}

function Write-Log {
    param([string]$Message, [string]$Color = "Gray")
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $entry
    try { Write-Host $entry -ForegroundColor $Color } catch {}
}

function Wait-ForWinget {
    param([int]$TimeoutSec = 60)
    $wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    $elapsed = 0
    $interval = 5
    Write-Log "Checking for WinGet availability..." "Gray"
    while (-not (Test-Path $wingetPath) -and $elapsed -lt $TimeoutSec) {
        Write-Log "WinGet not yet available — waiting ($elapsed/$TimeoutSec s)..." "Yellow"
        Start-Sleep -Seconds $interval
        $elapsed += $interval
    }

    if (Test-Path $wingetPath) {
        Write-Log "WinGet detected at $wingetPath" "Green"
        return $true
    } else {
        Write-Log "❌ WinGet not found after waiting $TimeoutSec seconds. Exiting." "Red"
        return $false
    }
}

function Run-WithTimeout {
    param(
        [string]$CommandLine,
        [int]$TimeoutSeconds
    )
    try {
        $process = Start-Process -FilePath "cmd.exe" `
            -ArgumentList "/c $CommandLine" `
            -PassThru -WindowStyle Hidden

        $elapsed = 0
        $interval = 5
        while (-not $process.HasExited -and $elapsed -lt $TimeoutSeconds) {
            Start-Sleep -Seconds $interval
            $elapsed += $interval
        }

        if (-not $process.HasExited) {
            Write-Log "Timeout reached ($TimeoutSeconds s). Terminating process ID $($process.Id)"
            try { $process.Kill() } catch { Write-Log "Failed to terminate process: $($_.Exception.Message)" }
            return $false
        } else {
            return $true
        }
    } catch {
        Write-Log "ERROR: Failed to start command: $($_.Exception.Message)"
        return $false
    }
}

function Install-Or-UpdateApps {
    Write-Log "=== Installing/Updating Applications ===" "Cyan"

    foreach ($app in $apps) {
        Write-Log "Processing $app..." "Gray"
        try {
            $isInstalled = $false
            $listOutput = & winget list --id $app 2>&1
            $listText = ($listOutput -join "`n").Trim()

            if ($listText -match 'No installed package' -or $listText -match 'No installed package found') {
                $isInstalled = $false
            }
            elseif ($listText -match '\b\d+(\.\d+)+\b' -or $listText -match [regex]::Escape($app)) {
                $isInstalled = $true
            }
            else {
                Write-Log ("Warning: could not determine install state for {0}; output: {1}" -f $app, ($listText -replace "[\r\n]+", " | ")) "Yellow"
                $isInstalled = $false
            }

            if ($isInstalled) {
                Write-Log "Updating $app..." "Yellow"
                $Command = "winget upgrade --id $app --accept-source-agreements --accept-package-agreements"
            } else {
                Write-Log "Installing $app..." "Yellow"
                $Command = "winget install --id $app --accept-source-agreements --accept-package-agreements"
            }

            $success = Run-WithTimeout -CommandLine $Command -TimeoutSeconds ($PerAppTimeoutMin * 60)
            if ($success) {
                Write-Log "Completed $app" "Green"
            } else {
                Write-Log "Timeout or failure for $app" "Red"
            }

        } catch {
            Write-Log ("ERROR: Failed processing {0}: {1}" -f $app, $_.Exception.Message) "Red"
        }
    }
}

# =======[ Run Process ]=======
Rotate-Log
$UserContext = whoami
Write-Log "===== Script started =====" "Cyan"
Write-Log "Running as: $UserContext"

if (Wait-ForWinget -TimeoutSec $WingetTimeoutSec) {
    Install-Or-UpdateApps
} else {
    Write-Log "Exiting — WinGet not available yet."
}

Write-Log "===== Script finished =====" "Cyan"
# =============================='