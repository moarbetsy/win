
# Windows Developer Workstation Setup
### Smart Package Management

![Platform](https://img.shields.io/badge/platform-Windows_10%2F11-blue)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A production-grade, idempotent bootstrapping script designed to turn a fresh Windows installation into a fully configured developer workstation. It handles package installation, system hardening, WSL setup, and environment configuration with support for unattended execution.

---

## Features

*   **Smart Package Management**: Primary installation via `winget` with an automatic fallback to **Chocolatey** if Winget fails.
*   **Idempotent Design**: Safe to run multiple times; detects installed software and skips unnecessary steps.
*   **JSONC Configuration**: Fully customizable via external configuration files that support comments.
*   **Automated WSL Setup**: Handles Windows Subsystem for Linux prerequisites and auto-resumes installation after rebooting.
*   **UI & Environment**: Configures Windows Terminal (Nerd Fonts), VS Code extensions, Oh My Posh, and Explorer tweaks.
*   **System Hardening**: Enables Long Paths, Developer Mode, and unhides file extensions.

---

## Prerequisites

*   **OS**: Windows 10 (Version 1809+) or Windows 11.
*   **Privileges**: Must be run as Administrator (script will auto-elevate if launched as user).
*   **Internet**: Required for downloading packages.

---

## Usage

### 1. Standard Run
Simply run the script to start the interactive setup.
```powershell
.\setup.ps1
```

### 2. Unattended Mode (CI/CD Friendly)
Runs without user prompts and handles reboots automatically if needed.
```powershell
.\setup.ps1 -Unattended
```

### 3. Using a Custom Manifest
Override the default toolchain with your own JSON/JSONC config file.
```powershell
.\setup.ps1 -ManifestPath "C:\Configs\my-dev-setup.jsonc"
```

### 4. Upgrade Everything
Updates all existing Winget packages before starting the setup.
```powershell
.\setup.ps1 -UpgradeAll
```

---

## Configuration (Manifest)

You can customize the setup by passing a `.json` or `.jsonc` file to the `-ManifestPath` parameter. You only need to include the keys you want to override (shallow merge).

**Example `custom-manifest.jsonc`:**

```jsonc
{
    "Features": {
        "WSL": true,
        "Fonts": true,
        // Disable VS Code extension setup
        "VSCodeConfig": false
    },
    "WingetPackages": [
        "Git.Git",
        "OpenJS.NodeJS.LTS",
        "Microsoft.VisualStudioCode",
        // Add custom tools
        "Mozilla.Firefox",
        "GoLang.Go"
    ],
    "VSCodeExtensions": [
        "ms-vscode.PowerShell",
        "golang.go"
    ]
}
```

---

## Default Software Stack

If no manifest is provided, the script installs the following "Batteries Included" stack:

| Category | Tools |
| :--- | :--- |
| **Core** | Git, 7-Zip, PowerShell 7 |
| **Runtimes** | Node.js (LTS), Python 3.12, .NET 8 SDK |
| **Editors** | VS Code (with ESLint, Prettier, Docker extensions) |
| **Terminal** | Windows Terminal, Oh My Posh, CaskaydiaCove Nerd Font |
| **Utils** | Docker Desktop, PowerToys |

---

## Command Line Parameters

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `-Unattended` | Switch | Runs without prompts. Reboots automatically if required (unless `-NoReboot` is used). |
| `-UpgradeAll` | Switch | Runs `winget upgrade --all` before installing new packages. |
| `-ManifestPath` | String | Path to a local JSON/JSONC file to override defaults. |
| `-NoReboot` | Switch | Prevents the script from rebooting automatically in Unattended mode. |
| `-EnableChocolateyFallback` | Bool | Default `$true`. Installs Chocolatey if a Winget package fails. |

---

## Logging

Logs are automatically generated for every run.
*   **Location:** `$env:TEMP\DevSetup_YYYYMMDD-HHmm.log`
*   **Details:** Contains timestamps, success/failure status, and error traces.

---

## Troubleshooting

**Winget not found?**
The script attempts to locate `winget.exe` automatically in `AppLocal` or `Program Files`. If it fails, ensure App Installer is updated via the Microsoft Store.

**Reboot Loop?**
The script uses the Registry key `HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce` to resume after a reboot (specifically for WSL). If the script keeps running on boot, delete the `DevSetupResume` registry value.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.
