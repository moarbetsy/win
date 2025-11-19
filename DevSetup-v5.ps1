<#
.SYNOPSIS
    Automated Developer Workstation Setup (Ultimate Edition - v2.2)

.DESCRIPTION
    Orchestrates a full developer environment setup:
    1. System Tweaks (Explorer, Developer Mode, Long Paths).
    2. Winget hardening (sources, optional global upgrade, retries).
    3. Package Installs (apps/runtimes/CLIs).
    4. Runtime Configuration (Node/Corepack, Python, Git).
    5. Editor Setup (VS Code + extensions).
    6. Shell Customization (PowerShell profile, Oh My Posh, Nerd Fonts).
    7. Windows Terminal defaults (font auto-patch; JSONC-safe).

    Idempotent: safe to re-run.

.PARAMETER Unattended
    Skips confirmation prompts.

.PARAMETER UpgradeAll
    Runs 'winget upgrade --all' before installs.

.PARAMETER NoReboot
    Prevents automatic reboot in Unattended mode.
#>

[CmdletBinding()]
param(
    [switch]$Unattended,
    [switch]$UpgradeAll,
    [switch]$NoReboot
)

# ---------------------------------------------------------------------------
# 0. Configuration (Edit to customize your stack)
# ---------------------------------------------------------------------------

$script:StartTime        = Get-Date
$LogPath                 = "$env:TEMP\DevSetup_$(Get-Date -Format 'yyyyMMdd-HHmm').log"
$script:RebootRequired   = $false

# Named winget exit codes for readability
$WINGET_ALREADY_INSTALLED = -1978335189  # 0x8A15002B
$WINGET_REBOOT_REQUIRED   = -1978335215  # 0x8A150011

$Config = @{
    Apps = @(
        # Core Runtimes & CLI
        "Microsoft.PowerShell"
        "Git.Git"
        "OpenJS.NodeJS.LTS"
        "Python.Python.3.12"
        "Microsoft.DotNet.SDK.8"
        "Gyan.FFmpeg"
        "7zip.7zip"

        # Terminals & Shell
        "Microsoft.WindowsTerminal"
        "JanDeDobbeleer.OhMyPosh"
        "ShaunH.CaskaydiaCoveNerdFont"      # REQUIRED for Oh My Posh icons

        # Editors & IDEs
        "Microsoft.VisualStudioCode"
        "Anysphere.Cursor"
        "Notepad++.Notepad++"

        # Tools & Utilities
        "Docker.DockerDesktop"
        "Microsoft.PowerToys"
        "RamenSoftware.Windhawk"

        # Communication / Media
        "Discord.Discord"
        "Telegram.TelegramDesktop"
        "OBSProject.OBSStudio"
        "Figma.Figma"
    )

    VSExtensions = @(
        "ms-python.python",
        "esbenp.prettier-vscode",
        "dbaeumer.vscode-eslint",
        "ms-azuretools.vscode-docker",
        "ritwickdey.LiveServer",
        "bradlc.vscode-tailwindcss",
        "vscode-icons-team.vscode-icons",
        "eamodio.gitlens",
        "editorconfig.editorconfig"
    )

    GitSafeDirs = @(
        "$env:USERPROFILE\source",
        "$env:USERPROFILE\src",
        "$env:USERPROFILE\projects",
        "$env:USERPROFILE\repos"
    )

    # Will be filtered (yarn/pnpm) when Corepack is present.
    NpmGlobals = @("yarn", "pnpm", "typescript", "neovim")
}

# ---------------------------------------------------------------------------
# 1. Logging, Elevation, Utilities
# ---------------------------------------------------------------------------

$ErrorActionPreference = 'Continue'
try { Start-Transcript -Path $LogPath -Append -ErrorAction SilentlyContinue | Out-Null } catch {}

function Log-Message {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS")][string]$Type = "INFO",
        [ConsoleColor]$Color = "White"
    )
    if ($Type -eq "ERROR") { $Color = "Red" }
    elseif ($Type -eq "WARN") { $Color = "Yellow" }
    elseif ($Type -eq "SUCCESS") { $Color = "Green" }
    $timestamp = Get-Date -Format "HH:mm:ss"
    $line = "[$timestamp] [$Type] $Message"
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $LogPath -Value $line -ErrorAction SilentlyContinue
}

# Self-Elevation
$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log-Message "Requesting Administrator privileges..." -Type WARN
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($Unattended) { $argList += "-Unattended" }
    if ($UpgradeAll) { $argList += "-UpgradeAll" }
    if ($NoReboot)   { $argList += "-NoReboot" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs | Out-Null
    exit
}

# Helpers
function Refresh-Environment {
    Log-Message "Refreshing process environment variables..." -Type INFO
    $machinePath  = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
    $userPath     = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
    $combinedPath = ($userPath + $machinePath | Where-Object { $_ -and $_.Trim() -ne '' } | Select-Object -Unique) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $combinedPath, 'Process')

    foreach ($loc in 'Machine','User') {
        $vars = [Environment]::GetEnvironmentVariables($loc)
        foreach ($name in $vars.Keys) {
            if ($name -eq 'Path') { continue }
            [Environment]::SetEnvironmentVariable($name, $vars[$name], 'Process')
        }
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [int]$Retries = 2,
        [int]$DelaySeconds = 5,
        [string]$When = "operation"
    )
    for ($i=0; $i -le $Retries; $i++) {
        try {
            return & $ScriptBlock
        } catch {
            if ($i -lt $Retries) {
                Log-Message "Retrying $When in $DelaySeconds s... ($($i+1)/$($Retries+1))" -Type WARN
                Start-Sleep -Seconds $DelaySeconds
            } else {
                throw
            }
        }
    }
}

function Test-PendingReboot {
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending"
    )
    $pending = $false
    foreach ($k in $keys) {
        if (Test-Path $k) { $pending = $true; break }
    }
    $pfro = "HKLM:\System\CurrentControlSet\Control\Session Manager"
    try {
        $val = (Get-ItemProperty -Path $pfro -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue)
        if ($val) { $pending = $true }
    } catch {}
    return $pending
}

# JSON with comments helper (Windows Terminal uses JSONC)
function ConvertFrom-JsonC {
    param([Parameter(Mandatory)][string]$Text)
    $noLine  = [regex]::Replace($Text, '^\s*//.*$', '', 'Multiline')
    $noBlock = [regex]::Replace($noLine, '/\*.*?\*/', '', 'Singleline')
    # Heuristic removal of dangling commas (common in JSONC)
    $noComma = [regex]::Replace($noBlock, ',\s*(?=[}\]])', '')
    return $noComma | ConvertFrom-Json
}

# ---------------------------------------------------------------------------
# 2. System Tweaks & Pre-Flight
# ---------------------------------------------------------------------------

Log-Message "=== Developer Workstation Setup Started ===" -Type INFO
Log-Message "Log File: $LogPath" -Type INFO

$ExplorerNeedsRestart = $false

Log-Message "[1/7] Configuring Windows & Explorer..." -Type INFO
try {
    # Explorer: show file extensions & hidden files
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -ErrorAction SilentlyContinue
    $ExplorerNeedsRestart = $true
    # Developer Mode
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -PropertyType DWord -Value 1 -Force | Out-Null
    # Long paths
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -PropertyType DWord -Value 1 -Force | Out-Null
    Log-Message "System tweaks applied." -Type SUCCESS
} catch {
    Log-Message "Failed to apply one or more system tweaks: $($_.Exception.Message)" -Type WARN
}

# Ensure WSL prerequisites; optional distro install with reboot guard
Log-Message "[WSL] Checking optional features & distribution..." -Type INFO
try {
    $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    $vmFeature  = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

    if ($wslFeature.State -ne 'Enabled') {
        Log-Message "Enabling Microsoft-Windows-Subsystem-Linux..." -Type INFO
        $res = Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction Stop
        if ($res.RestartNeeded) { $script:RebootRequired = $true }
    }
    if ($vmFeature.State -ne 'Enabled') {
        Log-Message "Enabling VirtualMachinePlatform..." -Type INFO
        $res = Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction Stop
        if ($res.RestartNeeded) { $script:RebootRequired = $true }
    }

    $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($wslCmd) {
        if (-not $script:RebootRequired) {
            $dists = (& wsl.exe -l -q 2>$null) | Where-Object { $_ -and $_.Trim() -ne "" }
            if (-not ($dists -contains "Ubuntu")) {
                Log-Message "[WSL] Installing Ubuntu distribution..." -Type INFO
                try {
                    wsl.exe --install -d Ubuntu
                    $script:RebootRequired = $true
                } catch {
                    Log-Message "WSL distro install failed (possibly needs virtualization enabled in BIOS)." -Type ERROR
                }
            } else {
                Log-Message "WSL distribution 'Ubuntu' already present." -Type INFO
            }
        } else {
            Log-Message "[WSL] Features enabled; deferring distro install until after reboot." -Type WARN
        }
    }
} catch {
    Log-Message "WSL prerequisite check failed: $($_.Exception.Message)" -Type WARN
}

# ---------------------------------------------------------------------------
# 3. Winget Operations
# ---------------------------------------------------------------------------

Log-Message "[2/7] Ensuring winget is ready..." -Type INFO
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log-Message "Winget not found. Opening App Installer page..." -Type ERROR
    Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
    try { Stop-Transcript | Out-Null } catch {}
    exit 1
}

# Winget source sanity
try {
    Invoke-WithRetry -When "winget source update" -ScriptBlock { winget source update --verbose-logs | Out-Null }
    try { winget source enable msstore | Out-Null } catch {}
} catch {
    Log-Message "Winget source update failed (continuing): $($_.Exception.Message)" -Type WARN
}

# Optional global upgrade
$doUpgrade = $UpgradeAll
if (-not $UpgradeAll -and -not $Unattended) {
    $response = Read-Host "Upgrade all existing packages first? (Y/N)"
    if ($response -match '^[Yy]') { $doUpgrade = $true }
}
if ($doUpgrade) {
    Log-Message "Running 'winget upgrade --all' (include unknown)..." -Type INFO
    try { winget upgrade --all --accept-source-agreements --accept-package-agreements --include-unknown | Out-Null } catch {}
}

function Install-WingetApp {
    param([Parameter(Mandatory)][string]$Id)
    Log-Message "Processing: $Id" -Type INFO
    $argsList = @(
        "install","--id",$Id,"--exact",
        "--accept-source-agreements","--accept-package-agreements",
        "--silent","--no-upgrade"
    )
    $exit = 0
    try {
        $proc = Start-Process -FilePath "winget" -ArgumentList $argsList -PassThru -Wait -NoNewWindow
        $exit = $proc.ExitCode
    } catch {
        Log-Message " - winget invocation threw: $($_.Exception.Message)" -Type ERROR
        return "FAILED"
    }

    switch ($exit) {
        0                         { Log-Message " - Installed successfully." -Type SUCCESS; return $null }
        $WINGET_ALREADY_INSTALLED { Log-Message " - Already installed." -Type INFO; return $null }
        $WINGET_REBOOT_REQUIRED   { Log-Message " - Installed (reboot required)." -Type WARN; $script:RebootRequired = $true; return "REBOOT_REQ" }
        default                   { Log-Message " - FAILED (Exit Code: $exit)" -Type ERROR; return "FAILED" }
    }
}

Log-Message "[3/7] Installing Applications..." -Type INFO
$failedInstalls = New-Object System.Collections.ArrayList
foreach ($app in $Config.Apps) {
    $result = Invoke-WithRetry -When "install $app" -ScriptBlock { Install-WingetApp -Id $app }
    if ($result -eq "FAILED") { [void]$failedInstalls.Add($app) }
}

Refresh-Environment

# ---------------------------------------------------------------------------
# 4. Tooling Configuration (Node/Python/Git/VS Code)
# ---------------------------------------------------------------------------

Log-Message "[4/7] Configuring runtimes & tooling..." -Type INFO

# VS Code extensions
$codePath = (Get-Command code -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
if (-not $codePath) {
    $possiblePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    if (Test-Path $possiblePath) { $codePath = $possiblePath }
    elseif (Test-Path "C:\Program Files\Microsoft VS Code\bin\code.cmd") { $codePath = "C:\Program Files\Microsoft VS Code\bin\code.cmd" }
}
if ($codePath) {
    try {
        $installedExts = & $codePath --list-extensions 2>$null
        foreach ($ext in $Config.VSExtensions) {
            if ($installedExts -and ($installedExts -contains $ext)) {
                Log-Message " - VS Code extension already installed: $ext" -Type INFO
            } else {
                & $codePath --install-extension $ext --force | Out-Null
                Log-Message " - VS Code extension installed: $ext" -Type SUCCESS
            }
        }
    } catch {
        Log-Message "VS Code extension install failed: $($_.Exception.Message)" -Type WARN
    }
} else {
    Log-Message "VS Code CLI not found; skipping extensions." -Type WARN
}

# Git configuration
if (Get-Command git -ErrorAction SilentlyContinue) {
    Log-Message "Configuring Git defaults..." -Type INFO
    git config --global init.defaultBranch "main"
    git config --global core.editor "code --wait"
    git config --global core.autocrlf input
    git config --global fetch.prune true
    git config --global pull.ff only

    foreach ($path in $Config.GitSafeDirs) {
        try {
            if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
            git config --global --add safe.directory $path
        } catch { Log-Message " - Failed to add Git safe.directory: $path" -Type WARN }
    }
}

# Node / Corepack / npm globals
if (Get-Command node -ErrorAction SilentlyContinue) {
    if (Get-Command corepack -ErrorAction SilentlyContinue) {
        Log-Message "Enabling Corepack (Yarn & pnpm via Node)..." -Type INFO
        try {
            corepack enable | Out-Null
            corepack prepare yarn@stable --activate | Out-Null
            corepack prepare pnpm@latest --activate | Out-Null
        } catch { Log-Message " - Corepack prepare failed (continuing): $($_.Exception.Message)" -Type WARN }
        $npmGlobals = $Config.NpmGlobals | Where-Object { $_ -notin @('yarn','pnpm') }
    } else {
        $npmGlobals = $Config.NpmGlobals
    }

    if (Get-Command npm -ErrorAction SilentlyContinue) {
        if ($npmGlobals.Count -gt 0) {
            Log-Message "Installing global npm packages: $($npmGlobals -join ', ')" -Type INFO
            foreach ($pkg in $npmGlobals) {
                try { npm install -g $pkg | Out-Null; Log-Message " - $pkg installed." -Type SUCCESS }
                catch { Log-Message " - Failed to install npm pkg: $pkg" -Type WARN }
            }
        }
    }
}

# Python pip
if (Get-Command python -ErrorAction SilentlyContinue) {
    Log-Message "Upgrading pip/setuptools/wheel..." -Type INFO
    try { python -m pip install --upgrade pip setuptools wheel | Out-Null } catch {}
}

# ---------------------------------------------------------------------------
# 5. PowerShell Profile (Idempotent for CurrentHost & AllHosts)
# ---------------------------------------------------------------------------

Log-Message "[5/7] Updating PowerShell profiles..." -Type INFO

function Update-ProfileBlock {
    param([Parameter(Mandatory)][string]$PathToProfile)

    if (-not (Test-Path $PathToProfile)) {
        New-Item -Path $PathToProfile -ItemType File -Force | Out-Null
    }

    $regionStart = "#region AutomatedSetup"
    $regionEnd   = "#endregion"

    # Use single-quoted here-string to avoid premature variable expansion; logic runs at profile-load time.
    $block = @'
#region AutomatedSetup
# --- Added by Dev Workstation Setup (Idempotent) ---
# 1) Oh My Posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh | Invoke-Expression
}

# 2) PSReadLine QoL
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineOption -PredictionSource History -ErrorAction SilentlyContinue
    Set-PSReadLineOption -PredictionViewStyle ListView -ErrorAction SilentlyContinue
}

# 3) Aliases
Set-Alias ll Get-ChildItem
Set-Alias g git

# Make 'code' available even if CLI isn't on PATH
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    $possible = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    if (Test-Path $possible) { Set-Alias code $possible }
    elseif (Test-Path "C:\Program Files\Microsoft VS Code\bin\code.cmd") { Set-Alias code "C:\Program Files\Microsoft VS Code\bin\code.cmd" }
}
#endregion
'@

    $content = Get-Content $PathToProfile -Raw -ErrorAction SilentlyContinue
    if ($content -match [regex]::Escape($regionStart) + "(.|\n)*?" + [regex]::Escape($regionEnd)) {
        Log-Message " - Updating configuration block in: $([IO.Path]::GetFileName($PathToProfile))" -Type INFO
        $content = $content -replace ($regionStart + "(.|\n)*?" + $regionEnd), $block
    } else {
        Log-Message " - Appending configuration block in: $([IO.Path]::GetFileName($PathToProfile))" -Type INFO
        $content = ($content + "`r`n" + $block).Trim()
    }
    Set-Content -Path $PathToProfile -Value $content -Encoding UTF8
}

Update-ProfileBlock -PathToProfile $PROFILE
if ($PROFILE -ne $PROFILE.CurrentUserAllHosts) {
    Update-ProfileBlock -PathToProfile $PROFILE.CurrentUserAllHosts
}

# Ensure helpful modules (silent best-effort)
try {
    if (-not (Get-Module -ListAvailable -Name posh-git)) {
        Install-Module posh-git -Scope CurrentUser -Force -AllowClobber -ErrorAction SilentlyContinue
    }
} catch {}

# ---------------------------------------------------------------------------
# 6. Windows Terminal Defaults (Font auto-patch, JSONC-safe)
# ---------------------------------------------------------------------------

Log-Message "[6/7] Patching Windows Terminal defaults (font face)..." -Type INFO

function Update-WindowsTerminalFont {
    param([string]$FontName = "CaskaydiaCove NF")
    $paths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )

    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        try {
            $raw  = Get-Content $p -Raw
            try {
                $json = ConvertFrom-JsonC -Text $raw
            } catch {
                Log-Message " - Failed to parse JSONC in $(Split-Path -Leaf $p); leaving file unchanged." -Type WARN
                continue
            }

            if (-not $json.profiles) { $json | Add-Member -NotePropertyName profiles -NotePropertyValue (@{}) }
            if (-not $json.profiles.defaults) { $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue (@{}) }
            if (-not $json.profiles.defaults.font) { $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue (@{}) }

            $current = $json.profiles.defaults.font.face
            if ($current -ne $FontName) {
                Copy-Item $p "$p.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -ErrorAction SilentlyContinue
                $json.profiles.defaults.font.face = $FontName
                # Re-emit as JSON (no comments)
                $json | ConvertTo-Json -Depth 20 | Set-Content -Path $p -Encoding UTF8
                Log-Message " - Set font to '$FontName' in $(Split-Path -Leaf $p)." -Type SUCCESS
            } else {
                Log-Message " - Font already '$FontName' in $(Split-Path -Leaf $p)." -Type INFO
            }
        } catch {
            Log-Message " - Failed to update $p: $($_.Exception.Message)" -Type WARN
        }
    }

    Log-Message "Note: Close and reopen Windows Terminal to pick up new font settings." -Type WARN
}
Update-WindowsTerminalFont

# Explorer refresh (apply hidden/ext settings) — do this late to minimize disruption
if ($ExplorerNeedsRestart) {
    if ($Unattended) {
        try {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
            Start-Process explorer.exe | Out-Null
            Log-Message "Explorer restarted to apply settings." -Type INFO
        } catch {
            Log-Message "Could not restart Explorer automatically." -Type WARN
        }
    } else {
        Log-Message "Explorer restart recommended to apply settings." -Type WARN
    }
}

# ---------------------------------------------------------------------------
# 7. Completion & Reboot Logic
# ---------------------------------------------------------------------------

if (Test-PendingReboot) { $script:RebootRequired = $true }

$elapsed = [int]((Get-Date) - $script:StartTime).TotalMinutes
Log-Message "=== Setup Complete (elapsed ~${elapsed}m) ===" -Type SUCCESS

if ($failedInstalls.Count -gt 0) {
    Log-Message "The following apps failed to install:" -Type ERROR
    $failedInstalls | ForEach-Object { Log-Message " * $_" -Type ERROR }
}

if ($script:RebootRequired) {
    Log-Message "[Reboot pending] One or more operations require a restart." -Type WARN
}

if (-not $Unattended) {
    $restart = Read-Host "Restart computer now? (Y/N)"
    if ($restart -match '^[Yy]') { Restart-Computer }
} elseif (-not $NoReboot -and $script:RebootRequired) {
    Log-Message "Unattended mode: Restarting in 5 seconds..." -Type WARN
    Start-Sleep -Seconds 5
    Restart-Computer
}

try { Stop-Transcript | Out-Null } catch {}
