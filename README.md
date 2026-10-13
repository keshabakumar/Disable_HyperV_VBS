# Windows 11 (26H2 / 24H2) Hyper-V & VBS Complete Disable Utility

[![OS: Windows 11](https://img.shields.io/badge/OS-Windows%2011%20(26H2%20%7C%2024H2)-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tested On: ASUS, MSI, Lenovo, Dell](https://img.shields.io/badge/Hardware-ASUS%20%7C%20MSI%20%7C%20Lenovo%20%7C%20HP-orange)](#-oem-bloatware-suppression)

A robust, standalone PowerShell utility engineered to completely disable **Hyper-V, Virtualization-Based Security (VBS), Memory Integrity (HVCI), and Credential Guard** on Windows 11 (specifically updated for **26H2** and **24H2**).

In modern Windows 11 builds, Microsoft locks down hardware virtualization extensions (**Intel VT-x / AMD SVM**) via the kernel hypervisor and System Guard. This tool fully releases that lock, enabling type-2 hypervisors and network emulation labs (e.g., **VMware Workstation, VirtualBox, EVE-NG, GNS3, Android Emulators**) to run with native hardware performance and nested virtualization support.

---

## 📑 Table of Contents
- [Why This Script Is Needed](#-why-this-script-is-needed)
- [Key Features](#-key-features)
- [Compatibility](#-compatibility)
- [Pre-Execution Safety & Warnings](#-pre-execution-safety--warnings)
- [How to Use](#-how-to-use)
- [ASUS Laptop / VivoBook Specific Instructions](#-asus-laptop--vivobook-specific-instructions)
- [Emergency Rollback & Recovery](#-emergency-rollback--recovery)
- [Execution Logs](#-execution-logs)
- [Disclaimer](#-disclaimer)

---

## ❓ Why This Script Is Needed

When running virtualized networking labs like **EVE-NG**, **GNS3**, or emulators in VMware Workstation on Windows 11:
- You receive errors such as: `"VMware Workstation does not support nested virtualization on this host"` or `"Device Guard/Credential Guard is in conflict"`.
- Virtual machines run extremely slowly or fail to boot 64-bit nested guest engines.
- Even if Hyper-V is unchecked in Windows Features, Windows 11 (24H2 / 26H2) continues to run VBS in the background via Device Guard and Memory Integrity.
- OEM management tools (like ASUS Armoury Crate, MyASUS, Lenovo Vantage) quietly re-enable VBS upon system restarts.

This script terminates all layers holding the hypervisor lock in one execution.

---

## 🚀 Key Features

- **Built for Windows 11 26H2 & 24H2:** Handles aggressive kernel-isolation policies, Tamper Protection boundaries, and modern WDAC Application Control `.cip` policies.
- **Zero External Downloads:** Pure native PowerShell and Windows administrative commands (`bcdedit`, `DISM`, `mountvol`, `reg`). No external dependencies or packages needed.
- **Pre-Flight Safety Shield:**
  - Verifies laptop AC charger connection to prevent firmware power failure.
  - Automatically creates a **Windows System Restore Point** (`Before Hyper-V VBS Disable Script`).
  - Creates a timestamped **BCD backup** (`BCD_Backup_*.bcd`).
  - Scans for **BitLocker / Device Encryption** and temporarily suspends it to avoid boot loops.
- **Deep Clean Hypervisor Tear-Down:**
  - Stops Hyper-V background services.
  - Removes Hyper-V, HypervisorPlatform, VirtualMachinePlatform, and WSL2 via DISM (`/LimitAccess` prevents update hangs).
  - Configures BCD with `hypervisorlaunchtype off`.
  - Disables VBS and Memory Integrity (HVCI) in Registry.
  - Clears Credential Guard LSA flags and GPO policies.
  - Configures UEFI Opt-Out via `SecConfig.efi`.
- **OEM Bloatware Suppression:** Detects and suppresses background services and scheduled tasks from **ASUS**, **MSI**, **Lenovo**, **Razer**, **HP**, and **Acer** that attempt to restore VBS.

---

## 💻 Compatibility

| Operating System | Support Status | Notes |
| :--- | :---: | :--- |
| **Windows 11 26H2** | **Fully Tested** | Overrides deep kernel hypervisor locks |
| **Windows 11 24H2** | **Fully Tested** | Bypasses Store-version WSL2 and DISM hangs |
| **Windows 11 23H2 / 22H2** | **Fully Tested** | Full automated disable |
| **Windows 10 (64-bit)** | **Supported** | Backward compatible |

---

## ⚠️ Pre-Execution Safety & Warnings

> [!WARNING]
> ### 1. Windows Hello PIN / Microsoft Account Notice
> Disabling VBS and clearing Credential Guard alters the Local Security Authority (LSA) and hardware security tokens.
> - If you log in with a **Microsoft Account using a PIN**, Windows may prompt you to **"Set up your PIN again"** upon first reboot.
> - **Ensure you know your Microsoft account password or have access to your recovery email/phone before running this script.**

> [!IMPORTANT]
> ### 2. Keep Laptop Plugged into Charger
> Firmware and UEFI modifications are executed during boot. Running this on low battery can interrupt the BCD or UEFI opt-out sequence.

---

## 🛠️ How to Use

### Step 1: Run the Script as Administrator
1. Open **PowerShell as Administrator** (Right-click Start menu $\rightarrow$ *Terminal (Admin)* or *PowerShell (Admin)*).
2. Set execution policy for the session:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Run the script:
   ```powershell
   .\Disable_HyperV_VBS_Final.ps1
   ```
4. Follow the interactive prompts in the console.

### Step 2: System Reboot & Confirmation
When the script completes, choose **Y** to restart. During the initial reboot:
1. A black or blue UEFI confirmation screen will display:
   ```text
   Do you want to disable Credential Guard?
   ```
2. **Press the Windows Key (or Fn + F3)** to approve the change.

---

## 💻 ASUS Laptop / VivoBook Specific Instructions

On ASUS laptops (VivoBook, ZenBook, ROG, TUF):

1. **UEFI Prompt Confirmation:**
   - ASUS keyboards assign the `F1`–`F12` row to multimedia by default.
   - Do **NOT** press `F3` alone; press **`Windows Key`** or **`Fn` + `F3`**.
2. **Enable Hardware Virtualization in BIOS:**
   - Restart laptop $\rightarrow$ tap **`F2`** to enter BIOS.
   - Press **`F7`** for *Advanced Mode*.
   - **For AMD Ryzen CPUs:** Go to *Advanced* $\rightarrow$ *CPU Configuration* $\rightarrow$ set **SVM Mode** to **`Enabled`**.
   - **For Intel CPUs:** Go to *Advanced* $\rightarrow$ *CPU Configuration* $\rightarrow$ set **Intel (VMX) Virtualization Technology** to **`Enabled`**.
   - Press **`F10`** to Save and Exit.

---

## 🔄 Emergency Rollback & Recovery

If you ever need to reverse all changes or if you get locked out of your PIN:

### Method 1: System Restore (Recommended)
1. At the login screen, hold the **`Shift`** key and click **Power** $\rightarrow$ **Restart**.
2. Select **Troubleshoot** $\rightarrow$ **Advanced Options** $\rightarrow$ **System Restore**.
3. Select the point named:
   ```text
   Before Hyper-V VBS Disable Script
   ```
4. Complete the wizard. All previous security settings and PIN functionality will be instantly restored.

### Method 2: Restore BCD Boot Configuration
If your system has trouble booting:
```cmd
bcdedit /import C:\DGLogs\BCD_Backup_<timestamp>.bcd
```

---

## 📝 Execution Logs

All operations, status checks, and registry edits are logged with timestamps:
- **Default Log Directory:** `C:\DGLogs\`
- **Log File:** `C:\DGLogs\Disable_HyperV_VBS_Log.txt`
- **BCD Backup:** `C:\DGLogs\BCD_Backup_*.bcd`

---

## ⚖️ Disclaimer

This utility is designed for developers, systems engineers, and network lab practitioners who require unrestricted type-2 hardware virtualization (Intel VT-x / AMD SVM). Disabling VBS, HVCI, and Credential Guard reduces kernel-level memory isolation. Use at your own discretion in development and test environments.
