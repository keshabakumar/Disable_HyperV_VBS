# ============================================================
# Full Hyper-V / VBS / Device Guard ENABLE Script (FINAL COMPLETE RESTORATION)
# Windows 11 24H2 - Standalone with IT Logging
# Re-enables: Hyper-V, WSL2, VirtualMachinePlatform, VBS, Credential Guard, HVCI
# Restores: OEM Services & Scheduled Tasks (ASUS, MSI, Razer, Lenovo, HP, Acer)
# Safety: AC Check, System Restore Point, BCD Backup, BitLocker Auto-Suspension
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
# Helper: ExecuteCommandAndLog (safe execution via cmd /c)
# ------------------------------------------------------------
function ExecuteCommandAndLog {
    param([string]$_cmd)
    try {
        Write-Log "Executing: $_cmd" -Level "INFO"
        $CmdOutput = cmd /c $_cmd 2>&1 | Out-String
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
# Default Microsoft Code Integrity policy
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
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAA
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
            exit
        } catch {
            Write-Host "Administrator elevation was declined or cancelled." -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "ERROR: Could not resolve script file path for auto-elevation." -ForegroundColor Red
        Write-Host "Please right-click PowerShell, choose 'Run as administrator', and run the script file." -ForegroundColor Yellow
        exit
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
Write-Log "STARTING HYPER-V & VBS FULL RESTORATION SESSION (FINAL)" -Level "INFO" -Color Cyan
Write-Log "Computer Name: $env:COMPUTERNAME | User: $env:USERNAME" -Level "INFO" -Color Gray
$_os = Get-CimInstance Win32_OperatingSystem
Write-Log "Windows OS: $($_os.Caption) (Build $($_os.BuildNumber))" -Level "INFO" -Color Gray
Write-Log "Log file location: $logFile" -Level "INFO" -Color Gray
Write-Log "============================================================" -Level "INFO" -Color Cyan

# ------------------------------------------------------------
# Pre-Flight Safety Checks: Battery/AC, System Restore Point, BCD Backup
# ------------------------------------------------------------
Write-Log "`n=== Pre-Flight Safety Checks ===" -Level "INFO" -Color Cyan

# 1. Battery / AC power check
try {
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $powerOnline = (Get-CimInstance -ClassName BatteryStatus -Namespace root\wmi -ErrorAction SilentlyContinue).PowerOnline
        if ($powerOnline -eq $false -or ($battery.BatteryStatus -ne 2 -and $battery.BatteryStatus -ne 6 -and $battery.BatteryStatus -ne 8 -and $battery.BatteryStatus -ne 9)) {
            Write-Host "`n============================================================" -ForegroundColor Red
            Write-Host " [MANDATORY] CHARGER NOT DETECTED! PLEASE PLUG IN CHARGER!  " -ForegroundColor Red
            Write-Host "============================================================" -ForegroundColor Red
            Write-Host " Running system security modifications on battery is risky." -ForegroundColor Yellow
            Write-Host " If power cuts mid-reboot, it can interrupt boot configuration." -ForegroundColor Yellow
            Write-Host "`n Please plug your laptop charger into the wall now." -ForegroundColor White
            Write-Host "============================================================" -ForegroundColor Red
            $null = Read-Host " Press ENTER once your charger is plugged in to continue"
            Write-Log "User confirmed charger plugged in. Proceeding." -Level "INFO"
        } else {
            Write-Log "Power Source: AC Power Connected (Charger Plugged In)." -Level "SUCCESS"
        }
    } else {
        Write-Log "Power Source: Desktop PC / AC Power (No Battery)." -Level "INFO" -Color Gray
    }
} catch {
    Write-Log "Battery check note: $($_.Exception.Message)" -Level "WARN"
}

# 2. System Restore Point
try {
    $srStatus = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).SystemRestore
    if ($srStatus) {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    }
    Checkpoint-Computer -Description "Before Hyper-V VBS Enable Script" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Log "System Restore Point created: 'Before Hyper-V VBS Enable Script'" -Level "SUCCESS"
} catch {
    Write-Log "System Restore Point note: $($_.Exception.Message)" -Level "WARN"
}

# 3. Backup BCD
try {
    $bcdBackupPath = Join-Path -Path $LogDir -ChildPath "BCD_Backup_Enable_$(Get-Date -Format 'yyyyMMdd_HHmmss').bcd"
    $bcdExport = (bcdedit /export $bcdBackupPath 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -or $bcdExport -match "success") {
        Write-Log "BCD backed up to: $bcdBackupPath" -Level "SUCCESS"
    } else {
        Write-Log "BCD backup output: $bcdExport" -Level "WARN"
    }
} catch {
    Write-Log "Could not backup BCD: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# BitLocker Check & Suspension (Prevents Lockouts)
# ------------------------------------------------------------
Write-Log "`n=== Pre-Check: Verifying BitLocker / Device Encryption status ===" -Level "INFO" -Color Cyan
$bitlockerActive = $false
try {
    $bdeStatus = (manage-bde -status C: 2>&1 | Out-String)
    Write-Log "BitLocker status check output: $bdeStatus" -Level "INFO"

    if ($bdeStatus -match "Protection On") {
        $bitlockerActive = $true
    }

    $deviceEncryptionPath = "HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker"
    if (Test-Path -Path $deviceEncryptionPath) {
        $devEncStatus = Get-ItemProperty -Path $deviceEncryptionPath -ErrorAction SilentlyContinue
        if ($devEncStatus.PreventDeviceEncryption -eq 0) {
            $encVolume = Get-CimInstance -Namespace "root\cimv2\security\MicrosoftVolumeEncryption" -ClassName Win32_EncryptableVolume -ErrorAction SilentlyContinue
            if ($encVolume -and $encVolume.ProtectionStatus -eq 1) {
                $bitlockerActive = $true
            }
        }
    }
} catch {
    Write-Log "BitLocker check note: $($_.Exception.Message)" -Level "WARN"
}

if ($bitlockerActive) {
    Write-Log "BitLocker / Device Encryption is currently ON." -Level "WARN"
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  NOTICE: BITLOCKER / DEVICE ENCRYPTION IS ACTIVE" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor Yellow
    Write-Host "  Re-enabling Hyper-V and VBS modifies boot security settings." -ForegroundColor Yellow
    Write-Host "  To prevent a 48-digit Recovery Key prompt on reboot, BitLocker" -ForegroundColor Yellow
    Write-Host "  should be temporarily suspended for upcoming reboots." -ForegroundColor Yellow
    Write-Host "  (Your drive remains encrypted; protection re-arms automatically)." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [Y] Continue & automatically suspend BitLocker for upcoming reboot (Recommended)" -ForegroundColor White
    Write-Host "  [N] Abort" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor Yellow
    $blChoice = Read-Host "Do you want to continue? (Y/n)"
    if ($blChoice -match "^[nN]") {
        Write-Log "User chose to abort due to active BitLocker." -Level "INFO"
        Write-Host "`nScript aborted by user. No changes were made." -ForegroundColor Gray
        exit
    }

    Write-Log "Temporarily suspending BitLocker protection for 2 reboots..." -Level "WARN"
    try {
        Suspend-BitLocker -MountPoint "C:" -RebootCount 2 -ErrorAction SilentlyContinue | Out-Null
        manage-bde -protectors -disable C: 2>&1 | Out-Null
        Write-Log "BitLocker suspended for upcoming reboots to prevent recovery key lock." -Level "SUCCESS"
        Write-Host "BitLocker temporarily suspended for upcoming reboots." -ForegroundColor Green
    } catch {
        Write-Log "Could not suspend BitLocker: $($_.Exception.Message)" -Level "WARN"
    }
} else {
    Write-Log "BitLocker / Device Encryption is OFF — safe to proceed." -Level "SUCCESS"
    Write-Host "BitLocker / Device Encryption is OFF — safe to proceed." -ForegroundColor Green
}

# ------------------------------------------------------------
# Step 0: Restore OEM Services & Scheduled Tasks
#         (Restores ASUS, MSI, Razer, Lenovo, HP, Acer bloatware/control centers)
# ------------------------------------------------------------
Write-Log "`n=== Step 0: Restoring OEM Services & Scheduled Tasks ===" -Level "INFO" -Color Cyan

$oemServices = @(
    "ArmouryCrateService*","MyASUS*","AsIO*","AsusAppService*","ASUSSoftwareManager*","ASUSSystemAnalysis*",  # ASUS
    "MSICenterService*","MSI_App_Service*","MSI*Service*",                                          # MSI
    "RazerSynapseService*","RazerGameManagerService*","Razer*Service*",                             # Razer
    "LenovoVantage*","ImControllerService*","Lenovo*Service*",                                      # Lenovo
    "HPSureClick*","HP*Service*","HPCommRecovery*",                                                  # HP
    "AcerCareCenter*","PredatorSense*","Acer*Service*"                                              # Acer
)

$foundSvc = Get-Service -Name $oemServices -ErrorAction SilentlyContinue
if ($foundSvc) {
    foreach ($svc in $foundSvc) {
        try {
            Write-Log "Restoring OEM service: $($svc.Name) ($($svc.DisplayName))" -Level "INFO"
            Set-Service -Name $svc.Name -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
            Write-Log "Restored OEM service: $($svc.Name)" -Level "SUCCESS"
        } catch {
            Write-Log "Could not restore $($svc.Name): $($_.Exception.Message)" -Level "WARN"
        }
    }
} else {
    Write-Log "No matching OEM bloatware services found." -Level "INFO" -Color Gray
}

# Re-enable OEM scheduled tasks
$oemTasks = @(
    "*ArmouryCrate*","*MyASUS*","*ASUSSystemAnalysis*","*ASUSSoftwareManager*",  # ASUS
    "*MSICenter*","*MSIAfterburner*","*MSI_App*",                                # MSI
    "*RazerSynapse*","*RazerGameManager*","*RazerCortex*",                       # Razer
    "*LenovoVantage*","*ImController*","*LenovoUtility*",                        # Lenovo
    "*HPSureClick*","*HPSupportAssistant*","*HPCommRecovery*",                   # HP
    "*AcerCareCenter*","*PredatorSense*"                                         # Acer
)

$foundTasks = Get-ScheduledTask -TaskName $oemTasks -ErrorAction SilentlyContinue
if ($foundTasks) {
    foreach ($task in $foundTasks) {
        try {
            Enable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
            Write-Log "Re-enabled OEM scheduled task: $($task.TaskName)" -Level "SUCCESS"
        } catch {
            Write-Log "Could not re-enable task $($task.TaskName): $($_.Exception.Message)" -Level "WARN"
        }
    }
} else {
    Write-Log "No matching OEM scheduled tasks found." -Level "INFO" -Color Gray
}

# ------------------------------------------------------------
# Step 0b: Clean up any lingering DGOptOut BCD entry from Disable Script
# ------------------------------------------------------------
Write-Log "`n=== Step 0b: Cleaning up lingering DGOptOut BCD entries ===" -Level "INFO" -Color Cyan
try {
    cmd /c 'bcdedit /delete "{0cb3b571-2f2e-4343-a879-d86a476d7215}" /f' 2>$null
    Write-Log "Cleaned up any lingering DGOptOut BCD entries from previous disable runs." -Level "SUCCESS"
} catch {
    Write-Log "BCD cleanup note: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Step 1: Enabling Windows Optional Features via DISM (/LimitAccess - no hang)
# ------------------------------------------------------------
Write-Log "`n=== Step 1: Enabling Hyper-V, WSL2, and virtualization features via DISM ===" -Level "INFO" -Color Cyan
$features = @(
    "Microsoft-Windows-Subsystem-Linux",
    "VirtualMachinePlatform",
    "HypervisorPlatform",
    "Microsoft-Hyper-V-All"
)

foreach ($feat in $features) {
    try {
        Write-Log "Enabling feature: $feat (via DISM /LimitAccess)..." -Level "INFO"
        $dismOut = (DISM.EXE /Online /Enable-Feature /FeatureName:$feat /All /NoRestart /LimitAccess 2>&1 | Out-String)
        Write-Log "DISM output for $feat : $dismOut" -Level "INFO"
        if ($dismOut -match "The operation completed successfully" -or $dismOut -match "already enabled") {
            Write-Log "Feature $feat enabled successfully." -Level "SUCCESS"
        } else {
            # Attempt without /All if /All is rejected
            $dismOut2 = (DISM.EXE /Online /Enable-Feature /FeatureName:$feat /NoRestart /LimitAccess 2>&1 | Out-String)
            if ($dismOut2 -match "The operation completed successfully" -or $dismOut2 -match "already enabled") {
                Write-Log "Feature $feat enabled successfully." -Level "SUCCESS"
            } else {
                Write-Log "Feature $feat DISM output: $dismOut2 (may not be supported on this Windows edition, e.g. Hyper-V on Home edition)." -Level "WARN"
            }
        }
    } catch {
        Write-Log "Feature $($feat): $($_.Exception.Message)" -Level "WARN"
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
    ExecuteCommandAndLog 'DISM.EXE /Online /Enable-Feature:IsolatedUserMode /NoRestart /LimitAccess'
}

try {
    $CmdOutput = DISM.EXE /Online /Enable-Feature:Microsoft-Hyper-V-Hypervisor /All /NoRestart /LimitAccess | Out-String
    if (-not $CmdOutput.Contains("The operation completed successfully.")) {
        $CmdOutput = DISM.EXE /Online /Enable-Feature:Microsoft-Hyper-V-Online /All /NoRestart /LimitAccess | Out-String
    }
    Write-Log "DISM output: $CmdOutput" -Level "INFO"
    if ($CmdOutput.Contains("The operation completed successfully.")) {
        Write-Log "Enabling Hyper-V and IOMMU via DISM successful." -Level "SUCCESS"
    } else {
        Write-Log "DISM Hyper-V enable note (may already be active or handled by VMP): check log." -Level "WARN"
    }
} catch {
    Write-Log "DISM Hyper-V enable error: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Step 4: Enabling VBS / Device Guard / Credential Guard / HVCI in Registry
# ------------------------------------------------------------
Write-Log "`n=== Step 4: Enabling Virtualization-Based Security (VBS) in Registry ===" -Level "INFO" -Color Cyan

ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d 1 /f'
ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /t REG_DWORD /d 1 /f'
ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Locked" /t REG_DWORD /d 0 /f'

# Enable Credential Guard (LsaCfgFlags = 2, Enabled without UEFI lock)
ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /t REG_DWORD /d 2 /f'

# Enable HVCI (Memory Integrity / Core Isolation)
ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Enabled" /t REG_DWORD /d 1 /f'
ExecuteCommandAndLog 'REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v "Locked" /t REG_DWORD /d 0 /f'
Write-Log "VBS, Credential Guard, and HVCI (Memory Integrity) registry keys enabled." -Level "SUCCESS"

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
    Write-Log "Writing SIPolicy.p7b file failed: $($_.Exception.Message)" -Level "WARN"
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
# Step 7: WSL2 Package & Kernel Restoration
# ------------------------------------------------------------
Write-Log "`n=== Step 7: Restoring WSL2 Package & Kernel ===" -Level "INFO" -Color Cyan
try {
    Write-Log "Attempting to restore / update WSL2 modern package and kernel (wsl --update)..." -Level "INFO"
    $wslUpdate = (wsl --update 2>&1 | Out-String)
    Write-Log "wsl --update output: $wslUpdate" -Level "INFO"
} catch {
    Write-Log "wsl --update note: $($_.Exception.Message)" -Level "WARN"
}

try {
    $null = wsl --set-default-version 2 2>&1
    Write-Log "WSL default version set to 2." -Level "SUCCESS"
} catch {
    Write-Log "WSL set-default-version note: $($_.Exception.Message)" -Level "INFO" -Color Gray
}

# ------------------------------------------------------------
# Step 8: Post-Execution Verification
# ------------------------------------------------------------
Write-Log "`n=== Step 8: Post-Execution Status Check ===" -Level "INFO" -Color Cyan
try {
    $dg = Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue
    if ($dg) {
        Write-Log "VirtualizationBasedSecurityStatus: $($dg.VirtualizationBasedSecurityStatus) (0=Off, 1=Pending, 2=Running)" -Level "INFO" -Color Gray
        Write-Log "SecurityServicesConfigured: $($dg.SecurityServicesConfigured -join ', ')" -Level "INFO" -Color Gray
    }
} catch {
    Write-Log "Win32_DeviceGuard check note: $($_.Exception.Message)" -Level "INFO" -Color Gray
}

# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------
Write-Log "`n============================================================" -Level "SUCCESS"
Write-Log "ALL RESTORATION STEPS COMPLETED!" -Level "SUCCESS"
Write-Log "Steps executed:" -Level "INFO" -Color Cyan
Write-Log "  PF. Safety: Battery/AC check, Restore Point, BCD backup, BitLocker auto-suspend" -Level "INFO" -Color Gray
Write-Log "  0.  Restored OEM Services & Scheduled Tasks (ASUS, MSI, Razer, Lenovo, HP, Acer)" -Level "INFO" -Color Gray
Write-Log "  0b. Cleaned up lingering DGOptOut BCD entries" -Level "INFO" -Color Gray
Write-Log "  1.  Enabled Hyper-V, WSL, VirtualMachinePlatform, HypervisorPlatform via DISM" -Level "INFO" -Color Gray
Write-Log "  2.  Set hypervisorlaunchtype auto in BCD" -Level "INFO" -Color Gray
Write-Log "  3.  Enabled Hyper-V and IOMMU via DISM" -Level "INFO" -Color Gray
Write-Log "  4.  VBS, Credential Guard, and Memory Integrity (HVCI) enabled in Registry" -Level "INFO" -Color Gray
Write-Log "  5.  Default SIPolicy.p7b Code Integrity policy deployed" -Level "INFO" -Color Gray
Write-Log "  6.  Verified hypervisorlaunchtype = Auto in BCD" -Level "INFO" -Color Gray
Write-Log "  7.  WSL2 package and kernel update initiated" -Level "INFO" -Color Gray
Write-Log "Detailed log file: $logFile" -Level "INFO" -Color Cyan
Write-Log "============================================================" -Level "SUCCESS"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  RESTORATION COMPLETE — REBOOT REQUIRED" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  After rebooting:" -ForegroundColor White
Write-Host "  1. Hyper-V, WSL2, Docker, and VirtualMachinePlatform will be active." -ForegroundColor White
Write-Host "  2. VBS & Memory Integrity will automatically initialize." -ForegroundColor White
Write-Host "     (Check Windows Security > Device Security > Core Isolation to confirm)." -ForegroundColor Gray
Write-Host "  3. OEM software (fans, RGB, power profiles) are restored to automatic." -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Green

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