# ============================================================
# Full Hyper-V / VBS / Device Guard Disable Script (ASUS & Win 11 Optimized)
# Windows 11 24H2 / 23H2 - Standalone with IT Logging
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
# Helper: ExecuteCommandAndLog
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
$script:logFile = Join-Path -Path $LogDir -ChildPath "Disable_HyperV_VBS_Log.txt"
$logFile = $script:logFile

# Start IT Log Session
Write-Log "============================================================" -Level "INFO" -Color Cyan
Write-Log "STARTING HYPER-V & VBS DISABLE SESSION" -Level "INFO" -Color Cyan
Write-Log "Computer Name: $env:COMPUTERNAME | User: $env:USERNAME" -Level "INFO" -Color Gray
$_os = Get-CimInstance Win32_OperatingSystem
Write-Log "Windows OS: $($_os.Caption) (Build $($_os.BuildNumber))" -Level "INFO" -Color Gray
Write-Log "Log file location: $logFile" -Level "INFO" -Color Gray
Write-Log "============================================================" -Level "INFO" -Color Cyan

# ------------------------------------------------------------
# Pre-Flight Safety: Battery/AC check, System Restore Point, BCD Backup
# ------------------------------------------------------------
Write-Log "`n=== Pre-Flight Safety Checks ===" -Level "INFO" -Color Cyan

# 1. Battery / AC power check
try {
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        $powerOnline = (Get-CimInstance -ClassName BatteryStatus -Namespace root\wmi -ErrorAction SilentlyContinue).PowerOnline
        if ($powerOnline -eq $false -or ($battery.BatteryStatus -ne 2 -and $battery.BatteryStatus -ne 6 -and $battery.BatteryStatus -ne 8 -and $battery.BatteryStatus -ne 9)) {
            Write-Host "`n============================================================" -ForegroundColor Yellow
            Write-Host " [WARNING] CHARGER NOT DETECTED! RUNNING ON BATTERY!        " -ForegroundColor Yellow
            Write-Host "============================================================" -ForegroundColor Yellow
            Write-Host " Running system firmware & security modifications on battery" -ForegroundColor Yellow
            Write-Host " is risky. Please plug in your charger." -ForegroundColor White
            Write-Host "============================================================" -ForegroundColor Yellow
            $chargerChoice = Read-Host " Do you want to continue anyway? (y/N)"
            if ($chargerChoice -notmatch "^[yY]") {
                Write-Log "User chose to abort because charger is not connected." -Level "INFO"
                Write-Host "`nScript aborted by user. Please connect charger and re-run." -ForegroundColor Gray
                exit
            }
            Write-Log "User chose to continue on battery." -Level "WARN"
        } else {
            Write-Log "Power Source: AC Power Connected (Charger Plugged In)." -Level "SUCCESS"
        }
    } else {
        Write-Log "Power Source: Desktop PC / AC Power." -Level "INFO" -Color Gray
    }
} catch {
    Write-Log "Battery check note: $($_.Exception.Message)" -Level "WARN"
}

# 2. Create System Restore Point
try {
    $srStatus = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).SystemRestore
    if ($srStatus) {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
    }
    Checkpoint-Computer -Description "Before Hyper-V VBS Disable Script" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-Log "System Restore Point created: 'Before Hyper-V VBS Disable Script'" -Level "SUCCESS"
} catch {
    Write-Log "Could not create System Restore Point (may be disabled on system): $($_.Exception.Message)" -Level "WARN"
}

# 3. Backup BCD
try {
    $bcdBackupPath = Join-Path -Path $LogDir -ChildPath "BCD_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').bcd"
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
# Step 0: Detect OEM manufacturer & disable OEM bloatware (ASUS optimization included)
# ------------------------------------------------------------
Write-Log "`n=== Step 0: Detecting OEM manufacturer & disabling OEM services ===" -Level "INFO" -Color Cyan
try {
    $mfr = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
    Write-Log "Detected manufacturer: $mfr" -Level "INFO" -Color Gray
} catch {
    $mfr = "Unknown"
}

$oemServices = @(
    "ArmouryCrateService*","MyASUS*","AsIO*","AsusAppService*","ASUSSoftwareManager*","ASUSSystemAnalysis*","ASUSOptimization*","AsusSysCap*", # ASUS
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
            Write-Log "Stopping & disabling OEM service: $($svc.Name)" -Level "WARN"
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Log "Disabled: $($svc.Name)" -Level "SUCCESS"
        } catch {
            Write-Log "Could not disable $($svc.Name): $($_.Exception.Message)" -Level "WARN"
        }
    }
} else {
    Write-Log "No matching OEM bloatware services running." -Level "INFO" -Color Gray
}

# Disable OEM scheduled tasks
$oemTasks = @(
    "*ArmouryCrate*","*MyASUS*","*ASUSSystemAnalysis*","*ASUSSoftwareManager*","*ASUSOptimization*",
    "*MSICenter*","*MSIAfterburner*","*MSI_App*",
    "*RazerSynapse*","*RazerGameManager*","*RazerCortex*",
    "*LenovoVantage*","*ImController*","*LenovoUtility*",
    "*HPSureClick*","*HPSupportAssistant*","*HPCommRecovery*",
    "*AcerCareCenter*","*PredatorSense*"
)
$foundTasks = Get-ScheduledTask -TaskName $oemTasks -ErrorAction SilentlyContinue
if ($foundTasks) {
    foreach ($task in $foundTasks) {
        try {
            Disable-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -ErrorAction Stop | Out-Null
            Write-Log "Disabled task: $($task.TaskName)" -Level "SUCCESS"
        } catch {
            Write-Log "Could not disable task $($task.TaskName): $($_.Exception.Message)" -Level "WARN"
        }
    }
}

# ------------------------------------------------------------
# Step 0b: Shut down WSL
# ------------------------------------------------------------
Write-Log "`n=== Step 0b: Shutting down WSL ===" -Level "INFO" -Color Cyan
try {
    $wslExe = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslExe) {
        wsl --shutdown 2>&1 | Out-Null
        Write-Log "WSL shut down." -Level "SUCCESS"
    }
} catch {
    Write-Log "WSL note: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Pre-Check: BitLocker / Device Encryption
# ------------------------------------------------------------
Write-Log "`n=== Pre-Check: Checking BitLocker status ===" -Level "INFO" -Color Cyan
$bitlockerActive = $false
try {
    $bdeStatus = (manage-bde -status C: 2>&1 | Out-String)
    if ($bdeStatus -match "Protection On") {
        $bitlockerActive = $true
    }
} catch {
    Write-Log "BitLocker query note: $($_.Exception.Message)" -Level "WARN"
}

if ($bitlockerActive) {
    Write-Host "`n[WARNING] BitLocker / Device Encryption is active on C:!" -ForegroundColor Yellow
    Write-Host "Temporarily suspending BitLocker for 2 reboots..." -ForegroundColor Cyan
    try {
        Suspend-BitLocker -MountPoint "C:" -RebootCount 2 -ErrorAction SilentlyContinue | Out-Null
        manage-bde -protectors -disable C: 2>&1 | Out-Null
        Write-Log "BitLocker suspended for 2 reboots." -Level "SUCCESS"
    } catch {
        Write-Log "Could not suspend BitLocker: $($_.Exception.Message)" -Level "WARN"
    }
} else {
    Write-Log "BitLocker is OFF." -Level "SUCCESS"
}

# ------------------------------------------------------------
# Step 1: Stopping Hyper-V services
# ------------------------------------------------------------
Write-Log "`n=== Step 1: Stopping Hyper-V services ===" -Level "INFO" -Color Cyan
try {
    $hvServices = Get-Service | Where-Object { $_.DisplayName -like "*Hyper-V*" -and $_.Status -eq "Running" }
    foreach ($svc in $hvServices) {
        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
        Write-Log "Stopped service: $($svc.Name)" -Level "SUCCESS"
    }
} catch {
    Write-Log "Hyper-V services stop note: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Step 2: Disabling Hyper-V and VirtualMachinePlatform features via DISM
# ------------------------------------------------------------
Write-Log "`n=== Step 2: Disabling Windows Hypervisor Features via DISM ===" -Level "INFO" -Color Cyan
$features = @(
    "Microsoft-Hyper-V-All",
    "HypervisorPlatform",
    "VirtualMachinePlatform",
    "Microsoft-Windows-Subsystem-Linux"
)

foreach ($feat in $features) {
    try {
        Write-Log "Disabling feature: $feat..." -Level "INFO"
        $dismOut = (DISM.EXE /Online /Disable-Feature /FeatureName:$feat /NoRestart /LimitAccess 2>&1 | Out-String)
        if ($dismOut -match "The operation completed successfully" -or $dismOut -match "already disabled" -or $dismOut -match "is unknown") {
            Write-Log "$feat disabled (or already absent)." -Level "SUCCESS"
        } else {
            Write-Log "$feat result: $dismOut" -Level "WARN"
        }
    } catch {
        Write-Log "Error disabling $feat: $($_.Exception.Message)" -Level "WARN"
    }
}

# ------------------------------------------------------------
# Step 3: Setting hypervisorlaunchtype to off in BCD
# ------------------------------------------------------------
Write-Log "`n=== Step 3: Setting hypervisorlaunchtype off in BCD ===" -Level "INFO" -Color Cyan
try {
    $bcdOut = (bcdedit /set hypervisorlaunchtype off 2>&1 | Out-String).Trim()
    Write-Log "bcdedit /set hypervisorlaunchtype off -> $bcdOut" -Level "SUCCESS"
} catch {
    Write-Log "Failed to set hypervisorlaunchtype: $($_.Exception.Message)" -Level "ERROR"
}

# ------------------------------------------------------------
# Step 4: Disabling VBS in Registry
# ------------------------------------------------------------
Write-Log "`n=== Step 4: Disabling VBS in Registry ===" -Level "INFO" -Color Cyan
try {
    $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
    if (-not (Test-Path -Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
    Set-ItemProperty -Path $dgPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $dgPath -Name "RequirePlatformSecurityFeatures" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $dgPath -Name "Locked" -Value 0 -Type DWord -Force
    Write-Log "Registry VBS parameters set to 0." -Level "SUCCESS"
} catch {
    Write-Log "VBS registry update error: $($_.Exception.Message)" -Level "ERROR"
}

ExecuteCommandAndLog 'REG DELETE "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "EnableVirtualizationBasedSecurity" /f'
ExecuteCommandAndLog 'REG DELETE "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "RequirePlatformSecurityFeatures" /f'
ExecuteCommandAndLog 'REG DELETE "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "Locked" /f'
ExecuteCommandAndLog 'REG DELETE "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v "HypervisorEnforcedCodeIntegrity" /f'
ExecuteCommandAndLog 'REG DELETE "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /f'

# ------------------------------------------------------------
# Step 5: Disabling Memory Integrity (Core Isolation / HVCI)
# ------------------------------------------------------------
Write-Log "`n=== Step 5: Disabling Memory Integrity (HVCI) in Registry ===" -Level "INFO" -Color Cyan
try {
    $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
    if (-not (Test-Path -Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
    Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value 0 -Type DWord -Force
    Write-Log "HVCI Enabled set to 0." -Level "SUCCESS"
} catch {
    Write-Log "HVCI registry error: $($_.Exception.Message)" -Level "ERROR"
}

# ------------------------------------------------------------
# Step 6: Clearing Credential Guard and Policies
# ------------------------------------------------------------
Write-Log "`n=== Step 6: Clearing Credential Guard and Policies ===" -Level "INFO" -Color Cyan
ExecuteCommandAndLog 'REG DELETE "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v "LsaCfgFlags" /f'

$dgPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard"
if (Test-Path -Path $dgPolicyPath) {
    Remove-Item -Path $dgPolicyPath -Recurse -Force -ErrorAction SilentlyContinue
    Write-Log "Removed GPO DeviceGuard key." -Level "SUCCESS"
}

# ------------------------------------------------------------
# Step 7: Disabling Hyper-V Hypervisor via DISM
# ------------------------------------------------------------
Write-Log "`n=== Step 7: Disabling Hyper-V Hypervisor via DISM ===" -Level "INFO" -Color Cyan
try {
    $CmdOutput = DISM.EXE /Online /disable-Feature /FeatureName:Microsoft-Hyper-V-Hypervisor /NoRestart | Out-String
    Write-Log "DISM Hypervisor disable: $CmdOutput" -Level "INFO"
} catch {
    Write-Log "DISM Hypervisor note: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Step 8: Configuring UEFI Opt-Out via SecConfig.efi
# ------------------------------------------------------------
Write-Log "`n=== Step 8: Configuring UEFI Opt-Out via SecConfig.efi ===" -Level "INFO" -Color Cyan
$secConfigSrc = "$env:windir\System32\SecConfig.efi"
if (Test-Path -Path $secConfigSrc) {
    $freeDrive = $null
    $efiMounted = $false
    try {
        $availableLetters = 90..69 | ForEach-Object { [char]$_ + ":" } | Where-Object { -not (Test-Path -Path $_) }
        if ($availableLetters) {
            $freeDrive = $availableLetters[0]
            mountvol $freeDrive /s
            $efiMounted = $true

            $efiBootDir = "$freeDrive\EFI\Microsoft\Boot"
            if (-not (Test-Path -Path $efiBootDir)) {
                New-Item -ItemType Directory -Path $efiBootDir -Force | Out-Null
            }
            Copy-Item -Path $secConfigSrc -Destination "$efiBootDir\SecConfig.efi" -Force

            cmd /c 'bcdedit /create "{0cb3b571-2f2e-4343-a879-d86a476d7215}" /d "DGOptOut" /application osloader' 2>$null
            bcdedit /set '{0cb3b571-2f2e-4343-a879-d86a476d7215}' path "\EFI\Microsoft\Boot\SecConfig.efi" | Out-Null
            bcdedit /set '{0cb3b571-2f2e-4343-a879-d86a476d7215}' loadoptions "DISABLE-LSA-ISO,DISABLE-VBS" | Out-Null
            bcdedit /set '{0cb3b571-2f2e-4343-a879-d86a476d7215}' device "partition=$freeDrive" | Out-Null
            bcdedit /set '{bootmgr}' bootsequence '{0cb3b571-2f2e-4343-a879-d86a476d7215}' | Out-Null

            Write-Log "UEFI Opt-Out configured for next boot." -Level "SUCCESS"
        }
    } catch {
        Write-Log "SecConfig.efi configuration error: $($_.Exception.Message)" -Level "WARN"
    } finally {
        if ($efiMounted -and $freeDrive) {
            mountvol $freeDrive /d 2>$null
        }
    }
}

# ------------------------------------------------------------
# Step 9: Disable Fast Startup (Crucial for ASUS Laptops)
# ------------------------------------------------------------
Write-Log "`n=== Step 9: Disabling Fast Startup (Ensures Clean Hypervisor Reload) ===" -Level "INFO" -Color Cyan
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0 -Type DWord -Force
    Write-Log "Fast Startup disabled." -Level "SUCCESS"
} catch {
    Write-Log "Could not disable Fast Startup in registry: $($_.Exception.Message)" -Level "WARN"
}

# ------------------------------------------------------------
# Summary & Critical ASUS VivoBook Instructions
# ------------------------------------------------------------
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host " SCRIPT COMPLETED! CRITICAL INSTRUCTIONS FOR ASUS VIVOBOOK:     " -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""
Write-Host " 1. UEFI OPT-OUT SCREEN DURING REBOOT:" -ForegroundColor Yellow
Write-Host "    When your ASUS Vivobook restarts, a black/blue screen will appear:" -ForegroundColor White
Write-Host "    'Do you want to disable Credential Guard?'" -ForegroundColor Gray
Write-Host "    >>> Press the [WINDOWS KEY] on your keyboard (OR Fn + F3)! <<<" -ForegroundColor Cyan
Write-Host "    (Do NOT just press F3 alone — ASUS keyboards default to volume/media keys!)" -ForegroundColor Yellow
Write-Host ""
Write-Host " 2. ASUS BIOS HARDWARE VIRTUALIZATION (AMD SVM / INTEL VT-x):" -ForegroundColor Yellow
Write-Host "    If your ASUS has an AMD Ryzen CPU (very common on VivoBooks):" -ForegroundColor White
Write-Host "    - Reboot -> tap [F2] repeatedly to enter BIOS" -ForegroundColor White
Write-Host "    - Press [F7] for Advanced Mode" -ForegroundColor White
Write-Host "    - Go to Advanced -> CPU Configuration -> SVM Mode -> set to [ENABLED]" -ForegroundColor Cyan
Write-Host "    - (For Intel VivoBooks: Advanced -> CPU Configuration -> Intel Virtualization Technology -> ENABLED)" -ForegroundColor Gray
Write-Host "    - Press [F10] to Save and Exit" -ForegroundColor White
Write-Host ""
Write-Host " 3. WINDOWS SECURITY GUI (MEMORY INTEGRITY):" -ForegroundColor Yellow
Write-Host "    In Windows 11 (24H2), Microsoft Tamper Protection blocks script changes." -ForegroundColor White
Write-Host "    Open Start Menu -> 'Windows Security' -> 'Device Security'" -ForegroundColor White
Write-Host "    -> Click 'Core isolation details' -> Toggle Memory Integrity to [OFF]" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Green
Write-Host ""

$rebootResp = Read-Host "Would you like to restart now? (y/N)"
if ($rebootResp -match "^[yY]") {
    Write-Host "Restarting system in 5 seconds... Remember to press the WINDOWS KEY or Fn+F3 on the prompt screen!" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Host "Please restart your laptop manually to apply changes." -ForegroundColor Yellow
}
