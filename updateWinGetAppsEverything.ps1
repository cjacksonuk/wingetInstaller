<#
    WinGet update all apps if you can!
    -----------------------------------------
    - 2025-10-14 by Christian Jackson 

probably run this manually as some apps not installed via winget will error out
cd "C:\Users\cj\OneDrive - ICT Hero\Scripts and Programming\WinGet"
#>
# Simple winget "upgrade anything installed" script with unified logging (C:\appinstall.log)

$LogFile = "C:\appinstall.log"
$DebugEnabled = $true

# ensure log file exists (create parent folder if needed)
try {
    $logDir = Split-Path -Path $LogFile -Parent
    if ($logDir -and -not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    if (-not (Test-Path $LogFile)) { New-Item -Path $LogFile -ItemType File -Force | Out-Null }
} catch {}

function Write-Log {
    param([string]$Message, [string]$Color = "Gray")
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $entry = "[$ts] $Message"

    # write to file (best-effort)
    try { Add-Content -Path $LogFile -Value $entry -ErrorAction Stop } catch {}

    # always emit to pipeline
    Write-Output $entry

    # colored host when available
    try { Write-Host $entry -ForegroundColor $Color } catch { try { [Console]::WriteLine($entry) } catch {} }
}

# start
Write-Log "===== winget: Upgrade installed apps - started =====" "Cyan"

# check winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Log "ERROR: winget not found in PATH. Aborting." "Red"
    exit 2
}

# attempt to upgrade all available packages; log each output line
try {
    Write-Log "Running: winget upgrade --all --accept-package-agreements --accept-source-agreements" "Cyan"
    $procOutput = & winget upgrade --all --accept-package-agreements --accept-source-agreements 2>&1
    foreach ($line in $procOutput) { Write-Log $line "Gray" }

    if ($LASTEXITCODE -eq 0) {
        Write-Log "winget upgrade completed successfully (exit 0)" "Green"
    } else {
        Write-Log ("winget upgrade finished with exit code {0}" -f $LASTEXITCODE) "Yellow"
    }
} catch {
    Write-Log ("ERROR: Exception running winget upgrade: {0}" -f $_.Exception.Message) "Red"
}

Write-Log "===== winget: Upgrade installed apps - finished =====" "Cyan"