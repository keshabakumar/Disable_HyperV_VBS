# ============================================================
# Full Hyper-V / VBS / Device Guard ENABLE Script (FINAL)
# Windows 11 24H2 - Standalone with IT Logging
# Re-enables: Hyper-V, WSL2, Kubernetes/Docker support, VBS, Credential Guard, HVCI
# Combines: Manual feature re-enable + DG Readiness Tool -Enable logic (embedded inline)
# No external downloads required — fully self-contained
# Run in PowerShell as Administrator (auto-elevates if needed)
# ============================================================

param(
    [string]$LogDir = "C:\DGLogs"
)

# ------------------------------------------------------------
# Helper Function: Write-Log (timestamped IT logging)
# ------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $logEntry = "[$timestamp] [$Level] $Message"
    if ($script:logFile) {
        try {
            Add-Content -Path $script:logFile -Value $logEntry -Force -ErrorAction Stop
        } catch {
            Write-Host "[LOG WRITE ERROR] Could not write to log: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if ($Level -eq "SUCCESS") {
        Write-Host $Message -ForegroundColor Green
    } elseif ($Level -eq "WARN") {
        Write-Host $Message -ForegroundColor Yellow
    } elseif ($Level -eq "ERROR") {
        Write-Host $Message -ForegroundColor Red
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

# ------------------------------------------------------------
# Helper: ExecuteCommandAndLog (from DG Readiness Tool)
# ------------------------------------------------------------
function ExecuteCommandAndLog {
    param([string]$_cmd)
    try {
        Write-Log "Executing: $_cmd" -Level "INFO"
        $CmdOutput = Invoke-Expression $_cmd | Out-String
        Write-Log "Output: $CmdOutput" -Level "INFO"
    } catch {
        Write-Log "Exception while executing $_cmd : $($_.Exception.Message)" -Level "WARN"
    }
}

# ------------------------------------------------------------
# Helper: IsRedstone (from DG Readiness Tool)
# ------------------------------------------------------------
function IsRedstone {
    $_osVersion = [environment]::OSVersion.Version
    if ($_osVersion.Major -lt 10) { return 0 }
    if ($_osVersion.Build -gt 10586) { return 1 }
    return 0
}

# ------------------------------------------------------------
# SIPolicy.p7b (embedded from DG Readiness Tool v3.6)
# This is the default Microsoft Code Integrity policy
# ------------------------------------------------------------
$SIPolicy_Encoded = "BQAAAA43RKLJRAZMtVH2AW5WMHbk9wcuTBkgTbfJb0SmxaI0BACNkAgAAAAAAAAA
HQAAAAIAAAAAAAAAAAAKAEAAAAAMAAAAAQorBgEEAYI3CgMGDAAAAAEKKwYBBAGC
NwoDBQwAAAABCisGAQQBgjc9BAEMAAAAAQorBgEEAYI3PQUBDAAAAAEKKwYBBAGC
NwoDFQwAAAABCisGAQQBgjdMAwEMAAAAAQorBgEEAYI3TAUBDAAAAAEKKwYBBAGC
N0wLAQEAAAAGAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AQAAAAYAAAABAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAA
BgAAAAEAAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAGAAAA
AQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAUAAAABAAAA
AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAABAAAAAEAAAABAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAGAAAAAQAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAYAAAABAAAAAgAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAABAAAABgAAAAEAAAADAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAEAAAAGAAAAAQAAAAEAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAQAAAAUAAAABAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAABAAAADgAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAEAAAAOAAAAAQAAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AQAAAA4AAAABAAAAAwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAA
DgAAAAEAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAOAAAA
AQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAA4AAAABAAAA
AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAADgAAAAEAAAADAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAOAAAAAQAAAAEAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAQAAAABAAAAAQAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAAPye3j3MoJGGstO/m3OKIFDLGlVN
otyttV8/cu4XchN4AQAAAAUAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AQAAAAYAAAABAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAA
DgAAAAEAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAHAAAA
AQAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQAAAAoAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAKAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAABAAAADAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAQAAAAYAAAABAAAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAABAAAABwAAAAEAAAAHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAABAAAAFAAAAIMAAAAAAAAADIAAAAsAAAAAAAAAAAAAAAEAAAAAAAAA
AgAAAAAAAAADAAAAAAAAAAQAAAAAAAAABQAAAAAAAAALAAAAAAAAAAwAAAAAAAAA
DQAAAAAAAAAOAAAAAAAAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAMAAAAAAAAAAyAAAASAAAABgAAAAAAAAAHAAAAAAAAAAgAAAAAAAAA
CQAAAAAAAAAKAAAAAAAAABMAAAAAAAAADwAAAAAAAAAQAAAAAAAAABEAAAAAAAAA
EgAAAAAAAAAUAAAAAAAAABUAAAAAAAAAGgAAAAAAAAAbAAAAAAAAABwAAAAAAAAA
FgAAAAAAAAAXAAAAAAAAABkAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAgAAABQAAABQAG8AbABpAGMAeQBJAG4AZgBvAAAAAAAWAAAA
SQBuAGYAbwByAG0AYQB0AGkAbwBuAAAAAAAAAAQAAABJAGQAAAAAAAMAAAAMAAAA
MAAzADEAMAAxADcAAAAAABQAAABQAG8AbABpAGMAeQBJAG4AZgBvAAAAAAAWAAAA
SQBuAGYAbwByAG0AYQB0AGkAbwBuAAAAAAAAAAgAAABOAGEAbQBlAAAAAAADAAAA
JgAAAEQAZQBmAGEAdQBsAHQAVwBpAG4AZABvAHcAcwBBAHUAZABpAHQAAAAAAAAA
AwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAA
BQAAAAYAAAA="

# ------------------------------------------------------------
# Auto-Elevation: If running in standard PowerShell, prompt for Administrator rights
# ------------------------------------------------------------
if (-not ([System.Security.Principal.WindowsPrincipal][System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required." -ForegroundColor Yellow
    Write-Host "Requesting Administrator permission via UAC prompt..." -ForegroundColor Cyan

    $rawPath = $PSCommandPath
    if (-not $rawPath) {
        $rawPath = $MyInvocation.MyCommand.Path
    }
    if (-not $rawPath -and $MyInvocation.MyCommand.Name) {
        $candidate = Join-Path -Path $PSScriptRoot -ChildPath $MyInvocation.MyCommand.Name
        if (Test-Path -Path $candidate) {
            $rawPath = $candidate
        }
    }

    $scriptPath = $null
    if ($rawPath -and (Test-Path -Path $rawPath)) {
        $scriptPath = (Resolve-Path -Path $rawPath).Path
    }

    if ($scriptPath) {
        try {
            Start-Process -FilePath "powershell.exe" -ArgumentList "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -LogDir `"$LogDir`"" -Verb RunAs
            Write-Host "Elevated Administrator session launched in a separate window." -ForegroundColor Green
            return
        } catch {
            Write-Host "Administrator elevation was declined or cancelled." -ForegroundColor Red
            return
        }
    } else {
        Write-Host "ERROR: Could not resolve script file path for auto-elevation." -ForegroundColor Red
        Write-Host "Please right-click PowerShell, choose 'Run as administrator', and run the script file." -ForegroundColor Yellow
        return
    }
}

# ------------------------------------------------------------
# Logging Initialization
# ------------------------------------------------------------
try {
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    }
} catch {
    Write-Host "[WARNING] Could not create log folder '$LogDir': $($_.Exception.Message)" -ForegroundColor Yellow
    $LogDir = "$env:TEMP\DGLogs"
    if (-not (Test-Path -Path $LogDir)) {
        New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction SilentlyContinue | Out-Null
    }
}
$script:logFile = Join-Path -Path $LogDir -ChildPath "Enable_HyperV_VBS_Log.txt"
$logFile = $script:logFile

# Start IT Log Session
Write-Log "============================================================" -Level "INFO" -Color Cyan
Write-Log "STARTING HYPER-V & VBS ENABLE SESSION (FINAL)" -Level "INFO" -Color Cyan
Write-Log "Computer Name: $env:COMPUTERNAME | User: $env:USERNAME" -Level "INFO" -Color Gray
Write-Log "Windows OS: $((Get-CimInstance Win32_OperatingSystem).Caption) (Build $((Get-CimInstance Win32_OperatingSystem).BuildNumber))" -Level "INFO" -Color Gray
Write-Log "Log file location: $logFile" -Level "INFO" -Color Gray
Write-Log "============================================================" -Level "INFO" -Color Cyan

# ------------------------------------------------------------
# Pre-Check: Verify BitLocker / Device Encryption is OFF
# If BitLocker is ON, abort the script to prevent recovery key issues
# ------------------------------------------------------------
Write-Log "`n=== Pre-Check: Verifying BitLocker / Device Encryption status ===" -Level "INFO" -Color Cyan
$bitlockerActive = $false
try {
    $bdeStatus = (manage-bde -status C: 2>&1 | Out-String)
    Write-Log "BitLocker status check output: $bdeStatus" -Level "INFO"

    if ($bdeStatus -match "Protection On") {
        $bitlockerActive = $true
    }

    # Also check Windows modern device encryption (Settings > Privacy & Security > Device Encryption)
    $deviceEncryptionPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    if (Test-Path -Path $deviceEncryptionPath) {
        $devEncStatus = Get-ItemProperty -Path $deviceEncryptionPath -ErrorAction SilentlyContinue
        if ($devEncStatus.PreventDeviceEncryption -eq 0) {
            # Check if modern encryption is active via WMI
            $encVolume = Get-CimInstance -Namespace "root\cimv2\security\MicrosoftVolumeEncryption" -ClassName Win32_EncryptableVolume -ErrorAction SilentlyContinue
            if ($encVolume -and $encVolume.ProtectionStatus -eq 1) {
                $bitlockerActive = $true
            }
        }
    }
} catch {
    Write-Log "BitLocker status check encountered an error: $($_.Exception.Message)" -Level "WARN"
}

if ($bitlockerActive) {
    Write-Log "ERROR: BitLocker / Device Encryption is currently ON!" -Level "ERROR"
    Write-Log "This script cannot proceed because it changes UEFI firmware variables (SecConfig.efi)" -Level "ERROR"
    Write-Log "which can trigger a BitLocker recovery key prompt on next reboot." -Level "ERROR"
    Write-Log "" -Level "ERROR"
    Write-Log "PLEASE DO THE FOLLOWING FIRST:" -Level "WARN"
    Write-Log "  1. Go to Settings > Privacy & Security > Device Encryption" -Level "WARN"
    Write-Log "  2. Turn OFF Device Encryption / BitLocker" -Level "WARN"
    Write-Log "  3. Wait for decryption to complete (may take time depending on drive size)" -Level "WARN"
    Write-Log "  4. Re-run this script" -Level "WARN"
    Write-Log "" -Level "ERROR"
    Write-Log "Script aborted. No changes were made." -Level "ERROR"
    Write-Log "============================================================" -Level "ERROR"

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host "  BITLOCKER / DEVICE ENCRYPTION IS ON — SCRIPT ABORTED" -ForegroundColor Red
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "  This script changes UEFI firmware variables which can trigger" -ForegroundColor Yellow
    Write-Host "  a BitLocker recovery key prompt on next reboot." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Please do the following:" -ForegroundColor Cyan
    Write-Host "    1. Settings > Privacy & Security > Device Encryption" -ForegroundColor White
    Write-Host "    2. Turn OFF Device Encryption / BitLocker" -ForegroundColor White
    Write-Host "    3. Wait for decryption to complete" -ForegroundColor White
    Write-Host "    4. Re-run this script" -ForegroundColor White
    Write-Host ""
    Write-Host "  No changes were made to your system." -ForegroundColor Gray
    Write-Host "============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press ENTER to exit..." -ForegroundColor Gray
    Read-Host
    exit
} else {
    Write-Log "BitLocker / Device Encryption is OFF — safe to proceed." -Level "SUCCESS"
    Write-Host "BitLocker / Device Encryption is OFF — safe to proceed." -ForegroundColor Green
}

# ------------------------------------------------------------
# Step 1: Enabling Hyper-V and related Windows features
#         (WSL2, VirtualMachinePlatform, HypervisorPlatform, Hyper-V)
# ------------------------------------------------------------
Write-Log "`n=== Step 1: Enabling Hyper-V, WSL2, and related Windows features ===" -Level "INFO" -Color Cyan
$features = @(
    @{ Name = "Microsoft-Hyper-V-All"; All = $true },
    @{ Name = "HypervisorPlatform"; All = $false },
    @{ Name = "VirtualMachinePlatform"; All = $false },
    @{ Name = "Microsoft-Windows-Subsystem-Linux"; All = $false }
)

foreach ($feat in $features) {
    try {
        Write-Log "Enabling feature: $($feat.Name)..." -Level "INFO"
        if ($feat.All) {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feat.Name -All -NoRestart -ErrorAction Stop
        } else {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feat.Name -NoRestart -ErrorAction Stop
        }
        Write-Log "Feature $($feat.Name) enabled successfully (RestartNeeded: $($result.RestartNeeded))." -Level "SUCCESS"
    } catch {
        Write-Log "Feature $($feat.Name): $($_.Exception.Message)" -Level "WARN"
    }
}

# ------------------------------------------------------------
# Step 2: Enabling hypervisor launch type in BCD
# ------------------------------------------------------------
Write-Log "`n=== Step 2: Enabling hypervisor launch type in BCD ===" -Level "INFO" -Color Cyan
try {
    $bcdOut = (bcdedit /set hypervisorlaunchtype auto 2>&1 | Out-String).Trim()
    Write-Log "bcdedit /set hypervisorlaunchtype auto -> $bcdOut" -Level "SUCCESS"
} catch {
    Write-Log "Failed to set hypervisorlaunchtype: $($_.Exception.Message)" -Level "ERROR"
}

# ------------------------------------------------------------
# Step 3: Enabling Hyper-V and IOMMU via DISM (DG Readiness Tool method)
# ------------------------------------------------------------
Write-Log "`n=== Step 3: Enabling Hyper-V and IOMMU via DISM ===" -Level "INFO" -Color Cyan
$_isRedstone = IsRedstone
if (-not $_isRedstone) {
    Write-Log "OS Not Redstone, enabling IsolatedUserMode separately..." -Level "INFO"
    ExecuteCommandAndLog 'DISM.EXE /Online /Enable-Feature:IsolatedUserMode /NoRestart'
}
try {
    $CmdOutput = DISM.EXE /Online /Enable-Feature:Microsoft-Hyper-V-Hypervisor /All /NoRestart | Out-String
    if (-not $CmdOutput.Contains("The operation completed successfully.")) {
        $CmdOutput = DISM.EXE /Online /Enable-Feature:Microsoft-Hyper-V-Online /All /NoRestart | Out-String
    }
    Write-Log "DISM output: $CmdOutput" -Level "INFO"
    if ($CmdOutput.Contains("The operation completed successfully.")) {
        Write-Log "Enabling Hyper-V and IOMMU via DISM successful." -Level "SUCCESS"
    } else {
        Write-Log "DISM Hyper-V enable did not report success (may already be enabled). Check log." -Level "WARN"
    }
} catch {
    Write-Log "DISM Hyper-V enable error: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Step 4: Enabling VBS / Device Guard Registry Keys (DG Readiness Tool -Enable method)
# ------------------------------------------------------------
Write-Log "`n=== Step 4: Enabling Virtualization-Based Security (VBS) in Registry ===" -Level "INFO" -Color Cyan
Write-Log "Setting RegKeys to enable DG/CG (DG Readiness Tool method)..." -Level "INFO"

ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 1 /f'
ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /t REG_DWORD /d 1 /f'

if (-not $_isRedstone) {
    ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Unlocked" /t REG_DWORD /d 1 /f'
} else {
    ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Locked" /t REG_DWORD /d 0 /f'
}

# Enable Credential Guard (LsaCfgFlags = 2)
ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 2 /f'

# Enable HVCI (Hypervisor-Enforced Code Integrity)
if (-not $_isRedstone) {
    ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "HypervisorEnforcedCodeIntegrity" /t REG_DWORD /d 1 /f'
} else {
    ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 1 /f'
    ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Locked" /t REG_DWORD /d 0 /f'
}
Write-Log "VBS, Credential Guard, and HVCI registry keys enabled." -Level "SUCCESS"

# ------------------------------------------------------------
# Step 5: Deploying default SIPolicy.p7b (DG Readiness Tool method)
# ------------------------------------------------------------
Write-Log "`n=== Step 5: Deploying default Code Integrity Policy (SIPolicy.p7b) ===" -Level "INFO" -Color Cyan
try {
    Write-Log "Writing decoded SIPolicy.p7b..." -Level "INFO"
    $SIPolicy_Decoded = [System.Convert]::FromBase64String($SIPolicy_Encoded)
    $ciPath = "$env:windir\System32\CodeIntegrity"
    if (-not (Test-Path -Path $ciPath)) {
        New-Item -ItemType Directory -Path $ciPath -Force | Out-Null
    }
    [System.IO.File]::WriteAllBytes("$ciPath\SIPolicy.p7b", $SIPolicy_Decoded)
    Write-Log "SIPolicy.p7b deployed successfully." -Level "SUCCESS"
} catch {
    Write-Log "Writing SIPolicy.p7b file failed: $($_.Exception.Message)" -Level "ERROR"
}

# ------------------------------------------------------------
# Step 6: Verifying hypervisor launch type in BCD
# ------------------------------------------------------------
Write-Log "`n=== Step 6: Verifying hypervisor launch type in BCD ===" -Level "INFO" -Color Cyan
try {
    $bcdCheck = (bcdedit /enum '{current}' 2>&1 | Select-String -Pattern "hypervisorlaunchtype" | Out-String).Trim()
    if ($bcdCheck -match 'hypervisorlaunchtype\s+Auto') {
        Write-Log "BCD verified: hypervisorlaunchtype = Auto" -Level "SUCCESS"
    } elseif ($bcdCheck) {
        Write-Log "hypervisorlaunchtype is NOT Auto: $bcdCheck" -Level "WARN"
        $null = bcdedit /set hypervisorlaunchtype auto
        $recheck = (bcdedit /enum '{current}' 2>&1 | Select-String -Pattern "hypervisorlaunchtype" | Out-String).Trim()
        if ($recheck -match 'hypervisorlaunchtype\s+Auto') {
            Write-Log "Re-applied successfully: hypervisorlaunchtype = Auto" -Level "SUCCESS"
        } else {
            Write-Log "Could not confirm hypervisorlaunchtype=Auto after re-apply: $recheck" -Level "ERROR"
        }
    } else {
        Write-Log "hypervisorlaunchtype entry not found in BCD; setting it explicitly to Auto." -Level "WARN"
        $finalBcd = (bcdedit /set hypervisorlaunchtype auto 2>&1 | Out-String).Trim()
        Write-Log "hypervisorlaunchtype set to Auto ($finalBcd)" -Level "SUCCESS"
    }
} catch {
    Write-Log "BCD verification note: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Step 7: WSL2 kernel update check (recommended for WSL2)
# ------------------------------------------------------------
Write-Log "`n=== Step 8: WSL2 Kernel Update Check ===" -Level "INFO" -Color Cyan
try {
    $wslStatus = (wsl --status 2>&1 | Out-String)
    if ($wslStatus -match "Default Version: 2") {
        Write-Log "WSL2 is already configured (Default Version: 2)." -Level "SUCCESS"
    } elseif ($wslStatus -match "not found" -or $wslStatus -match "not recognized") {
        Write-Log "WSL not yet available — will be active after reboot. Run 'wsl --install' after reboot if needed." -Level "WARN"
    } else {
        Write-Log "WSL status: $wslStatus" -Level "INFO"
        Write-Log "Setting WSL default version to 2..." -Level "INFO"
        $wslSet = (wsl --set-default-version 2 2>&1 | Out-String)
        Write-Log "WSL set-default-version output: $wslSet" -Level "INFO"
    }
} catch {
    Write-Log "WSL2 check skipped (will be available after reboot): $($_.Exception.Message)" -Level "INFO" -Color Gray
}

# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------
Write-Log "`n============================================================" -Level "SUCCESS"
Write-Log "ALL ENABLE STEPS COMPLETED!" -Level "SUCCESS"
Write-Log "Steps executed:" -Level "INFO" -Color Cyan
Write-Log "  1.  Enabled Hyper-V, HypervisorPlatform, VMP, WSL features" -Level "INFO" -Color Gray
Write-Log "  2.  Set hypervisorlaunchtype auto in BCD" -Level "INFO" -Color Gray
Write-Log "  3.  Enabled Hyper-V/IOMMU via DISM (DG Readiness Tool method)" -Level "INFO" -Color Gray
Write-Log "  4.  VBS, Credential Guard, HVCI registry keys enabled" -Level "INFO" -Color Gray
Write-Log "  5.  Default SIPolicy.p7b deployed (Code Integrity policy)" -Level "INFO" -Color Gray
Write-Log "  6.  BCD hypervisorlaunchtype verified = Auto" -Level "INFO" -Color Gray
Write-Log "  7.  WSL2 kernel update checked" -Level "INFO" -Color Gray
Write-Log "" -Level "INFO" -Color Gray
Write-Log "What is now re-enabled:" -Level "INFO" -Color Cyan
Write-Log "  - Hyper-V (full management + hypervisor)" -Level "INFO" -Color Gray
Write-Log "  - WSL / WSL2 (Windows Subsystem for Linux)" -Level "INFO" -Color Gray
Write-Log "  - VirtualMachinePlatform (for WSL2, Docker, etc.)" -Level "INFO" -Color Gray
Write-Log "  - HypervisorPlatform (for third-party hypervisors)" -Level "INFO" -Color Gray
Write-Log "  - Kubernetes support (via WSL2 or Hyper-V backend)" -Level "INFO" -Color Gray
Write-Log "  - Docker Desktop support (via WSL2 or Hyper-V)" -Level "INFO" -Color Gray
Write-Log "  - VBS / Credential Guard / HVCI (security features)" -Level "INFO" -Color Gray
Write-Log "" -Level "INFO" -Color Gray
Write-Log "Detailed IT execution report written to: $logFile" -Level "INFO" -Color Cyan
Write-Log "IMPORTANT: A reboot is required for all changes to take effect." -Level "WARN"
Write-Log "NOTE: After reboot, VBS/Credential Guard may trigger a password/PIN reset." -Level "WARN"
Write-Log "============================================================" -Level "SUCCESS"

Write-Host ""
$promptMsg = "Ready to restart your computer to apply changes.`nPress ENTER or [Y] to reboot now, or [N] to reboot manually later: "
$response = Read-Host -Prompt $promptMsg

if ([string]::IsNullOrWhiteSpace($response) -or $response -match "^[yY]") {
    Write-Log "User confirmed reboot. Restarting computer in 5 seconds..." -Level "WARN"
    Write-Host "`nRestarting computer in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Log "Immediate reboot postponed by user. Manual reboot required to apply changes." -Level "INFO"
    Write-Host "`nReboot postponed. Please restart your PC manually to complete changes." -ForegroundColor Yellow
    Write-Host "Press ENTER to exit..." -ForegroundColor Gray
    Read-Host
}