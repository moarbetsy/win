<#
.SYNOPSIS
    Automated Developer Workstation Setup (2026 Lean Edition - v3.2)
    *FIXED: Nerd Font ID and NuGet Silent Install*

.DESCRIPTION
    1. System Tweaks (Explorer, Dev Mode, Dev Drive).
    2. Winget Operations (Hardened).
    3. Package Installs (Apps/Runtimes).
    4. Runtime Config (Git, Bun, UV).
    5. Cursor Editor Setup.
    6. Shell Customization (Oh My Posh, Nerd Fonts).
#>

[CmdletBinding()]
param(
    [switch]$Unattended,
    [switch]$UpgradeAll,
    [switch]$NoReboot
)

# ---------------------------------------------------------------------------
# 0. Configuration
# ---------------------------------------------------------------------------

$script:StartTime      = Get-Date
$LogPath               = "$env:TEMP\DevSetup_$(Get-Date -Format 'yyyyMMdd-HHmm').log"
$script:RebootRequired = $false

# Named winget exit codes
$WINGET_ALREADY_INSTALLED = -1978335189
$WINGET_REBOOT_REQUIRED   = -1978335215

$Config = @{
    Apps = @(
        # System & Core
        "Microsoft.PowerShell"
        # Removed DevHome (often pre-installed or flagged as missing)

        # Runtimes & CLIs
        "Git.Git"
        "OpenJS.NodeJS.LTS"
        "Python.Python.3.13"                # 2026 Stable
        "Microsoft.DotNet.SDK.10"           # 2026 LTS
        "Oven-sh.Bun"                       # JS Runtime
        "astral-sh.uv"                      # Python Manager (Fast)
        "Gyan.FFmpeg"
        "7zip.7zip"

        # Terminals & Shell
        "Microsoft.WindowsTerminal"
        "JanDeDobbeleer.OhMyPosh"
        "NerdFonts.CaskaydiaCove"           # FIXED: Updated Package ID

        # Editors & IDEs
        "Anysphere.Cursor"
        "Notepad++.Notepad++"

        # Virtualization
        "Docker.DockerDesktop"
    )

    CursorExtensions = @(
        "ms-python.python",
        "charliermarsh.ruff",
        "oven.bun-vscode",
        "esbenp.prettier-vscode",
        "dbaeumer.vscode-eslint",
        "ms-azuretools.vscode-docker",
        "bradlc.vscode-tailwindcss",
        "eamodio.gitlens",
        "editorconfig.editorconfig",
        "GitHub.copilot"
    )

    GitBaseDir = "$env:USERPROFILE"
}

# ---------------------------------------------------------------------------
# 1. Logging & Elevation
# ---------------------------------------------------------------------------

try { Start-Transcript -Path $LogPath -Append -ErrorAction SilentlyContinue | Out-Null } catch {}

function Log-Message {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet("INFO","WARN","ERROR","SUCCESS")][string]$Type = "INFO",
        [ConsoleColor]$Color = "White"
    )
    switch ($Type) {
        "ERROR"   { $Color = "Red" }
        "WARN"    { $Color = "Yellow" }
        "SUCCESS" { $Color = "Green" }
        "INFO"    { $Color = "Cyan" }
    }
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] [$Type] $Message" -ForegroundColor $Color
}

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log-Message "Requesting Administrator privileges..." -Type WARN
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
    if ($Unattended) { $argList += "-Unattended" }
    if ($UpgradeAll) { $argList += "-UpgradeAll" }
    if ($NoReboot)   { $argList += "-NoReboot" }
    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit
}

function Invoke-WithRetry {
    param([scriptblock]$ScriptBlock, [string]$When = "operation")
    for ($i=0; $i -le 2; $i++) {
        try { return & $ScriptBlock }
        catch {
            if ($i -lt 2) { Start-Sleep -Seconds 5 } else { throw }
        }
    }
}

function Update-Environment {
    Log-Message "Refreshing environment variables..." -Type INFO
    foreach ($level in 'Machine','User') {
        [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
            if ($_.Key -eq 'Path') {
                $curr = [Environment]::GetEnvironmentVariable('Path', 'Process') -split ';'
                $new = ($curr + ($_.Value -split ';')) | Select-Object -Unique | Where-Object { $_ }
                [Environment]::SetEnvironmentVariable('Path', ($new -join ';'), 'Process')
            } else {
                [Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'Process')
            }
        }
    }
}

# ---------------------------------------------------------------------------
# 2. System Tweaks
# ---------------------------------------------------------------------------

Log-Message "=== Developer Workstation Setup (Fixed Edition) ===" -Type INFO

Log-Message "[1/6] System Tweaks..." -Type INFO
try {
    # Force Bootstrap NuGet Provider (Fixes the prompt you saw)
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction SilentlyContinue

    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "Hidden" -Value 1 -ErrorAction SilentlyContinue
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -PropertyType DWord -Value 1 -Force | Out-Null
    New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -PropertyType DWord -Value 1 -Force | Out-Null
} catch {}

# Dev Drive Check
$devDrive = Get-Volume | Where-Object { $_.FileSystem -eq "ReFS" -or $_.DriveLabel -match "Dev" } | Select-Object -First 1
if ($devDrive) {
    $Config.GitBaseDir = "$($devDrive.DriveLetter):"
    Log-Message "Dev Drive detected on $($devDrive.DriveLetter):." -Type SUCCESS
}

# ---------------------------------------------------------------------------
# 3. Winget Operations
# ---------------------------------------------------------------------------

Log-Message "[2/6] Installing Packages..." -Type INFO

function Install-WingetApp {
    param([string]$Id)
    Log-Message "Installing: $Id" -Type INFO
    $args = @("install", "--id", $Id, "-e", "--silent", "--accept-source-agreements", "--accept-package-agreements", "--no-upgrade")
    $proc = Start-Process -FilePath "winget" -ArgumentList $args -PassThru -Wait -NoNewWindow
    if ($proc.ExitCode -eq $WINGET_REBOOT_REQUIRED) { $script:RebootRequired = $true }
}

foreach ($app in $Config.Apps) {
    Invoke-WithRetry -When "Install $app" -ScriptBlock { Install-WingetApp -Id $app }
}
Update-Environment

# ---------------------------------------------------------------------------
# 4. Runtime & Tooling
# ---------------------------------------------------------------------------

Log-Message "[3/6] Configuring Runtimes..." -Type INFO

if (Get-Command git -ErrorAction SilentlyContinue) {
    git config --global init.defaultBranch "main"
    git config --global core.autocrlf input
    
    $cursorCmd = Get-Command cursor -ErrorAction SilentlyContinue
    if ($cursorCmd) { git config --global core.editor "cursor --wait" }
    
    $repoPath = Join-Path $Config.GitBaseDir "source"
    if (-not (Test-Path $repoPath)) { New-Item -ItemType Directory -Path $repoPath -Force | Out-Null }
    git config --global --add safe.directory $repoPath
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
    Log-Message "Configuring uv..." -Type INFO
    try { uv python install 3.13 2>$null } catch {}
}

# ---------------------------------------------------------------------------
# 5. Cursor Editor Setup
# ---------------------------------------------------------------------------

Log-Message "[4/6] Setting up Cursor IDE..." -Type INFO

$cursorCmd = if (Get-Command cursor -ErrorAction SilentlyContinue) { "cursor" } else { "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe" }

if (Get-Command $cursorCmd -ErrorAction SilentlyContinue) {
    Log-Message "Installing Extensions..." -Type INFO
    foreach ($ext in $Config.CursorExtensions) {
        $list = & $cursorCmd --list-extensions
        if ($list -notcontains $ext) {
            Log-Message " - Installing $ext" -Type INFO
            & $cursorCmd --install-extension $ext --force | Out-Null
        }
    }
}

# ---------------------------------------------------------------------------
# 6. Shell & Profile
# ---------------------------------------------------------------------------

Log-Message "[5/6] Updating Shell Profile..." -Type INFO

# Now safe to install modules without prompt
Install-Module -Name "posh-git" -Force -AllowClobber -Scope CurrentUser -ErrorAction SilentlyContinue
Install-Module -Name "Terminal-Icons" -Force -AllowClobber -Scope CurrentUser -ErrorAction SilentlyContinue

$profilePath = $PROFILE.CurrentUserAllHosts
if (-not (Test-Path $profilePath)) { New-Item -Path $profilePath -Force | Out-Null }

$profileBlock = @'
#region DevSetup
Import-Module posh-git -ErrorAction SilentlyContinue
Import-Module Terminal-Icons -ErrorAction SilentlyContinue

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\kushal.omp.json" | Invoke-Expression
}

if (Get-Command bun -ErrorAction SilentlyContinue) {
    $env:BUN_INSTALL = "$env:USERPROFILE\.bun"
    $env:Path = "$env:BUN_INSTALL\bin;$env:Path"
    if (Test-Path "$env:BUN_INSTALL\_bun") { . "$env:BUN_INSTALL\_bun" }
}

if (Get-Command uv -ErrorAction SilentlyContinue) {
    uv generate-shell-completion powershell | Out-String | Invoke-Expression
}

Set-Alias ll Get-ChildItem
Set-Alias g git
Set-Alias code cursor
#endregion
'@

$curr = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($curr -notmatch "#region DevSetup") {
    Add-Content -Path $profilePath -Value "`n$profileBlock"
    Log-Message "PowerShell profile patched." -Type SUCCESS
}

# ---------------------------------------------------------------------------
# 7. Finalize
# ---------------------------------------------------------------------------

Log-Message "[6/6] Patching Terminal Font..." -Type INFO
$wtPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wtPath) {
    $content = Get-Content $wtPath -Raw
    # Ensure we use the exact name provided by NerdFonts package
    if ($content -notmatch "CaskaydiaCove NF") {
        $content = $content -replace '"face":\s*".*?"', '"face": "CaskaydiaCove NF"'
        Set-Content -Path $wtPath -Value $content
        Log-Message "Windows Terminal font updated." -Type SUCCESS
    }
}

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
$elapsed = [math]::Round(((Get-Date) - $script:StartTime).TotalMinutes, 1)
Log-Message "=== Setup Complete (${elapsed}m) ===" -Type SUCCESS

if ($script:RebootRequired -and -not $Unattended) {
    $ans = Read-Host "Reboot recommended. Restart now? (y/n)"
    if ($ans -eq 'y') { Restart-Computer }
} elseif ($script:RebootRequired -and -not $NoReboot) {
    Restart-Computer
}
