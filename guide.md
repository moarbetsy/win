
## The "Unbreakable" Developer Workstation Guide**

Target Specs: Intel i7 / 16GB RAM / Windows 11 Pro  
Stack: Cursor, Rust, Go, Bun, Node.js  
Philosophy: 100% Isolation (No global dependency messes).

## ---

**Phase 1: The Clean Up (OS Optimization)**

*Goal: Free up RAM by removing Windows bloat before we install tools.*

1. Right-click the Start Menu and select **Terminal (Admin)**.  
2. Run the **Chris Titus Tech** tool:  
   PowerShell  
   irm christitus.com/win | iex

3. **Tweaks Tab (Critical Settings):**  
   * Select **"Desktop"** from the top menu.  
   * **CHECK these:** Run O\&O ShutUp10, Disable Telemetry, Disable Bing in Search.  
   * **UNCHECK these (Do NOT remove):** App Installer (Required for Winget), Microsoft Store (Required for Terminal).  
   * Click **Run Tweaks**.  
4. **Updates Tab:** Select **"Security (Recommended)"**.  
5. Close the tool.

## ---

**Phase 2: UI Sanity (ExplorerPatcher)**

*Goal: Fix the Windows 11 Taskbar so you can see your open windows clearly.*

1. In your Admin Terminal, run:  
   PowerShell  
   winget install \-\-id valinet.ExplorerPatcher

2. Your screen will flash grey/black for 10 seconds. **This is normal.**  
3. Once the desktop returns, right-click the Taskbar \-\> **Properties**.  
4. **Apply these settings:**  
   * **Taskbar Style:** Windows 10  
   * **Combine taskbar icons:** Never combine (Crucial for coding).  
   * **System Tray:** Enable Show seconds.

## ---

**Phase 3: The "Guardian" Installation Script**

*Goal: Install the Development Stack and the "Guardian" tools (uv and fnm) that prevent system rot.*

1. Open **Notepad**.  
2. Copy the code block below completely.  
3. Save the file to your Desktop as **setup.ps1**.

PowerShell

\<\#  
.SYNOPSIS  
    Master Developer Setup \- December 2025 Edition  
    Installs: Cursor, Rust, Go, Bun.  
    Integrates: 'uv' & 'fnm' for dependency safety.  
    Utilities: RapidEE, ExplorerPatcher, 7Zip.  
\#\>  
$ErrorActionPreference \= "Stop"

\# \--- 1\. Admin Check \---  
if (\-not (\[Security.Principal.WindowsPrincipal\]\[Security.Principal.WindowsIdentity\]::GetCurrent()).IsInRole(\[Security.Principal.WindowsBuiltInRole\]::Administrator)) {  
    Write-Host "Please run as Administrator\!" \-ForegroundColor Red; exit  
}

\# \--- 2\. The Safe Tool List \---  
$Apps \= @(  
    \# Core Utilities  
    "Microsoft.PowerShell"  
    "Git.Git"  
    "7zip.7zip"  
    "Rafaellw.RapidEnvironmentEditor" \# Visual PATH Editor  
      
    \# C++ Build Tools (Essential for Rust)  
    "Microsoft.VisualStudio.2022.BuildTools"  
    "Microsoft.VisualCpp.Redist.2015-2022"

    \# The "Guardians" (Prevent Dependency Hell)  
    "astral-sh.uv"       \# Python Project Manager  
    "Schniz.fnm"         \# Node Version Manager

    \# Modern Runtimes  
    "Oven-sh.Bun"        \# Bun  
    "GoLang.Go"          \# Go  
    "Rustlang.Rustup"    \# Rust Installer

    \# Editor & Terminal  
    "Anysphere.Cursor"  
    "Microsoft.WindowsTerminal"  
    "JanDeDobbeleer.OhMyPosh"  
    "ShaunH.CaskaydiaCoveNerdFont" \# Required for Icons  
)

\# \--- 3\. Installation Loop \---  
Write-Host "Installing Safe Stack..." \-ForegroundColor Cyan  
foreach ($app in $Apps) {  
    Write-Host "Processing $app..." \-NoNewline  
    try {  
        winget install \-\-id $app \-\-exact \-\-accept-source-agreements \-\-accept-package-agreements \-\-silent \-\-no-upgrade  
        Write-Host " \[OK\]" \-ForegroundColor Green  
    } catch {  
        Write-Host " \[Check if installed\]" \-ForegroundColor Yellow  
    }  
}

\# \--- 4\. Profile Configuration \---  
Write-Host "Configuring PowerShell Environment..." \-ForegroundColor Cyan  
$ProfilePath \= $PROFILE  
if (\-not (Test-Path $ProfilePath)) { New-Item \-Path $ProfilePath \-ItemType File \-Force | Out-Null }

$Content \= @'  
\# \--- Master Dev Config \---

\# 1\. Oh My Posh Theme  
if (Get-Command oh-my-posh \-ErrorAction SilentlyContinue) {  
    oh-my-posh init pwsh \--config "$env:POSH\_THEMES\_PATH\\kushal.omp.json" | Invoke-Expression  
}

\# 2\. FNM (Fast Node Manager) \- Auto-switch Node versions  
if (Get-Command fnm \-ErrorAction SilentlyContinue) {  
    fnm env \--use-on-cd | Invoke-Expression  
}

\# 3\. Path Fixes (Crucial for Go/Rust/Bun)  
$env:PATH \+= ";$env:USERPROFILE\\go\\bin"  
$env:PATH \+= ";$env:USERPROFILE\\.bun\\bin"  
$env:PATH \+= ";$env:USERPROFILE\\.cargo\\bin"

\# 4\. Aliases  
Set-Alias ll Get-ChildItem  
Set-Alias g git  
Set-Alias c cursor  
Set-Alias ree "C:\\Program Files\\RapidEE\\RapidEE.exe"  
'@

Add-Content \-Path $ProfilePath \-Value $Content  
Write-Host "Setup Complete\! PLEASE REBOOT NOW." \-ForegroundColor Green

4. Right-click setup.ps1 \-\> **Run with PowerShell**.  
5. **REBOOT YOUR COMPUTER.**

## ---

**Phase 4: Manual Connections (The Glue)**

*Goal: Link Rust to the C++ tools and setup Cursor.*

### **1\. Configure Build Tools (For Rust)**

The script installed the *installer*, but you need to select the payload.

1. Open Start Menu \-\> **Visual Studio Installer**.  
2. Click **Modify** on "Visual Studio Build Tools 2022".  
3. Check **\[x\] Desktop development with C++**.  
4. Click **Install** (This downloads the Linker that Rust needs).

### **2\. Activate Rust**

Open your Terminal and run:

PowerShell

rustup default stable\-x86\_64-pc-windows-msvc  
rustc \-\-version

*(If it returns a version number, Rust is working).*

### **3\. Configure Cursor (JSON)**

Open Cursor \-\> **Ctrl+Shift+P** \-\> "Open Settings (JSON)". Paste this:

JSON

{  
  "editor.fontFamily": "'CaskaydiaCove NF', Consolas, monospace",  
  "editor.fontLigatures": true,  
  "terminal.integrated.fontFamily": "'CaskaydiaCove NF'",  
  "go.useLanguageServer": true,  
  "rust-analyzer.checkOnSave.command": "clippy",  
  // Auto-detect 'uv' environments  
  "python.defaultInterpreterPath": ".venv/Scripts/python.exe"  
}

## ---

**Phase 5: The "No-Break" Workflow**

*Goal: Learn the new commands so you never pollute your system again.*

### **Python Projects (Using uv)**

Old Bad Habit: Running pip install pandas globally.  
New Safe Habit:

1. mkdir my-project \-\> cd my-project  
2. uv init (Creates project).  
3. uv add pandas (Installs pandas **only** in this folder).  
4. uv run main.py

### **Node Projects (Using fnm)**

Old Bad Habit: Installing Node from the website.  
New Safe Habit:

1. fnm install \--lts (Install Node once).  
2. fnm use lts (Activate it).  
3. npm install (Works as normal, but sandboxed).

## ---

**Phase 6: Maintenance & Performance**

*Goal: Keep the 16GB RAM machine fast.*

### **1\. Defender Exclusions (Huge Speed Boost)**

Every time you compile Rust, Windows Defender scans thousands of new files, slowing you down.

1. Go to **Windows Security** \-\> **Virus & threat protection**.  
2. **Manage Settings** \-\> **Exclusions**.  
3. Add Folder: C:\\Users\\YourName\\Code (Or wherever you keep projects).

### **2\. Visualizing PATH (RapidEE)**

If your terminal ever says "Command Not Found":

1. Type ree in your terminal (Alias we created for Rapid Environment Editor).  
2. Look at the **User Variables** (Right side).  
3. If you see **RED** text, that path is dead. Right-click \-\> Delete.  
4. This keeps your startup time fast.

### **3\. Emergency ExplorerPatcher Removal**

If a Windows Update breaks your taskbar (screen flashes black):

1. Ctrl \+ Alt \+ Delete \-\> Task Manager.  
2. Run New Task \-\> ep\_setup.exe /uninstall.  
3. This resets the GUI to default immediately.
