# Windows 11 (26H2 / 24H2) Hyper-V, VBS & Device Guard Switch Utility
### Complete Disable & Restoration Suite

[![OS: Windows 11](https://img.shields.io/badge/OS-Windows%2011%20(26H2%20%7C%2024H2)-0078D6?logo=windows)](https://www.microsoft.com/windows)
[![PowerShell: 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)](https://github.com/PowerShell/PowerShell)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tested On: ASUS, MSI, Lenovo, Dell, HP, Razer](https://img.shields.io/badge/Hardware-ASUS%20%7C%20MSI%20%7C%20Lenovo%20%7C%20HP%20%7C%20Razer-orange)](#-oem-bloatware-management)

A production-grade, standalone PowerShell toolkit engineered to **toggle and fully control** **Hyper-V, Virtualization-Based Security (VBS), Memory Integrity (HVCI), and Credential Guard** on Windows 11 (specifically tailored for **26H2** and **24H2**).

Available in both `.ps1` (direct execution) and `.txt` (script repository / copy-paste) formats.

---

## 📦 Suite Components

| File Name | Format | Purpose | Description |
| :--- | :---: | :---: | :--- |
| **`Disable_HyperV_VBS_Final.ps1`** | PowerShell | **Disable** | Releases kernel hypervisor lock for VMware, EVE-NG, GNS3, VirtualBox |
| **`Disable_HyperV_VBS_Final.txt`** | Text | **Disable** | Plain-text copy of the disable script |
| **`Enable_HyperV_VBS_Final.ps1`** | PowerShell | **Restore / Enable** | Fully restores Hyper-V, VBS, HVCI, Credential Guard, WSL2 & OEM apps |
| **`Enable_HyperV_VBS_Final.txt`** | Text | **Restore / Enable** | Plain-text copy of the enable script |

---

## 📑 Table of Contents
- [Why This Suite Is Needed](#-why-this-suite-is-needed)
- [Key Features](#-key-features)
  - [Disable Script Features](#-disable-script-features)
  - [Enable Script Features](#-enable-script-features)
- [Compatibility](#-compatibility)
- [Pre-Execution Safety & Warnings](#-pre-execution-safety--warnings)
- [How to Use](#-how-to-use)
  - [Option A: Disabling Hyper-V & VBS (For Emulators / EVE-NG)](#-option-a-disabling-hyper-v--vbs-for-emulators--eve-ng)
  - [Option B: Re-Enabling Hyper-V & VBS (Restoring Security & Docker/WSL2)](#-option-b-re-enabling-hyper-v--vbs-restoring-security--dockerwsl2)
- [ASUS Laptop / VivoBook Specific Instructions](#-asus-laptop--vivobook-specific-instructions)
- [Emergency Rollback & Recovery](#-emergency-rollback--recovery)
- [Execution Logs](#-execution-logs)
- [Disclaimer](#-disclaimer)

---

## ❓ Why This Suite Is Needed

In Windows 11 builds (24H2 / 26H2), Microsoft strictly enforces hardware virtualization extensions (**Intel VT-x / AMD SVM**) via the kernel hypervisor and System Guard.

* **When you need to Disable:** Running nested hypervisors and networking labs (such as **EVE-NG**, **GNS3**, **VMware Workstation**, or Android emulators) triggers conflicts such as:
  * `"VMware Workstation does not support nested virtualization on this host"`
  * `"Device Guard/Credential Guard is in conflict"`
  * Severe emulation lag and inability to run 64-bit nested VMs.
  * OEM software (ASUS Armoury Crate, Lenovo Vantage, MSI Center, etc.) secretly re-enables VBS upon reboot.

* **When you need to Enable:** Returning your system back to normal requires more than just ticking boxes in Windows Features:
  * Restoring Windows BCD hypervisor launch configuration.
  * Restoring Memory Integrity (Core Isolation) & Credential Guard.
  * Restoring WSL2 and Linux subsystem kernels.
  * Unfreezing and starting manufacturer OEM fan controls, power modes, and RGB background services.

---

## 🚀 Key Features

### 🛡️ Pre-Flight Safety Shield (Both Scripts)
* **AC Power Check:** Strictly verifies your laptop is plugged into the wall charger before modifying UEFI boot sequences or security policies.
* **Automated System Restore Point:** Creates a snapshot checkpoint before making any changes.
* **BCD Backup:** Automatically exports an instantaneous BCD backup to `C:\DGLogs\BCD_Backup_*.bcd`.
* **Safe BitLocker Protection:** Detects BitLocker or modern Device Encryption. Rather than risking a 48-digit recovery key prompt on boot, it automatically suspends BitLocker for upcoming reboots (`Suspend-BitLocker -RebootCount 2`).

### 🔻 Disable Script Features
* **Built for Windows 11 26H2 & 24H2:** Bypasses Store-version WSL2 and DISM hangs using `/LimitAccess`.
* **Deep Clean Hypervisor Tear-Down:**
  * Stops Hyper-V background services.
  * Removes Hyper-V, HypervisorPlatform, VirtualMachinePlatform, and WSL2 via DISM.
  * Sets BCD `hypervisorlaunchtype off`.
  * Wipes VBS and Memory Integrity (HVCI) registry keys.
  * Clears Credential Guard LSA flags and active WDAC `.cip` policies.
  * Injects UEFI Opt-Out via `SecConfig.efi` (prompting F3 on reboot).
* **OEM Bloatware Suppression:** Disables background services and scheduled tasks from **ASUS**, **MSI**, **Lenovo**, **Razer**, **HP**, and **Acer** that attempt to restore VBS.

### 🔺 Enable Script Features
* **Full Restoration:**
  * Sets BCD `hypervisorlaunchtype auto`.
  * Re-enables Hyper-V, HypervisorPlatform, VirtualMachinePlatform, and WSL features via DISM.
  * Cleans up any leftover `SecConfig.efi` or `DGOptOut` BCD entries.
  * Restores VBS, Credential Guard (`LsaCfgFlags = 2`), and Memory Integrity (`Enabled = 1`).
  * Deploys the default Microsoft `SIPolicy.p7b` Code Integrity policy.
* **OEM Services & Tasks Re-Activation:** Automatically re-enables and starts OEM management software (ASUS Armoury Crate / MyASUS, MSI Center, Lenovo Vantage, Razer Synapse, HP Sure Click, Acer Care Center). Your fan profiles, power modes, and lighting work properly again.
* **WSL2 Package & Kernel Recovery:** Restores the modern Store WSL2 package and kernel via `wsl --update`.

---

## 💻 Compatibility

| Operating System | Support Status | Notes |
| :--- | :---: | :--- |
| **Windows 11 26H2** | **Fully Tested** | Overrides deep kernel hypervisor locks |
| **Windows 11 24H2** | **Fully Tested** | Solves Store WSL2 & DISM hang issues |
| **Windows 11 23H2 / 22H2** | **Fully Tested** | Full automated toggle |
| **Windows 10 (64-bit)** | **Supported** | Backward compatible |

---

## ⚠️ Pre-Execution Safety & Warnings

> [!WARNING]
> ### 1. Windows Hello PIN / Microsoft Account Notice (When Disabling)
> Disabling VBS and clearing Credential Guard alters Local Security Authority (LSA) tokens.
> * If you log in with a **Microsoft Account PIN**, Windows may ask you to **"Set up your PIN again"** on the first reboot.
> * **Ensure you know your Microsoft account password or have access to your verification email/phone before running the disable script.**

> [!IMPORTANT]
> ### 2. Keep Laptop Plugged into Charger
> System boot settings and security configurations are written on reboot. Running either script on low battery can interrupt the BCD or UEFI sequence.

---

## 🛠️ How to Use

### 🔻 Option A: Disabling Hyper-V & VBS (For Emulators / EVE-NG)

1. Open **PowerShell as Administrator** (Right-click Start $\rightarrow$ *Terminal (Admin)* or *PowerShell (Admin)*).
2. Set execution policy:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Run the disable script:
   ```powershell
   .\Disable_HyperV_VBS_Final.ps1
   ```
4. Follow the interactive prompts and confirm reboot with **Y**.
5. **During reboot:** When the black or blue UEFI screen appears asking to disable Credential Guard, **press F3 (or Fn + F3 / Windows Key)** to confirm.

---

### 🔺 Option B: Re-Enabling Hyper-V & VBS (Restoring Security & Docker/WSL2)

1. Open **PowerShell as Administrator**.
2. Set execution policy:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
3. Run the enable script:
   ```powershell
   .\Enable_HyperV_VBS_Final.ps1
   ```
4. Confirm BitLocker auto-suspension if prompted.
5. Choose **Y** to restart your PC.
6. Once rebooted, Hyper-V, WSL2, Docker support, Memory Integrity (Core Isolation), and your OEM laptop tools will be fully operational.

> [!TIP]
> If running from a `.txt` file, simply rename `Enable_HyperV_VBS_Final.txt` to `.ps1`, or copy and paste the code into an elevated PowerShell terminal.

---

## 💻 ASUS Laptop / VivoBook Specific Instructions

On ASUS laptops (VivoBook, ZenBook, ROG, TUF):

1. **UEFI Prompt Confirmation (Disable Step):**
   * ASUS keyboards assign `F1`–`F12` to multimedia keys by default.
   * Press **`Windows Key`** or **`Fn` + `F3`** (do not just tap `F3`).
2. **Enable Hardware Virtualization in BIOS:**
   * Restart laptop $\rightarrow$ tap **`F2`** to enter BIOS.
   * Press **`F7`** for *Advanced Mode*.
   * **For AMD Ryzen CPUs:** *Advanced* $\rightarrow$ *CPU Configuration* $\rightarrow$ set **SVM Mode** to **`Enabled`**.
   * **For Intel CPUs:** *Advanced* $\rightarrow$ *CPU Configuration* $\rightarrow$ set **Intel (VMX) Virtualization Technology** to **`Enabled`**.
   * Press **`F10`** to Save and Exit.

---

## 🔄 Emergency Rollback & Recovery

If you ever need to restore previous system state manually:

### Method 1: System Restore (Recommended)
1. At the login screen, hold the **`Shift`** key and click **Power** $\rightarrow$ **Restart**.
2. Select **Troubleshoot** $\rightarrow$ **Advanced Options** $\rightarrow$ **System Restore**.
3. Select the restore point (`Before Hyper-V VBS Disable Script` or `Before Hyper-V VBS Enable Script`).
4. Complete the wizard.

### Method 2: Restore BCD Boot Configuration
```cmd
bcdedit /import C:\DGLogs\BCD_Backup_<timestamp>.bcd
```

---

## 📝 Execution Logs

All operations, status checks, and registry edits are logged with timestamps:
* **Log Directory:** `C:\DGLogs\`
* **Disable Log:** `C:\DGLogs\Disable_HyperV_VBS_Log.txt`
* **Enable Log:** `C:\DGLogs\Enable_HyperV_VBS_Log.txt`
* **BCD Backups:** `C:\DGLogs\BCD_Backup_*.bcd`

---

## ⚖️ Disclaimer

This utility is designed for developers, systems engineers, and network lab practitioners who need granular control over hardware virtualization (Intel VT-x / AMD SVM). Disabling VBS, HVCI, and Credential Guard reduces kernel-level memory isolation. Re-enabling restores Microsoft recommended security baselines. Use at your own discretion in development and production environments.
