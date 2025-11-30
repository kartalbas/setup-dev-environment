<#
.SYNOPSIS
    Development environment setup script for Windows with configuration file support.

.DESCRIPTION
    This script automates the installation of development tools on Windows using Scoop
    package manager (for user-level tools) and winget (for admin-level tools).

    Tools are configured via a .config file (setup-dev-environment-windows.config by default).
    The script supports both user-level installation (no admin rights) and admin-level
    installation (requires admin rights).

.PARAMETER ToolsUserRights
    Install user-level tools using Scoop (NO ADMIN required).
    Tools are installed to the path specified in the config file.

.PARAMETER ToolsAdminRights
    Install admin-level tools using winget (REQUIRES ADMIN).
    Installs system-wide applications like Docker Desktop, browsers, etc.

.PARAMETER ForceAdmin
    Install EVERYTHING with admin rights (NOT RECOMMENDED).
    Bypasses Scoop's security restrictions. Use only when absolutely necessary.

.PARAMETER ConfigFile
    Path to custom configuration file.
    Default: setup-dev-environment-windows.config (in same directory as script)

.PARAMETER ForceInstall
    Install ONLY specified tools, ignoring config file settings.
    Useful for quick installation of specific tools.

.EXAMPLE
    .\setup-dev-environment-windows.ps1 -ToolsUserRights
    Install user-level tools (Git, Python, Node.js, etc.) without admin rights.

.EXAMPLE
    .\setup-dev-environment-windows.ps1 -ToolsAdminRights
    Install admin-level tools (Docker Desktop, browsers, etc.) - requires admin rights.

.EXAMPLE
    .\setup-dev-environment-windows.ps1 -ForceAdmin
    Install both user and admin tools with admin rights (NOT RECOMMENDED).

.EXAMPLE
    .\setup-dev-environment-windows.ps1 -ToolsUserRights -ForceInstall argocd
    Install ONLY ArgoCD, ignoring config file.

.EXAMPLE
    .\setup-dev-environment-windows.ps1 -ToolsUserRights -ForceInstall argocd,terraform,kubectl
    Install ONLY specified tools (comma-separated), ignoring config file.

.EXAMPLE
    .\setup-dev-environment-windows.ps1 -ToolsUserRights -ConfigFile "D:\my-config.config"
    Use custom configuration file.

.NOTES
    File Name      : setup-dev-environment-windows.ps1
    Version        : 0.1.0
    Author         : Development Team
    Prerequisite   : PowerShell 5.1 or higher

    Configuration File:
        Edit setup-dev-environment-windows.config to select which tools to install.
        Set to 'true' to install, 'false' to skip each tool.

    Installation Paths:
        User-level tools: Configured in config file (default: D:\bin\scoop)
        Admin-level tools: Standard system locations (Program Files, etc.)

    Recommended Workflow:
        1. Edit setup-dev-environment-windows.config
        2. Run: .\setup-dev-environment-windows.ps1 -ToolsUserRights
        3. (Optional) Run: .\setup-dev-environment-windows.ps1 -ToolsAdminRights
        4. Restart terminal to use installed tools

.LINK
    https://github.com/kartalbas/setup-dev-environment
    https://scoop.sh
    https://github.com/microsoft/winget-cli

#>

# setup-dev-environment.ps1
# Dynamic development environment setup with configuration file
# Config file: setup-dev-environment-windows.config
# Version: 4.0.1
#
# Changelog:
#

param(
    [switch]$ToolsUserRights = $false,
    [switch]$ToolsAdminRights = $false,
    [switch]$ForceAdmin = $false,
    [string]$ConfigFile = "",
    [string[]]$ForceInstall = @()
)

$ErrorActionPreference = "Continue"

# ============================================================================
# HANDLE FORCEADMIN MODE
# ============================================================================

if ($ForceAdmin) {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                   ⚠️  FORCE ADMIN MODE ENABLED  ⚠️              ║
╚════════════════════════════════════════════════════════════════╝

⚠️  WARNING: You are using Force Admin mode!

This will:
- Bypass Scoop's security restrictions
- Install ALL tools (both user and admin level)
- Run with administrator privileges

This mode is NOT RECOMMENDED for regular use.
Scoop is designed to be installed as a regular user.

Press Ctrl+C now to cancel, or
"@ -ForegroundColor Yellow
    
    Write-Host "Continuing in 5 seconds..." -ForegroundColor Red
    Start-Sleep -Seconds 5
    
    # Auto-enable both installation modes
    $ToolsUserRights = $true
    $ToolsAdminRights = $true
    
    Write-Host "`n✓ ForceAdmin mode: Both user and admin tools will be installed" -ForegroundColor Green
}

# ============================================================================
# DETERMINE CONFIG FILE PATH
# ============================================================================

if ([string]::IsNullOrEmpty($ConfigFile)) {
    $scriptPath = $PSCommandPath
    $scriptDir = Split-Path -Parent $scriptPath
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
    # Remove platform suffix if already present (e.g., 'setup-dev-environment-windows' -> 'setup-dev-environment')
    $baseName = $scriptName -replace '-windows$', '' -replace '-macos$', '' -replace '-ubuntu$', ''
    $ConfigFile = Join-Path $scriptDir "$baseName-windows.config"
}

if (-not (Test-Path $ConfigFile)) {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                     ⚠️  CONFIG FILE NOT FOUND  ⚠️               ║
╚════════════════════════════════════════════════════════════════╝

Configuration file not found: $ConfigFile

WHAT TO DO:

  1. Create a configuration file by copying the template:
     Copy-Item "setup-dev-environment-windows.config.template" "$ConfigFile"

  2. Or use a different config file:
     .\setup-dev-environment-windows.ps1 -ToolsUserRights -ConfigFile "path\to\your.config"

  3. Or use ForceInstall to install specific tools without config:
     .\setup-dev-environment-windows.ps1 -ToolsUserRights -ForceInstall git,python

EXPECTED CONFIG FILE LOCATION:
  Script directory: $scriptDir
  Config file:      $ConfigFile

For more help:
  .\setup-dev-environment-windows.ps1
  Get-Help .\setup-dev-environment-windows.ps1 -Full

"@ -ForegroundColor Red
    exit 1
}

Write-Host "📋 Using configuration file: $ConfigFile" -ForegroundColor Cyan

# ============================================================================
# PARSE CONFIG FILE
# ============================================================================

function Read-ConfigFile {
    param([string]$FilePath)
    
    $config = @{
        General = @{}
        UserLevel = @{}
        AdminLevel = @{}
    }
    
    $currentSection = ""
    $currentSubSection = ""
    
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        if ($line -match '^#' -or $line -eq '') {
            return
        }
        
        if ($line -match '^\[(.+)\]$') {
            $section = $matches[1]

            if ($section -eq 'General') {
                $currentSection = 'General'
                $currentSubSection = ''
            }
            elseif ($section -match '^General\.(.+)$') {
                $currentSection = 'General'
                $currentSubSection = $matches[1]

                if (-not $config.General.ContainsKey($currentSubSection)) {
                    $config.General[$currentSubSection] = @{}
                }
            }
            elseif ($section -match '^(UserLevel|AdminLevel)\.(.+)$') {
                $currentSection = $matches[1]
                $currentSubSection = $matches[2]

                if (-not $config[$currentSection].ContainsKey($currentSubSection)) {
                    $config[$currentSection][$currentSubSection] = @{}
                }
            }
            elseif ($section -match '^(UserLevel|AdminLevel)$') {
                $currentSection = $matches[1]
                $currentSubSection = ''
            }
        }
        elseif ($line -match '^([^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            # Strip inline comments
            if ($value -match '^([^#]+)#') {
                $value = $matches[1].Trim()
            }
            
            if ($value -eq 'true') { $value = $true }
            elseif ($value -eq 'false') { $value = $false }

            if ($currentSection -eq 'General') {
                if ($currentSubSection) {
                    $config.General[$currentSubSection][$key] = $value
                }
                else {
                    $config.General[$key] = $value
                }
            }
            elseif ($currentSubSection) {
                $config[$currentSection][$currentSubSection][$key] = $value
            }
            else {
                if (-not $config[$currentSection].ContainsKey('_root')) {
                    $config[$currentSection]['_root'] = @{}
                }
                $config[$currentSection]['_root'][$key] = $value
            }
        }
    }
    
    return $config
}

Write-Host "Parsing configuration file..." -ForegroundColor Cyan
$config = Read-ConfigFile -FilePath $ConfigFile

$installPath = $config.General.InstallPath
$isMinimal = $config.General.MinimalInstall

Write-Host "✓ Configuration loaded" -ForegroundColor Green
Write-Host "  Install Path: $installPath" -ForegroundColor Gray
Write-Host "  Minimal Mode: $isMinimal" -ForegroundColor Gray

if ($ForceInstall.Count -gt 0) {
    Write-Host "  Force Install: $($ForceInstall -join ', ')" -ForegroundColor Magenta
}

# ============================================================================
# LOAD MODULES
# ============================================================================

$scriptPath = $PSCommandPath
$scriptDir = Split-Path -Parent $scriptPath
$ModulesPath = Join-Path $scriptDir "modules\windows"

# ============================================================================
# VALIDATE PARAMETERS
# ============================================================================

if (-not $ToolsUserRights -and -not $ToolsAdminRights) {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║              📖 DEVELOPMENT ENVIRONMENT SETUP HELP             ║
╚════════════════════════════════════════════════════════════════╝

DESCRIPTION:
  Automated development environment setup for Windows using Scoop
  (user-level) and winget (admin-level) package managers.

USAGE:
  .\setup-dev-environment-windows.ps1 -ToolsUserRights
  .\setup-dev-environment-windows.ps1 -ToolsAdminRights
  .\setup-dev-environment-windows.ps1 -ForceAdmin

PARAMETERS:

  -ToolsUserRights
      Install user-level tools using Scoop (NO ADMIN required)
      Includes: Git, Python, Node.js, Docker CLI, Kubernetes tools, etc.

  -ToolsAdminRights
      Install admin-level tools using winget (REQUIRES ADMIN)
      Includes: Docker Desktop, Browsers, PowerToys, Windows Terminal, etc.

  -ForceAdmin
      Install EVERYTHING with admin rights (⚠️  NOT RECOMMENDED)
      Bypasses Scoop security restrictions. Use only when necessary.

  -ConfigFile <path>
      Use custom configuration file
      Default: setup-dev-environment-windows.config

  -ForceInstall <tool1>,<tool2>,...
      Install ONLY specified tools, ignoring config file
      Useful for quick installation of specific tools

EXAMPLES:

  # Install user-level tools (recommended first step)
  .\setup-dev-environment-windows.ps1 -ToolsUserRights

  # Install admin-level tools (run as Administrator)
  .\setup-dev-environment-windows.ps1 -ToolsAdminRights

  # Install specific tool only
  .\setup-dev-environment-windows.ps1 -ToolsUserRights -ForceInstall argocd

  # Install multiple specific tools
  .\setup-dev-environment-windows.ps1 -ToolsUserRights -ForceInstall git,python,kubectl

  # Use custom config file
  .\setup-dev-environment-windows.ps1 -ToolsUserRights -ConfigFile "D:\my-config.config"

  # Get detailed PowerShell help
  Get-Help .\setup-dev-environment-windows.ps1 -Full

CONFIGURATION:
  Edit $ConfigFile to select which tools to install.
  Set each tool to 'true' (install) or 'false' (skip).

RECOMMENDED WORKFLOW:
  1. Edit setup-dev-environment-windows.config
  2. Run: .\setup-dev-environment-windows.ps1 -ToolsUserRights
  3. Restart terminal
  4. (Optional) Run: .\setup-dev-environment-windows.ps1 -ToolsAdminRights
  5. Restart computer (if Docker Desktop was installed)

MORE HELP:
  Get-Help .\setup-dev-environment-windows.ps1 -Full
  Get-Help .\setup-dev-environment-windows.ps1 -Examples

"@ -ForegroundColor Cyan
    exit 1
}

# ============================================================================
# CHECK ADMIN STATUS - STRICT CHECK
# ============================================================================

function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isAdmin = Test-Administrator

if ($ToolsUserRights -and $isAdmin -and -not $ForceAdmin) {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                          ⚠️  ERROR  ⚠️                          ║
╚════════════════════════════════════════════════════════════════╝

You are running as Administrator!

Scoop MUST be installed as a REGULAR USER (not admin).
This is a security requirement of Scoop.

Please:
1. Close this Administrator PowerShell window
2. Open a REGULAR PowerShell:
   - Press Windows key
   - Type "PowerShell"
   - Click "Windows PowerShell" (NOT "Run as Administrator")
3. Navigate to your script directory
4. Run: .\setup-dev-environment.ps1 -ToolsUserRights

OR, if you want to bypass this check (NOT RECOMMENDED):
   .\setup-dev-environment.ps1 -ForceAdmin


"@ -ForegroundColor Red
    exit 1
}

if ($ToolsAdminRights -and -not $isAdmin) {
    Write-Host @"
╔═════════════════════════════════════════════════════════╗
║                          ERROR                          ║
╚═════════════════════════════════════════════════════════╝

Admin-level tools require administrator privileges.

Please:
1. Right-click PowerShell → "Run as Administrator"
2. Navigate to your script directory
3. Run: .\setup-dev-environment.ps1 -ToolsAdminRights

"@ -ForegroundColor Red
    exit 1
}

# ============================================================================
# BANNER
# ============================================================================

$mode = if ($ToolsUserRights) { "USER-LEVEL (No Admin)" } else { "ADMIN-LEVEL (Requires Admin)" }

Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     DEVELOPMENT ENVIRONMENT INSTALLER
║     Mode: $mode
║     Install Path: $installPath
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Start-Sleep -Seconds 2

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Write-Section {
    param([string]$Title)
    $separator = "=" * 60
    Write-Host "`n" -NoNewline
    Write-Host $separator -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host $separator -ForegroundColor Cyan
}

function Install-ScoopPackage {
    param(
        [string]$Package,
        [string]$Bucket = $null,
        [bool]$ShouldInstall = $true
    )
    
    # If ForceInstall is specified, ONLY install tools in that list
    if ($ForceInstall.Count -gt 0) {
        if ($ForceInstall -notcontains $Package) {
            return  # Silently skip tools not in ForceInstall list
        }
        Write-Host "  → Force installing $Package..." -ForegroundColor Magenta
    }
    elseif (-not $ShouldInstall) {
        Write-Host "  ⊘ Skipped $Package (disabled in config)" -ForegroundColor Gray
        return
    }
    
    if ($Bucket) {
        scoop bucket add $Bucket 2>$null
    }
    
    $installed = scoop list 2>$null | Select-String -Pattern "^$Package "
    if ($installed) {
        Write-Host "  ✓ $Package already installed" -ForegroundColor Green
    } else {
        Write-Host "  → Installing $Package..." -ForegroundColor Cyan
        $installOutput = scoop install $Package 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $Package installed" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to install $Package" -ForegroundColor Red
            # Show error output if installation failed
            if ($installOutput) {
                Write-Host "     Error: $installOutput" -ForegroundColor Red
            }
        }
    }
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$Name,
        [bool]$ShouldInstall = $true
    )
    
    # If ForceInstall is specified, ONLY install tools in that list
    if ($ForceInstall.Count -gt 0) {
        if (($ForceInstall -notcontains $Name) -and ($ForceInstall -notcontains $PackageId)) {
            return  # Silently skip tools not in ForceInstall list
        }
        Write-Host "  → Force installing $Name..." -ForegroundColor Magenta
    }
    elseif (-not $ShouldInstall) {
        Write-Host "  ⊘ Skipped $Name (disabled in config)" -ForegroundColor Gray
        return
    }
    
    Write-Host "  → Installing $Name..." -ForegroundColor Cyan
    winget install --id=$PackageId --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ $Name installed" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ $Name installation may have failed (sometimes normal)" -ForegroundColor Yellow
    }
}

function Install-BeyondCompare {
    param(
        [bool]$ShouldInstall = $true
    )
    
    # If ForceInstall is specified, ONLY install tools in that list
    if ($ForceInstall.Count -gt 0) {
        if ($ForceInstall -notcontains "beyondcompare") {
            return  # Silently skip if not in ForceInstall list
        }
        Write-Host "  → Force installing Beyond Compare..." -ForegroundColor Magenta
    }
    elseif (-not $ShouldInstall) {
        Write-Host "  ⊘ Skipped Beyond Compare (disabled in config)" -ForegroundColor Gray
        return
    }
    
    Write-Host "  → Detecting latest Beyond Compare version..." -ForegroundColor Cyan
    
    try {
        # Download the Beyond Compare download page
        $downloadPage = Invoke-WebRequest -Uri "https://www.scootersoftware.com/download.php" -UseBasicParsing
        
        # Try multiple regex patterns to find the download link
        $exeFileName = $null
        $patterns = @(
            'href="(https://www\.scootersoftware\.com/files/BCompare-[\d\.]+\.exe)"',
            'href="(/files/BCompare-[\d\.]+\.exe)"',
            '(BCompare-[\d\.]+\.exe)',
            'files/(BCompare-[^"<>\s]+\.exe)'
        )
        
        foreach ($pattern in $patterns) {
            if ($downloadPage.Content -match $pattern) {
                $exeFileName = $Matches[1]
                if ($exeFileName -notlike "http*") {
                    $exeFileName = $exeFileName -replace '^/files/', ''
                    $exeFileName = $exeFileName -replace '^files/', ''
                }
                if ($exeFileName -like "BCompare-*") {
                    break
                }
            }
        }
        
        if (-not $exeFileName -or $exeFileName -notlike "BCompare-*") {
            # Fallback: Use known latest version
            Write-Host "  → Could not detect version, using known latest..." -ForegroundColor Yellow
            $exeFileName = "BCompare-5.1.6.31527.exe"
        }
        
        $downloadUrl = "https://www.scootersoftware.com/files/$exeFileName"
        
        # Extract version from filename
        if ($exeFileName -match 'BCompare-([\d\.]+)\.exe') {
            $version = $Matches[1]
            Write-Host "  → Found Beyond Compare v$version" -ForegroundColor Gray
        }
        
        # Check if already installed
        $installed = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | 
                     Where-Object { $_.DisplayName -like "*Beyond Compare*" }
        
        if ($installed) {
            Write-Host "  ✓ Beyond Compare already installed ($($installed.DisplayVersion))" -ForegroundColor Green
            return
        }
        
        # Download installer
        $tempFile = Join-Path $env:TEMP $exeFileName
        Write-Host "  → Downloading from $downloadUrl..." -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -ErrorAction Stop
        
        # Install silently
        Write-Host "  → Installing Beyond Compare (this may take a moment)..." -ForegroundColor Cyan
        Start-Process -FilePath $tempFile -ArgumentList "/SILENT" -Wait -NoNewWindow
        
        # Cleanup
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        Write-Host "  ✓ Beyond Compare installed successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Failed to download/install Beyond Compare: $_" -ForegroundColor Red
        Write-Host "  → Try manual download from: https://www.scootersoftware.com/download.php" -ForegroundColor Yellow
    }
}

function Install-GitForWindows {
    param([bool]$ShouldInstall = $true)
    
    # If ForceInstall is specified, ONLY install tools in that list
    if ($ForceInstall.Count -gt 0) {
        if ($ForceInstall -notcontains "git") {
            return  # Silently skip if not in ForceInstall list
        }
        Write-Host "  → Force installing Git for Windows..." -ForegroundColor Magenta
    }
    elseif (-not $ShouldInstall) {
        Write-Host "  ⊘ Skipped Git (disabled in config)" -ForegroundColor Gray
        return
    }
    
    # Check if winget is available
    $wingetAvailable = Test-CommandExists winget
    
    if (-not $wingetAvailable) {
        Write-Host "  ⚠️  Winget not found - falling back to Scoop's git" -ForegroundColor Yellow
        Write-Host "  Note: Claude Code requires git-bash. Install Git for Windows manually for full support." -ForegroundColor Cyan
        Write-Host "  → Installing git via Scoop..." -ForegroundColor Cyan
        scoop install git
        if (Test-CommandExists git) {
            Write-Host "  ✓ Git installed via Scoop" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to install git" -ForegroundColor Red
        }
        return
    }
    
    # Check if Scoop's git is installed and remove it
    $scoopGit = scoop list git 2>$null | Select-String -Pattern "^git "
    if ($scoopGit) {
        Write-Host "  → Removing Scoop's git (will install Git for Windows instead)..." -ForegroundColor Yellow
        scoop uninstall git 2>&1 | Out-Null
        Write-Host "  ✓ Scoop's git removed" -ForegroundColor Green
    }
    
    # Check if Git for Windows is already installed (via winget or manual)
    $gitInstalled = $null
    try {
        $gitInstalled = winget list --id Git.Git --accept-source-agreements 2>&1 | Select-String "Git.Git"
    } catch {
        # Ignore errors
    }
    
    if ($gitInstalled) {
        Write-Host "  ✓ Git for Windows already installed" -ForegroundColor Green
        
        # Find bash and set environment variable
        $commonPaths = @(
            "C:\Program Files\Git\bin\bash.exe",
            "C:\Program Files (x86)\Git\bin\bash.exe"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                Write-Host "  ✓ Git Bash found at: $path" -ForegroundColor Green
                [Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $path, "User")
                $env:CLAUDE_CODE_GIT_BASH_PATH = $path
                Write-Host "  ✓ Set CLAUDE_CODE_GIT_BASH_PATH" -ForegroundColor Green
                break
            }
        }
        return
    }
    
    Write-Host "  → Installing Git for Windows via winget..." -ForegroundColor Cyan
    Write-Host "    (Includes git-bash required for Claude Code)" -ForegroundColor Gray
    
    winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Git for Windows installed" -ForegroundColor Green
        
        # Refresh environment to detect git
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Try to find bash and set environment variable
        Start-Sleep -Seconds 2
        $commonPaths = @(
            "C:\Program Files\Git\bin\bash.exe",
            "C:\Program Files (x86)\Git\bin\bash.exe"
        )
        
        foreach ($path in $commonPaths) {
            if (Test-Path $path) {
                Write-Host "  ✓ Git Bash found at: $path" -ForegroundColor Green
                [Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $path, "User")
                $env:CLAUDE_CODE_GIT_BASH_PATH = $path
                Write-Host "  ✓ Set CLAUDE_CODE_GIT_BASH_PATH for Claude Code" -ForegroundColor Green
                break
            }
        }
        
        Write-Host "  Restart your terminal to use git" -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Failed to install Git for Windows" -ForegroundColor Red
        Write-Host "  Falling back to Scoop's git..." -ForegroundColor Yellow
        scoop install git
        if (Test-CommandExists git) {
            Write-Host "  ✓ Git installed via Scoop (fallback)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to install git" -ForegroundColor Red
        }
    }
}

function Test-CommandExists {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

function Get-ConfigValue {
    param(
        [hashtable]$Config,
        [string]$Key,
        [bool]$DefaultValue = $false
    )
    
    if ($Config.ContainsKey($Key)) {
        return $Config[$Key]
    }
    return $DefaultValue
}

function Update-SystemPath {
    param([string]$NewPath)

    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")

    if ($currentPath -split ';' | Where-Object { $_ -eq $NewPath }) {
        Write-Host "  ✓ PATH already contains: $NewPath" -ForegroundColor Green
        return
    }

    $newPathValue = "$currentPath;$NewPath"
    [Environment]::SetEnvironmentVariable("Path", $newPathValue, "User")

    $env:Path = "$env:Path;$NewPath"

    Write-Host "  ✓ Added to PATH: $NewPath" -ForegroundColor Green
}

function Install-PowerShellModules {
    param(
        [hashtable]$ModulesConfig,
        [string]$ModulesSourcePath
    )

    if (-not $ModulesConfig) {
        return
    }

    # Determine PowerShell modules directory
    $psVersion = $PSVersionTable.PSVersion.Major
    if ($psVersion -ge 6) {
        # PowerShell Core/7+
        $modulesDir = Join-Path $env:USERPROFILE "Documents\PowerShell\Modules"
    } else {
        # Windows PowerShell 5.1
        $modulesDir = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
    }

    # Ensure modules directory exists
    if (-not (Test-Path $modulesDir)) {
        New-Item -Path $modulesDir -ItemType Directory -Force | Out-Null
    }

    $modulesInstalled = @()
    $modulesFailed = @()

    # Install path-manager
    if (Get-ConfigValue $ModulesConfig "path-manager") {
        $moduleName = "path-manager"
        $sourcePath = Join-Path $ModulesSourcePath "$moduleName\$moduleName.psm1"
        $destDir = Join-Path $modulesDir $moduleName

        if (Test-Path $sourcePath) {
            try {
                # Create module directory
                if (-not (Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }

                # Copy module file
                Copy-Item -Path $sourcePath -Destination (Join-Path $destDir "$moduleName.psm1") -Force
                Write-Host "  ✓ $moduleName installed to PowerShell modules" -ForegroundColor Green
                $modulesInstalled += $moduleName
            }
            catch {
                Write-Host "  ✗ Failed to install $moduleName : $_" -ForegroundColor Red
                $modulesFailed += $moduleName
            }
        }
        else {
            Write-Host "  ⚠️  $moduleName source not found at: $sourcePath" -ForegroundColor Yellow
            $modulesFailed += $moduleName
        }
    }

    # Install winget-manager
    if (Get-ConfigValue $ModulesConfig "winget-manager") {
        $moduleName = "winget-manager"
        $sourcePath = Join-Path $ModulesSourcePath "$moduleName\$moduleName.psm1"
        $destDir = Join-Path $modulesDir $moduleName

        if (Test-Path $sourcePath) {
            try {
                if (-not (Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $sourcePath -Destination (Join-Path $destDir "$moduleName.psm1") -Force
                Write-Host "  ✓ $moduleName installed to PowerShell modules" -ForegroundColor Green
                $modulesInstalled += $moduleName
            }
            catch {
                Write-Host "  ✗ Failed to install $moduleName : $_" -ForegroundColor Red
                $modulesFailed += $moduleName
            }
        }
        else {
            Write-Host "  ⚠️  $moduleName source not found at: $sourcePath" -ForegroundColor Yellow
            $modulesFailed += $moduleName
        }
    }

    # Install scoop-manager
    if (Get-ConfigValue $ModulesConfig "scoop-manager") {
        $moduleName = "scoop-manager"
        $sourcePath = Join-Path $ModulesSourcePath "$moduleName\$moduleName.psm1"
        $destDir = Join-Path $modulesDir $moduleName

        if (Test-Path $sourcePath) {
            try {
                if (-not (Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item -Path $sourcePath -Destination (Join-Path $destDir "$moduleName.psm1") -Force
                Write-Host "  ✓ $moduleName installed to PowerShell modules" -ForegroundColor Green
                $modulesInstalled += $moduleName
            }
            catch {
                Write-Host "  ✗ Failed to install $moduleName : $_" -ForegroundColor Red
                $modulesFailed += $moduleName
            }
        }
        else {
            Write-Host "  ⚠️  $moduleName source not found at: $sourcePath" -ForegroundColor Yellow
            $modulesFailed += $moduleName
        }
    }

    # Update PowerShell profile to auto-import modules
    if ($modulesInstalled.Count -gt 0) {
        # Import modules in current session
        Write-Host "`n  → Importing modules in current session..." -ForegroundColor Cyan
        foreach ($mod in $modulesInstalled) {
            Import-Module $mod -ErrorAction SilentlyContinue
            Write-Host "  ✓ $mod imported" -ForegroundColor Green
        }

        $profilePath = $PROFILE
        $profileDir = Split-Path -Parent $profilePath

        # Ensure profile directory exists
        if (-not (Test-Path $profileDir)) {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
        }

        # Create profile if it doesn't exist
        if (-not (Test-Path $profilePath)) {
            New-Item -Path $profilePath -ItemType File -Force | Out-Null
        }

        # Read existing profile content
        $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if (-not $profileContent) {
            $profileContent = ""
        }

        # Check if auto-import section exists
        if ($profileContent -notmatch "# Auto-import custom PowerShell modules") {
            $importBlock = @"

# ============================================================================
# Auto-import custom PowerShell modules
# Added by setup-dev-environment.ps1
# ============================================================================

"@
            foreach ($mod in $modulesInstalled) {
                $importBlock += @"
# Import $mod module
if (Get-Module -ListAvailable -Name $mod) {
    Import-Module $mod -ErrorAction SilentlyContinue
}

"@
            }

            Add-Content -Path $profilePath -Value $importBlock
            Write-Host "  ✓ PowerShell profile updated to auto-import modules" -ForegroundColor Green
            Write-Host "    Profile location: $profilePath" -ForegroundColor Gray
        }
        else {
            Write-Host "  PowerShell profile already configured for module auto-import" -ForegroundColor Cyan
        }

        Write-Host "`n  Modules are now globally available!" -ForegroundColor Cyan
        Write-Host "     Open a new PowerShell session or run:" -ForegroundColor Gray
        Write-Host "     . `$PROFILE" -ForegroundColor Yellow
    }

    if ($modulesFailed.Count -gt 0) {
        Write-Host "  ⚠️  $($modulesFailed.Count) module(s) failed to install" -ForegroundColor Yellow
    }
}

function Install-CustomTools {
    param(
        [string]$ToolsSourcePath,
        [string]$InstallPath
    )

    # Check if tools source directory exists
    if (-not (Test-Path $ToolsSourcePath)) {
        Write-Host "  No custom tools found at: $ToolsSourcePath" -ForegroundColor Gray
        return
    }

    # Get all PowerShell scripts from tools directory
    $toolScripts = Get-ChildItem -Path $ToolsSourcePath -Filter "*.ps1" -File -ErrorAction SilentlyContinue

    if ($toolScripts.Count -eq 0) {
        Write-Host "  No tools to deploy" -ForegroundColor Gray
        return
    }

    # Create tools directory in install path
    $toolsDestPath = Join-Path $InstallPath "tools"
    if (-not (Test-Path $toolsDestPath)) {
        New-Item -Path $toolsDestPath -ItemType Directory -Force | Out-Null
    }

    $toolsDeployed = @()
    $toolsFailed = @()

    Write-Host "  → Deploying custom tools to: $toolsDestPath" -ForegroundColor Cyan

    foreach ($tool in $toolScripts) {
        try {
            $destPath = Join-Path $toolsDestPath $tool.Name
            Copy-Item -Path $tool.FullName -Destination $destPath -Force
            Write-Host "  ✓ $($tool.Name) deployed" -ForegroundColor Green
            $toolsDeployed += $tool.Name
        }
        catch {
            Write-Host "  ✗ Failed to deploy $($tool.Name): $_" -ForegroundColor Red
            $toolsFailed += $tool.Name
        }
    }

    # Add tools directory to PATH if tools were deployed successfully
    if ($toolsDeployed.Count -gt 0) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $pathEntries = $currentPath -split ';' | Where-Object { $_ }

        if ($pathEntries -notcontains $toolsDestPath) {
            Write-Host "  → Adding tools directory to PATH..." -ForegroundColor Cyan
            Update-SystemPath -NewPath $toolsDestPath
        }
        else {
            Write-Host "  ✓ PATH already contains: $toolsDestPath" -ForegroundColor Green
        }

        Write-Host "`n  Deployed tools are now available!" -ForegroundColor Cyan
        Write-Host "     $($toolsDeployed.Count) tool(s) deployed:" -ForegroundColor Gray
        foreach ($tool in $toolsDeployed) {
            Write-Host "     • $tool" -ForegroundColor Gray
        }
        Write-Host "`n     You can run them from any location:" -ForegroundColor Gray
        Write-Host "     pwsh $toolsDestPath\<tool-name>.ps1" -ForegroundColor Yellow
    }

    if ($toolsFailed.Count -gt 0) {
        Write-Host "  ⚠️  $($toolsFailed.Count) tool(s) failed to deploy" -ForegroundColor Yellow
    }
}

function Install-NVMForWindows {
    param([bool]$ShouldInstall = $true)

    if (-not $ShouldInstall) {
        Write-Host "  ⊘ Skipped NVM (disabled in config)" -ForegroundColor Gray
        return
    }

    # If ForceInstall is specified, check if nvm is in the list
    if ($ForceInstall.Count -gt 0 -and $ForceInstall -notcontains "nvm") {
        return
    }

    # Check if NVM is already installed
    if (Test-CommandExists nvm) {
        Write-Host "  ✓ NVM already installed" -ForegroundColor Green
        $nvmVersion = & nvm version 2>$null
        Write-Host "  → Current version: $nvmVersion" -ForegroundColor Gray
        return
    }

    Write-Host "  → Installing NVM for Windows..." -ForegroundColor Cyan

    try {
        # Use noinstall (portable) version to avoid GUI dialogs
        $nvmVersion = "1.1.12"  # Latest stable version
        $zipUrl = "https://github.com/coreybutler/nvm-windows/releases/download/$nvmVersion/nvm-noinstall.zip"
        $zipPath = Join-Path $env:TEMP "nvm-noinstall.zip"
        $nvmHome = "$env:APPDATA\nvm"
        $nvmSymlink = "$env:PROGRAMFILES\nodejs"

        Write-Host "  → Downloading NVM $nvmVersion (portable)..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -ErrorAction Stop

        Write-Host "  → Extracting NVM..." -ForegroundColor Gray
        # Create NVM directory
        if (-not (Test-Path $nvmHome)) {
            New-Item -ItemType Directory -Path $nvmHome -Force | Out-Null
        }
        Expand-Archive -Path $zipPath -DestinationPath $nvmHome -Force

        # Create settings.txt for NVM
        $settingsContent = @"
root: $nvmHome
path: $nvmSymlink
"@
        Set-Content -Path "$nvmHome\settings.txt" -Value $settingsContent -Force

        # Set environment variables (User level to avoid admin requirements)
        [System.Environment]::SetEnvironmentVariable("NVM_HOME", $nvmHome, "User")
        [System.Environment]::SetEnvironmentVariable("NVM_SYMLINK", $nvmSymlink, "User")

        # Add to PATH
        $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath -notlike "*$nvmHome*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$nvmHome;$nvmSymlink;$userPath", "User")
        }

        # Cleanup
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue

        # Refresh environment
        $env:NVM_HOME = $nvmHome
        $env:NVM_SYMLINK = $nvmSymlink
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (Test-CommandExists nvm) {
            Write-Host "  ✓ NVM installed successfully" -ForegroundColor Green

            # Install LTS Node.js
            Write-Host "  → Installing Node.js LTS via NVM..." -ForegroundColor Cyan
            nvm install lts 2>&1 | Out-Null
            nvm use lts 2>&1 | Out-Null

            # Refresh PATH again
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            if (Test-CommandExists node) {
                $nodeVersion = & node --version
                Write-Host "  ✓ Node.js $nodeVersion installed" -ForegroundColor Green
                Write-Host "  Restart terminal to use node/npm commands" -ForegroundColor Yellow
            } else {
                Write-Host "  ⚠ Node.js installed but not in PATH yet" -ForegroundColor Yellow
                Write-Host "  Restart terminal and run: nvm use lts" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✗ NVM installation may have failed" -ForegroundColor Red
            Write-Host "  Download manually from: https://github.com/coreybutler/nvm-windows/releases" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ✗ Failed to install NVM: $_" -ForegroundColor Red
        Write-Host "  Download manually from: https://github.com/coreybutler/nvm-windows/releases" -ForegroundColor Yellow
    }
}

function Install-Yarn {
    param([bool]$ShouldInstall = $true)

    if (-not $ShouldInstall) {
        Write-Host "  ⊘ Skipped Yarn (disabled in config)" -ForegroundColor Gray
        return
    }

    # Check if Node.js is available
    if (-not (Test-CommandExists node)) {
        Write-Host "  ✗ Node.js not found. Install NVM/Node.js first." -ForegroundColor Red
        return
    }

    # Check if Yarn is already installed
    if (Test-CommandExists yarn) {
        Write-Host "  ✓ Yarn already installed" -ForegroundColor Green
        return
    }

    Write-Host "  → Installing Yarn via Corepack..." -ForegroundColor Cyan

    # Try Corepack first (built into Node.js 16.10+)
    corepack enable 2>&1 | Out-Null
    corepack prepare yarn@stable --activate 2>&1 | Out-Null

    if (Test-CommandExists yarn) {
        Write-Host "  ✓ Yarn installed via Corepack" -ForegroundColor Green
    } else {
        # Fallback to npm install
        Write-Host "  → Corepack not available, using npm..." -ForegroundColor Yellow
        npm install -g yarn --quiet 2>&1 | Out-Null
        if (Test-CommandExists yarn) {
            Write-Host "  ✓ Yarn installed via npm" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to install Yarn" -ForegroundColor Red
        }
    }
}

function Install-Pnpm {
    param([bool]$ShouldInstall = $true)

    if (-not $ShouldInstall) {
        Write-Host "  ⊘ Skipped pnpm (disabled in config)" -ForegroundColor Gray
        return
    }

    # Check if Node.js is available
    if (-not (Test-CommandExists node)) {
        Write-Host "  ✗ Node.js not found. Install NVM/Node.js first." -ForegroundColor Red
        return
    }

    # Check if pnpm is already installed
    if (Test-CommandExists pnpm) {
        Write-Host "  ✓ pnpm already installed" -ForegroundColor Green
        return
    }

    Write-Host "  → Installing pnpm via official installer..." -ForegroundColor Cyan

    try {
        # Use official pnpm installer
        Invoke-WebRequest https://get.pnpm.io/install.ps1 -UseBasicParsing | Invoke-Expression

        if (Test-CommandExists pnpm) {
            Write-Host "  ✓ pnpm installed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ pnpm installation failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ Failed to install pnpm: $_" -ForegroundColor Red
        Write-Host "  Try manually: Invoke-WebRequest https://get.pnpm.io/install.ps1 -UseBasicParsing | Invoke-Expression" -ForegroundColor Yellow
    }
}

# ============================================================================
# USER-LEVEL TOOLS INSTALLATION
# ============================================================================

if ($ToolsUserRights) {
    
    # ========================================================================
    # INSTALL SCOOP
    # ========================================================================
    
    Write-Section "Installing Scoop Package Manager"
    
    if (Test-CommandExists scoop) {
        Write-Host "  ✓ Scoop already installed" -ForegroundColor Green
        $currentScoopPath = scoop prefix scoop 2>$null
        if ($currentScoopPath) {
            Write-Host "  → Current location: $currentScoopPath" -ForegroundColor Gray
        }
    } else {
        if (-not (Test-Path $installPath)) {
            Write-Host "  → Creating directory: $installPath..." -ForegroundColor Cyan
            New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        }
        
        $env:SCOOP = $installPath
        
        if ($ForceAdmin) {
            [Environment]::SetEnvironmentVariable('SCOOP', $installPath, 'Machine')
            Write-Host "  → Set SCOOP environment variable (Machine scope)" -ForegroundColor Gray
        } else {
            [Environment]::SetEnvironmentVariable('SCOOP', $installPath, 'User')
            Write-Host "  → Set SCOOP environment variable (User scope)" -ForegroundColor Gray
        }
        
        Write-Host "  → Installing Scoop to $installPath..." -ForegroundColor Cyan
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        
        if ($ForceAdmin) {
            Write-Host "  → Installing Scoop with admin privileges (ForceAdmin mode)..." -ForegroundColor Yellow
            Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
        } else {
            Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        }
        
        if (Test-CommandExists scoop) {
            Write-Host "  ✓ Scoop installed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to install Scoop" -ForegroundColor Red
            exit 1
        }
    }
    
    # Add buckets
    if ($ForceInstall.Count -eq 0) {
        Write-Host "  → Adding Scoop buckets..." -ForegroundColor Gray
        $buckets = @("extras", "versions", "java", "nerd-fonts")
        foreach ($bucket in $buckets) {
            $bucketExists = scoop bucket list 2>$null | Select-String -Pattern "^$bucket$"
            if (-not $bucketExists) {
                scoop bucket add $bucket 2>&1 | Out-Null
            }
        }
    }
    
    # Update PATH
    $scoopShims = Join-Path $installPath "shims"
    if (Test-Path $scoopShims) {
        Update-SystemPath $scoopShims
    }

    # ========================================================================
    # DEPLOY CUSTOM TOOLS
    # ========================================================================

    Write-Section "Custom Tools Deployment"

    $toolsSourcePath = Join-Path $scriptDir "tools"
    Install-CustomTools -ToolsSourcePath $toolsSourcePath -InstallPath $installPath

    # ========================================================================
    # FORCE INSTALL MODE - Skip all sections and install only specified tools
    # ========================================================================
    
    if ($ForceInstall.Count -gt 0) {
        Write-Section "Force Install Mode - Installing Specified Tools Only"

        # Track installation results
        $successfulTools = @()
        $failedTools = @()
        $alreadyInstalled = @()

        # Tool name suggestions for common mistakes
        $toolSuggestions = @{
            "claude" = @{
                correct = "claude-code"
                reason = "Claude Code is an npm package, not a Scoop package"
                hint = "Use: -ForceInstall claude-code"
            }
            "node" = @{
                correct = "nodejs"
                reason = "The package name in Scoop is 'nodejs'"
                hint = "Use: -ForceInstall nodejs"
            }
            "python3" = @{
                correct = "python"
                reason = "The package name in Scoop is 'python'"
                hint = "Use: -ForceInstall python"
            }
        }

        foreach ($tool in $ForceInstall) {
            Write-Host "`n→ Force installing: $tool" -ForegroundColor Magenta
            
            # Special handling for git - use Git for Windows
            if ($tool -eq "git") {
                $gitExistedBefore = Test-CommandExists git
                Install-GitForWindows -ShouldInstall $true
                if (Test-CommandExists git) {
                    if ($gitExistedBefore) {
                        $alreadyInstalled += "git"
                    } else {
                        $successfulTools += "git"
                    }
                } else {
                    $failedTools += @{tool="git"; reason="Installation failed"}
                }
                continue
            }
            
            # Special handling for claude-code - requires npm
            if ($tool -eq "claude-code") {
                if (-not (Test-CommandExists npm)) {
                    Write-Host "  ✗ npm not found. Installing Node.js first..." -ForegroundColor Yellow
                    Write-Host "  → Installing nodejs via Scoop..." -ForegroundColor Cyan
                    scoop install nodejs 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✓ Node.js installed" -ForegroundColor Green
                        # Refresh PATH
                        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
                    } else {
                        Write-Host "  ✗ Failed to install Node.js" -ForegroundColor Red
                        $failedTools += @{tool="claude-code"; reason="npm not found and Node.js installation failed"}
                        continue
                    }
                }

                # Check if already installed
                $claudeInstalled = npm list -g @anthropic-ai/claude-code 2>&1 | Select-String "@anthropic-ai/claude-code"
                if ($claudeInstalled) {
                    Write-Host "  ✓ claude-code already installed" -ForegroundColor Green
                    $alreadyInstalled += "claude-code"
                } else {
                    Write-Host "  → Installing claude-code via npm..." -ForegroundColor Cyan
                    npm install -g @anthropic-ai/claude-code --silent 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✓ claude-code installed successfully" -ForegroundColor Green
                        $successfulTools += "claude-code"
                    } else {
                        Write-Host "  ✗ Failed to install claude-code" -ForegroundColor Red
                        Write-Host "  Try manually: npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
                        $failedTools += @{tool="claude-code"; reason="npm install failed"}
                    }
                }
                continue
            }
            
            # Check if tool name has a known suggestion
            if ($toolSuggestions.ContainsKey($tool)) {
                $suggestion = $toolSuggestions[$tool]
                Write-Host "  ⚠️  Tool '$tool' not found" -ForegroundColor Yellow
                Write-Host "  Did you mean '$($suggestion.correct)'?" -ForegroundColor Cyan
                Write-Host "     $($suggestion.reason)" -ForegroundColor Gray
                Write-Host "     $($suggestion.hint)" -ForegroundColor Cyan
                $failedTools += @{tool=$tool; reason="Tool not found. Did you mean '$($suggestion.correct)'?"}
                continue
            }

            $installed = scoop list 2>$null | Select-String -Pattern "^$tool "
            if ($installed) {
                Write-Host "  ✓ $tool already installed" -ForegroundColor Green
                $alreadyInstalled += $tool
            } else {
                Write-Host "  → Installing $tool..." -ForegroundColor Cyan
                scoop install $tool 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ $tool installed successfully" -ForegroundColor Green
                    $successfulTools += $tool
                } else {
                    Write-Host "  ✗ Failed to install $tool" -ForegroundColor Red
                    Write-Host "  Try: scoop search $tool" -ForegroundColor Yellow
                    $failedTools += @{tool=$tool; reason="Not found in Scoop. Try: scoop search $tool"}
                }
            }
        }

        # ====================================================================
        # Display detailed installation summary
        # ====================================================================
        Write-Host ""
        Write-Host ("═" * 70) -ForegroundColor DarkGray
        Write-Host " 📊 Installation Summary" -ForegroundColor Cyan
        Write-Host ("═" * 70) -ForegroundColor DarkGray

        $totalTools = $ForceInstall.Count
        $totalSuccess = $successfulTools.Count
        $totalAlreadyInstalled = $alreadyInstalled.Count
        $totalFailed = $failedTools.Count

        # Determine overall status
        if ($totalFailed -eq 0 -and ($totalSuccess -gt 0 -or $totalAlreadyInstalled -gt 0)) {
            Write-Host " All tools installed successfully!" -ForegroundColor Green
        }
        elseif ($totalFailed -gt 0 -and ($totalSuccess -gt 0 -or $totalAlreadyInstalled -gt 0)) {
            Write-Host " ⚠️  Installation completed with some failures" -ForegroundColor Yellow
        }
        elseif ($totalFailed -gt 0 -and $totalSuccess -eq 0 -and $totalAlreadyInstalled -eq 0) {
            Write-Host " ❌ Installation failed" -ForegroundColor Red
        }
        elseif ($totalAlreadyInstalled -eq $totalTools) {
            Write-Host " All tools were already installed" -ForegroundColor Cyan
        }
        Write-Host ""

        # Show newly installed tools
        if ($successfulTools.Count -gt 0) {
            Write-Host " ✓ Successfully installed ($($successfulTools.Count)):" -ForegroundColor Green
            foreach ($tool in $successfulTools) {
                Write-Host "   • $tool" -ForegroundColor Green
            }
            Write-Host ""
        }

        # Show already installed tools
        if ($alreadyInstalled.Count -gt 0) {
            Write-Host " Already installed ($($alreadyInstalled.Count)):" -ForegroundColor Cyan
            foreach ($tool in $alreadyInstalled) {
                Write-Host "   • $tool" -ForegroundColor Gray
            }
            Write-Host ""
        }

        # Show failed installations with reasons
        if ($failedTools.Count -gt 0) {
            Write-Host " ✗ Failed to install ($($failedTools.Count)):" -ForegroundColor Red
            foreach ($item in $failedTools) {
                if ($item -is [hashtable]) {
                    Write-Host "   • $($item.tool)" -ForegroundColor Red
                    Write-Host "     → $($item.reason)" -ForegroundColor Yellow
                } else {
                    Write-Host "   • $item" -ForegroundColor Red
                }
            }
            Write-Host ""
        }

        # Provide next steps if there were failures
        if ($failedTools.Count -gt 0) {
            Write-Host " Next steps:" -ForegroundColor Cyan
            $hasTypoSuggestion = $false
            $hasNpmIssue = $false
            $hasScoopIssue = $false

            foreach ($item in $failedTools) {
                if ($item -is [hashtable]) {
                    if ($item.reason -like "*Did you mean*") {
                        $hasTypoSuggestion = $true
                    }
                    if ($item.reason -like "*npm*") {
                        $hasNpmIssue = $true
                    }
                    if ($item.reason -like "*Not found in Scoop*") {
                        $hasScoopIssue = $true
                    }
                }
            }

            if ($hasTypoSuggestion) {
                Write-Host "   1. Check tool names and use suggested corrections above" -ForegroundColor Gray
            }
            if ($hasNpmIssue) {
                Write-Host "   2. Ensure Node.js is installed: scoop install nodejs" -ForegroundColor Gray
            }
            if ($hasScoopIssue) {
                Write-Host "   3. Search for correct package names: scoop search <tool>" -ForegroundColor Gray
            }
            Write-Host "   4. Check available buckets: scoop bucket list" -ForegroundColor Gray
            Write-Host "   5. Some tools require specific buckets (extras, versions, etc.)" -ForegroundColor Gray
            Write-Host ""
        }

        Write-Host ("═" * 70) -ForegroundColor DarkGray

        # Exit with appropriate code
        if ($failedTools.Count -gt 0) {
            exit 1
        } else {
            exit 0
        }
    }
    
    # ========================================================================
    # CORE TOOLS
    # ========================================================================
    
    Write-Section "Core Development Tools"
    
    $coreTools = $config.UserLevel.CoreTools
    if ($coreTools) {
        # Install Git for Windows (includes git-bash for Claude Code)
        Install-GitForWindows -ShouldInstall (Get-ConfigValue $coreTools "git")
        
        Install-ScoopPackage "gh" -ShouldInstall (Get-ConfigValue $coreTools "github-cli")
        Install-ScoopPackage "curl" -ShouldInstall (Get-ConfigValue $coreTools "curl")
        Install-ScoopPackage "wget" -ShouldInstall (Get-ConfigValue $coreTools "wget")
        Install-ScoopPackage "jq" -ShouldInstall (Get-ConfigValue $coreTools "jq")
        Install-ScoopPackage "yq" -ShouldInstall (Get-ConfigValue $coreTools "yq")
        Install-ScoopPackage "ripgrep" -ShouldInstall (Get-ConfigValue $coreTools "ripgrep")
        Install-ScoopPackage "fd" -ShouldInstall (Get-ConfigValue $coreTools "fd")
        Install-ScoopPackage "fzf" -ShouldInstall (Get-ConfigValue $coreTools "fzf")
        Install-ScoopPackage "bat" -ShouldInstall (Get-ConfigValue $coreTools "bat")
        Install-ScoopPackage "less" -ShouldInstall (Get-ConfigValue $coreTools "less")
        Install-ScoopPackage "7zip" -ShouldInstall (Get-ConfigValue $coreTools "7zip")
    }
    
    # ========================================================================
    # UNIX TOOLS (Enhanced with tree and rsync)
    # ========================================================================
    
    Write-Section "Unix/Linux Tools"
    
    $unixTools = $config.UserLevel.UnixTools
    if ($unixTools) {
        # Core Unix tools
        Install-ScoopPackage "busybox" -ShouldInstall (Get-ConfigValue $unixTools "busybox")
        Install-ScoopPackage "grep" -ShouldInstall (Get-ConfigValue $unixTools "grep")
        Install-ScoopPackage "sed" -ShouldInstall (Get-ConfigValue $unixTools "sed")
        Install-ScoopPackage "gawk" -ShouldInstall (Get-ConfigValue $unixTools "gawk")
        Install-ScoopPackage "make" -ShouldInstall (Get-ConfigValue $unixTools "make")
        Install-ScoopPackage "which" -ShouldInstall (Get-ConfigValue $unixTools "which")
        Install-ScoopPackage "ssh" -ShouldInstall (Get-ConfigValue $unixTools "ssh")
        Install-ScoopPackage "openssh" -ShouldInstall (Get-ConfigValue $unixTools "openssh")
        Install-ScoopPackage "mc" -ShouldInstall (Get-ConfigValue $unixTools "mc")
        
        # Tree - standalone version from extras bucket
        if (Get-ConfigValue $unixTools "tree-standalone") {
            Write-Host "  → Installing tree (standalone from extras)..." -ForegroundColor Cyan
            scoop bucket add extras 2>$null
            Install-ScoopPackage "tree" -Bucket "extras" -ShouldInstall $true
            
            if (-not (Test-CommandExists tree)) {
                Write-Host "  Tip: Use 'busybox tree' as alternative" -ForegroundColor Yellow
            }
        } elseif (Get-ConfigValue $unixTools "busybox") {
            Write-Host "  Tree available via: busybox tree" -ForegroundColor Gray
        }
        
        # Rsync - cwrsync (rsync for Windows) from extras bucket
        if (Get-ConfigValue $unixTools "rsync-standalone") {
            Write-Host "  → Installing rsync (cwrsync from extras)..." -ForegroundColor Cyan
            scoop bucket add extras 2>$null
            Install-ScoopPackage "cwrsync" -Bucket "extras" -ShouldInstall $true
            
            $rsyncPath = "$installPath\apps\cwrsync\current\bin\rsync.exe"
            if (Test-Path $rsyncPath) {
                Write-Host "  ✓ rsync (cwrsync) installed successfully" -ForegroundColor Green
                Write-Host "  → Location: $rsyncPath" -ForegroundColor Gray
            } else {
                Write-Host "  Tip: Use 'busybox rsync' as alternative" -ForegroundColor Yellow
            }
        } elseif (Get-ConfigValue $unixTools "busybox") {
            Write-Host "  Rsync available via: busybox rsync" -ForegroundColor Gray
        }
    }
    
    # ========================================================================
    # PROGRAMMING LANGUAGES
    # ========================================================================
    
    Write-Section "Programming Languages"
    
    # Python (Enhanced with better error handling)
    $pythonConfig = $config.UserLevel.'Languages.Python'
    if ($pythonConfig -and (Get-ConfigValue $pythonConfig "install")) {
        Write-Host "`nPython" -ForegroundColor Yellow
        Install-ScoopPackage "python" -ShouldInstall $true
        
        if ((Get-ConfigValue $pythonConfig "pip-packages") -and (Test-CommandExists python)) {
            Write-Host "  → Installing Python packages..." -ForegroundColor Cyan
            
            # Close any Python processes that might lock files
            Get-Process python* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Update pip first
            Write-Host "  → Updating pip..." -ForegroundColor Gray
            python -m pip install --upgrade pip 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ pip updated" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ pip update had warnings (often normal)" -ForegroundColor Yellow
            }
            
            Start-Sleep -Seconds 2
            
            # Install packages one by one
            $packages = @('pylint', 'black', 'flake8', 'mypy', 'pytest', 'ipython', 'jupyter')
            foreach ($pkg in $packages) {
                Write-Host "  → Installing $pkg..." -ForegroundColor Gray
                pip install $pkg --quiet 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ $pkg installed" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠ $pkg may have issues" -ForegroundColor Yellow
                }
            }
            
            Write-Host "  ✓ Python packages installation complete" -ForegroundColor Green
        }
    }
    
    # Node.js via NVM
    $nodeConfig = $config.UserLevel.'Languages.NodeJS'
    if ($nodeConfig -and (Get-ConfigValue $nodeConfig "nvm")) {
        Write-Host "`nNode.js (via NVM)" -ForegroundColor Yellow
        Install-NVMForWindows -ShouldInstall $true

        # Install Yarn (optional)
        Install-Yarn -ShouldInstall (Get-ConfigValue $nodeConfig "yarn")

        # Install pnpm (optional)
        Install-Pnpm -ShouldInstall (Get-ConfigValue $nodeConfig "pnpm")

        # Install global npm packages (optional)
        if ((Get-ConfigValue $nodeConfig "npm-global-packages") -and (Test-CommandExists npm)) {
            Write-Host "  → Installing global npm packages..." -ForegroundColor Cyan
            npm install -g typescript ts-node eslint prettier --quiet 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ npm packages installed" -ForegroundColor Green
            } else {
                Write-Host "  ⚠ Some npm packages may have failed" -ForegroundColor Yellow
            }
        }
    }
    
    # Go
    $goConfig = $config.UserLevel.'Languages.Go'
    if ($goConfig -and (Get-ConfigValue $goConfig "install")) {
        Write-Host "`nGo" -ForegroundColor Yellow
        Install-ScoopPackage "go" -ShouldInstall $true
    }
    
    # Rust
    $rustConfig = $config.UserLevel.'Languages.Rust'
    if ($rustConfig -and (Get-ConfigValue $rustConfig "install")) {
        Write-Host "`nRust" -ForegroundColor Yellow
        Install-ScoopPackage "rustup" -ShouldInstall $true
        if (Test-CommandExists rustup) {
            Write-Host "  → Setting up Rust stable..." -ForegroundColor Gray
            rustup default stable --quiet 2>&1 | Out-Null
        }
    }
    
    # Java
    $javaConfig = $config.UserLevel.'Languages.Java'
    if ($javaConfig -and (Get-ConfigValue $javaConfig "install")) {
        Write-Host "`nJava" -ForegroundColor Yellow
        Install-ScoopPackage "openjdk" -Bucket "java" -ShouldInstall $true
        Install-ScoopPackage "maven" -ShouldInstall (Get-ConfigValue $javaConfig "maven")
        Install-ScoopPackage "gradle" -ShouldInstall (Get-ConfigValue $javaConfig "gradle")
    }
    
    # Ruby
    $rubyConfig = $config.UserLevel.'Languages.Ruby'
    if ($rubyConfig -and (Get-ConfigValue $rubyConfig "install")) {
        Write-Host "`nRuby" -ForegroundColor Yellow
        Install-ScoopPackage "ruby" -ShouldInstall $true
        if ((Get-ConfigValue $rubyConfig "bundler") -and (Test-CommandExists gem)) {
            Write-Host "  → Installing bundler..." -ForegroundColor Gray
            gem install bundler --quiet
        }
    }
    
    # PHP
    $phpConfig = $config.UserLevel.'Languages.PHP'
    if ($phpConfig -and (Get-ConfigValue $phpConfig "install")) {
        Write-Host "`nPHP" -ForegroundColor Yellow
        Install-ScoopPackage "php" -ShouldInstall $true
        Install-ScoopPackage "composer" -ShouldInstall (Get-ConfigValue $phpConfig "composer")
    }
    
    # .NET
    $dotnetConfig = $config.UserLevel.'Languages.DotNet'
    if ($dotnetConfig -and (Get-ConfigValue $dotnetConfig "install")) {
        Write-Host "`n.NET" -ForegroundColor Yellow
        Install-ScoopPackage "dotnet-sdk" -ShouldInstall $true
    }
    
    # Flutter
    $flutterConfig = $config.UserLevel.'Languages.Flutter'
    if ($flutterConfig -and (Get-ConfigValue $flutterConfig "install")) {
        Write-Host "`nFlutter SDK" -ForegroundColor Yellow
        Install-ScoopPackage "flutter" -ShouldInstall $true
        
        if (Test-CommandExists flutter) {
            Write-Host "  → Configuring Flutter..." -ForegroundColor Cyan
            
            # Disable analytics
            flutter config --no-analytics 2>&1 | Out-Null
            
            # Run flutter doctor to complete setup
            Write-Host "  → Running initial Flutter setup (this may take a moment)..." -ForegroundColor Gray
            flutter doctor 2>&1 | Out-Null
            
            Write-Host "  ✓ Flutter SDK configured" -ForegroundColor Green
            
            # Check if Android SDK should be installed
            if (Get-ConfigValue $flutterConfig "android-sdk") {
                Write-Host "  → Note: Android SDK installation requires manual setup" -ForegroundColor Yellow
                Write-Host "  → Visit: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
            }
            
            Write-Host "  Run 'flutter doctor' to check your Flutter setup" -ForegroundColor Cyan
        }
    }
    
    # ========================================================================
    # DATABASES
    # ========================================================================
    
    Write-Section "Databases"
    
    $dbConfig = $config.UserLevel.Databases
    if ($dbConfig) {
        Install-ScoopPackage "sqlite" -ShouldInstall (Get-ConfigValue $dbConfig "sqlite")
        Install-ScoopPackage "postgresql" -ShouldInstall (Get-ConfigValue $dbConfig "postgresql")
        Install-ScoopPackage "mongodb" -ShouldInstall (Get-ConfigValue $dbConfig "mongodb")
        Install-ScoopPackage "redis" -ShouldInstall (Get-ConfigValue $dbConfig "redis")
        Install-ScoopPackage "mysql" -ShouldInstall (Get-ConfigValue $dbConfig "mysql")
    }
    
    # ========================================================================
    # CONTAINERS
    # ========================================================================
    
    Write-Section "Container Tools"
    
    $containerConfig = $config.UserLevel.Containers
    if ($containerConfig) {
        Install-ScoopPackage "docker" -ShouldInstall (Get-ConfigValue $containerConfig "docker-cli")
        Install-ScoopPackage "docker-compose" -ShouldInstall (Get-ConfigValue $containerConfig "docker-compose")
        Install-ScoopPackage "kubectl" -ShouldInstall (Get-ConfigValue $containerConfig "kubectl")
        Install-ScoopPackage "helm" -ShouldInstall (Get-ConfigValue $containerConfig "helm")
        Install-ScoopPackage "k9s" -ShouldInstall (Get-ConfigValue $containerConfig "k9s")
        Install-ScoopPackage "kind" -ShouldInstall (Get-ConfigValue $containerConfig "kind")
        Install-ScoopPackage "minikube" -ShouldInstall (Get-ConfigValue $containerConfig "minikube")
        Install-ScoopPackage "argocd" -ShouldInstall (Get-ConfigValue $containerConfig "argocd-cli")
    }
    
    # ========================================================================
    # CLOUD TOOLS
    # ========================================================================
    
    Write-Section "Cloud Tools"
    
    $cloudConfig = $config.UserLevel.Cloud
    if ($cloudConfig) {
        Install-ScoopPackage "aws" -ShouldInstall (Get-ConfigValue $cloudConfig "aws-cli")
        Install-ScoopPackage "azure-cli" -ShouldInstall (Get-ConfigValue $cloudConfig "azure-cli")
        Install-ScoopPackage "gcloud" -ShouldInstall (Get-ConfigValue $cloudConfig "gcloud")
        Install-ScoopPackage "terraform" -ShouldInstall (Get-ConfigValue $cloudConfig "terraform")
        Install-ScoopPackage "packer" -ShouldInstall (Get-ConfigValue $cloudConfig "packer")
        Install-ScoopPackage "vault" -ShouldInstall (Get-ConfigValue $cloudConfig "vault")
        Install-ScoopPackage "consul" -ShouldInstall (Get-ConfigValue $cloudConfig "consul")
        Install-ScoopPackage "ansible" -ShouldInstall (Get-ConfigValue $cloudConfig "ansible")
    }
    
    # ========================================================================
    # BUILD TOOLS
    # ========================================================================
    
    Write-Section "Build Tools"
    
    $buildConfig = $config.UserLevel.BuildTools
    if ($buildConfig) {
        Install-ScoopPackage "cmake" -ShouldInstall (Get-ConfigValue $buildConfig "cmake")
        Install-ScoopPackage "ninja" -ShouldInstall (Get-ConfigValue $buildConfig "ninja")
        Install-ScoopPackage "meson" -ShouldInstall (Get-ConfigValue $buildConfig "meson")
        Install-ScoopPackage "bazel" -ShouldInstall (Get-ConfigValue $buildConfig "bazel")
        Install-ScoopPackage "task" -ShouldInstall (Get-ConfigValue $buildConfig "task")
    }
    
    # ========================================================================
    # EDITORS
    # ========================================================================
    
    Write-Section "Editors"
    
    $editorConfig = $config.UserLevel.Editors
    if ($editorConfig) {
        Install-ScoopPackage "vscode" -Bucket "extras" -ShouldInstall (Get-ConfigValue $editorConfig "vscode")
        Install-ScoopPackage "neovim" -ShouldInstall (Get-ConfigValue $editorConfig "neovim")
        Install-ScoopPackage "vim" -ShouldInstall (Get-ConfigValue $editorConfig "vim")
        Install-ScoopPackage "nano" -ShouldInstall (Get-ConfigValue $editorConfig "nano")
        Install-ScoopPackage "sublime-text" -Bucket "extras" -ShouldInstall (Get-ConfigValue $editorConfig "sublime-text")
        Install-ScoopPackage "jetbrains-toolbox" -Bucket "extras" -ShouldInstall (Get-ConfigValue $editorConfig "jetbrains-toolbox")
    }
    
    # ========================================================================
    # TESTING TOOLS
    # ========================================================================
    
    Write-Section "Testing Tools"
    
    $testConfig = $config.UserLevel.Testing
    if ($testConfig) {
        Install-ScoopPackage "postman" -Bucket "extras" -ShouldInstall (Get-ConfigValue $testConfig "postman")
        Install-ScoopPackage "insomnia" -Bucket "extras" -ShouldInstall (Get-ConfigValue $testConfig "insomnia")
        Install-ScoopPackage "httpie" -ShouldInstall (Get-ConfigValue $testConfig "httpie")
        Install-ScoopPackage "hey" -ShouldInstall (Get-ConfigValue $testConfig "hey")
        Install-ScoopPackage "k6" -Bucket "extras" -ShouldInstall (Get-ConfigValue $testConfig "k6")
    }
    
    # ========================================================================
    # SECURITY TOOLS
    # ========================================================================
    
    Write-Section "Security Tools"
    
    $securityConfig = $config.UserLevel.Security
    if ($securityConfig) {
        Install-ScoopPackage "nmap" -Bucket "extras" -ShouldInstall (Get-ConfigValue $securityConfig "nmap")
        Install-ScoopPackage "openssl" -ShouldInstall (Get-ConfigValue $securityConfig "openssl")
        Install-ScoopPackage "putty" -Bucket "extras" -ShouldInstall (Get-ConfigValue $securityConfig "putty")
        Install-ScoopPackage "winscp" -Bucket "extras" -ShouldInstall (Get-ConfigValue $securityConfig "winscp")
        Install-ScoopPackage "mkcert" -ShouldInstall (Get-ConfigValue $securityConfig "mkcert")
    }
    
    # ========================================================================
    # DOCUMENTATION
    # ========================================================================
    
    Write-Section "Documentation Tools"
    
    $docConfig = $config.UserLevel.Documentation
    if ($docConfig) {
        Install-ScoopPackage "pandoc" -ShouldInstall (Get-ConfigValue $docConfig "pandoc")
        Install-ScoopPackage "hugo" -ShouldInstall (Get-ConfigValue $docConfig "hugo")
        Install-ScoopPackage "mdbook" -ShouldInstall (Get-ConfigValue $docConfig "mdbook")
        Install-ScoopPackage "markdownlint-cli" -ShouldInstall (Get-ConfigValue $docConfig "markdownlint-cli")
    }
    
    # ========================================================================
    # TERMINAL ENHANCEMENTS
    # ========================================================================
    
    Write-Section "Terminal Enhancements"
    
    $termConfig = $config.UserLevel.Terminal
    if ($termConfig) {
        Install-ScoopPackage "starship" -ShouldInstall (Get-ConfigValue $termConfig "starship")
        Install-ScoopPackage "zoxide" -ShouldInstall (Get-ConfigValue $termConfig "zoxide")
        Install-ScoopPackage "tldr" -ShouldInstall (Get-ConfigValue $termConfig "tldr")
    }
    
    # ========================================================================
    # VERSION CONTROL
    # ========================================================================
    
    Write-Section "Version Control Helpers"
    
    $vcConfig = $config.UserLevel.VersionControl
    if ($vcConfig) {
        Install-ScoopPackage "git-lfs" -ShouldInstall (Get-ConfigValue $vcConfig "git-lfs")
        Install-ScoopPackage "lazygit" -ShouldInstall (Get-ConfigValue $vcConfig "lazygit")
        Install-ScoopPackage "delta" -ShouldInstall (Get-ConfigValue $vcConfig "delta")
        Install-ScoopPackage "tig" -ShouldInstall (Get-ConfigValue $vcConfig "tig")
    }
    
    # ========================================================================
    # UTILITIES
    # ========================================================================
    
    Write-Section "Utilities"
    
    $utilConfig = $config.UserLevel.Utilities
    if ($utilConfig) {
        Install-ScoopPackage "glab" -ShouldInstall (Get-ConfigValue $utilConfig "gitlab-cli")
        Install-ScoopPackage "rclone" -ShouldInstall (Get-ConfigValue $utilConfig "rclone")
        Install-ScoopPackage "ffmpeg" -ShouldInstall (Get-ConfigValue $utilConfig "ffmpeg")
        Install-ScoopPackage "imagemagick" -ShouldInstall (Get-ConfigValue $utilConfig "imagemagick")
        Install-ScoopPackage "watchexec" -ShouldInstall (Get-ConfigValue $utilConfig "watchexec")
        Install-ScoopPackage "entr" -ShouldInstall (Get-ConfigValue $utilConfig "entr")
        Install-ScoopPackage "direnv" -ShouldInstall (Get-ConfigValue $utilConfig "direnv")
        Install-ScoopPackage "just" -ShouldInstall (Get-ConfigValue $utilConfig "just")
        
        # Claude Code - AI coding assistant CLI
        if (Get-ConfigValue $utilConfig "claude-code") {
            Write-Host "`nClaude Code" -ForegroundColor Yellow
            
            if (-not (Test-CommandExists npm)) {
                Write-Host "  ✗ npm not found. Install Node.js first." -ForegroundColor Red
            }
            elseif (Test-CommandExists claude) {
                Write-Host "  ✓ claude-code already installed" -ForegroundColor Green
            }
            else {
                Write-Host "  → Installing Claude Code via npm..." -ForegroundColor Cyan
                npm install -g @anthropic-ai/claude-code --silent 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ Claude Code installed" -ForegroundColor Green
                    Write-Host "  Run 'claude --help' to get started" -ForegroundColor Cyan
                } else {
                    Write-Host "  ✗ Failed to install Claude Code via npm" -ForegroundColor Red
                    Write-Host "  → Try manually: npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
                }
            }
        }
    }

    # ========================================================================
    # POWERSHELL MODULES
    # ========================================================================

    Write-Section "PowerShell Modules"

    $psModulesConfig = $config.UserLevel.PowerShellModules
    if ($psModulesConfig) {
        Install-PowerShellModules -ModulesConfig $psModulesConfig -ModulesSourcePath $ModulesPath
    }
    else {
        Write-Host "  ⊘ No PowerShell modules configured" -ForegroundColor Gray
    }

    # ========================================================================
    # FONTS
    # ========================================================================
    
    Write-Section "Fonts"
    
    $fontConfig = $config.UserLevel.Fonts
    if ($fontConfig) {
        Install-ScoopPackage "FiraCode-NF" -Bucket "nerd-fonts" -ShouldInstall (Get-ConfigValue $fontConfig "firacode-nf")
        Install-ScoopPackage "CascadiaCode-NF" -Bucket "nerd-fonts" -ShouldInstall (Get-ConfigValue $fontConfig "cascadiacode-nf")
        Install-ScoopPackage "JetBrainsMono-NF" -Bucket "nerd-fonts" -ShouldInstall (Get-ConfigValue $fontConfig "jetbrainsmono-nf")
    }
    
    # ========================================================================
    # CONFIGURE GIT
    # ========================================================================
    
    if (Test-CommandExists git) {
        Write-Section "Configuring Git"
        
        git config --global core.editor "code --wait" 2>$null
        
        if (Test-CommandExists delta) {
            git config --global core.pager delta
            git config --global interactive.diffFilter "delta --color-only"
            git config --global delta.navigate true
            git config --global merge.conflictstyle diff3
            git config --global diff.colorMoved default
        }
        
        git config --global alias.st status
        git config --global alias.co checkout
        git config --global alias.br branch
        git config --global alias.ci commit
        git config --global alias.unstage "reset HEAD --"
        git config --global alias.last "log -1 HEAD"
        git config --global alias.lg "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
        
        Write-Host "  ✓ Git configured" -ForegroundColor Green
    }
    
    # ========================================================================
    # CONFIGURE POWERSHELL PROFILE
    # ========================================================================
    
    Write-Section "PowerShell Profile"
    
    $profileContent = @'
# Development Environment Profile - Auto-generated by setup-dev-environment.ps1

# Starship Prompt
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# Zoxide (better cd)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# PSReadLine configuration
if (Get-Module -ListAvailable -Name PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
}

# Aliases
Set-Alias -Name vim -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name cat -Value bat -ErrorAction SilentlyContinue
Set-Alias -Name grep -Value rg -ErrorAction SilentlyContinue
Set-Alias -Name find -Value fd -ErrorAction SilentlyContinue

# Unix tools fallbacks (use busybox if standalone not available)
if (-not (Get-Command tree -ErrorAction SilentlyContinue)) {
    function tree { busybox tree @args }
}

if (-not (Get-Command rsync -ErrorAction SilentlyContinue)) {
    function rsync { busybox rsync @args }
}

# Utility functions
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force @args }
function which ($cmd) { Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path }
function touch ($file) { "" | Out-File $file -Encoding ASCII }
function mkcd ($dir) { mkdir $dir -Force; Set-Location $dir }

# Git shortcuts
function gs { git status }
function ga { git add @args }
function gc { git commit @args }
function gp { git push @args }
function gl { git pull @args }
function gd { git diff @args }
function gco { git checkout @args }

Write-Host "Dev environment loaded! Ready to code." -ForegroundColor Green
'@
    
    if (-not (Test-Path $PROFILE)) {
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }
    
    $existingContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($existingContent -notmatch "Dev environment loaded") {
        $profileContent | Out-File -FilePath $PROFILE -Encoding UTF8 -Append
        Write-Host "  ✓ PowerShell profile configured" -ForegroundColor Green
    } else {
        Write-Host "  ✓ PowerShell profile already configured" -ForegroundColor Green
    }
    
    Write-Host "  → Restart terminal or run: . `$PROFILE" -ForegroundColor Yellow
    
    # ========================================================================
    # SUMMARY
    # ========================================================================
    
    Write-Section "Installation Complete!"
    
    Write-Host @"

╔═══════════════════════════════════════════════════════════╗
║              USER-LEVEL INSTALLATION COMPLETE!            ║
╚═══════════════════════════════════════════════════════════╝

Installation Location: $installPath
📋 Configuration File: $ConfigFile

All selected tools have been installed!

NEXT STEPS:

1. Restart your terminal (or run: . `$PROFILE)

2. Verify PATH:
   echo `$env:PATH | Select-String scoop

3. Test installations:
   git --version
   python --version
   node --version
   kubectl version --client

4. Configure Git:
   git config --global user.name "Your Name"
   git config --global user.email "your@email.com"

5. (Optional) Install admin tools:
   Right-click PowerShell → Run as Administrator
   .\setup-dev-environment.ps1 -ToolsAdminRights

Useful commands:
   scoop update *          # Update all packages
   scoop list              # List installed
   scoop search <name>     # Search packages
   scoop cleanup *         # Remove old versions

Installation paths:
   Tools: $installPath\apps
   Shims: $installPath\shims
   Config: $ConfigFile

Happy Coding!

"@ -ForegroundColor Green
    
    # Verification
    Write-Section "Verification"
    
    $commandsToCheck = @(
        "git", "python", "node", "npm", "go", "docker", "kubectl",
        "sed", "grep", "awk", "curl", "jq", "code", "mc"
    )
    
    Write-Host "`nChecking installed commands:" -ForegroundColor Cyan
    $installedCount = 0
    foreach ($cmd in $commandsToCheck) {
        if (Test-CommandExists $cmd) {
            Write-Host "  ✓ $cmd" -ForegroundColor Green
            $installedCount++
        } else {
            Write-Host "  ✗ $cmd (not found)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n$installedCount of $($commandsToCheck.Count) core tools verified" -ForegroundColor Green
}

# ============================================================================
# ADMIN-LEVEL TOOLS
# ============================================================================

if ($ToolsAdminRights) {
    
    Write-Section "🔐 Admin-Level Tools"
    
    if (-not (Test-CommandExists winget)) {
        Write-Host @"
  ⚠️  Winget not found - Admin tools require Windows Package Manager

  Install winget from:
     https://github.com/microsoft/winget-cli/releases

  Or install via Microsoft Store:
     Search for "App Installer" and install/update it

  Once winget is installed, run this again:
     .\setup-dev-environment.ps1 -ToolsAdminRights

"@ -ForegroundColor Yellow
        
        if ($ForceAdmin) {
            Write-Host "  → Skipping admin tools section (winget not available)" -ForegroundColor Gray
            Write-Host "`nUser-level tools installation complete!" -ForegroundColor Green
            Write-Host "   Install winget to enable admin tools installation.`n" -ForegroundColor Cyan
            return
        } else {
            exit 1
        }
    }
    
    # ========================================================================
    # FORCE INSTALL MODE - Skip all sections and install only specified tools
    # ========================================================================
    
    if ($ForceInstall.Count -gt 0) {
        Write-Section "🎯 Force Install Mode - Installing Specified Admin Tools Only"
        
        foreach ($tool in $ForceInstall) {
            Write-Host "`n→ Force installing: $tool" -ForegroundColor Magenta
            
            # For admin tools, try winget
            Write-Host "  → Installing $tool via winget..." -ForegroundColor Cyan
            winget install $tool --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ $tool installed successfully" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Failed to install $tool" -ForegroundColor Red
                Write-Host "  Try: winget search $tool" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nForce install complete!" -ForegroundColor Green
        Write-Host "Installed tools: $($ForceInstall -join ', ')" -ForegroundColor Cyan
        exit 0
    }
    
    $adminConfig = $config.AdminLevel.SystemTools
    
    if ($adminConfig) {
        Write-Host "`nSystem Tools" -ForegroundColor Yellow
        
        Install-WingetPackage "Docker.DockerDesktop" "Docker Desktop" `
            -ShouldInstall (Get-ConfigValue $adminConfig "docker-desktop")
        
        Install-WingetPackage "WiresharkFoundation.Wireshark" "Wireshark" `
            -ShouldInstall (Get-ConfigValue $adminConfig "wireshark")
        
        Install-WingetPackage "Microsoft.PowerToys" "PowerToys" `
            -ShouldInstall (Get-ConfigValue $adminConfig "powertoys")
        
        Install-WingetPackage "Microsoft.WindowsTerminal" "Windows Terminal" `
            -ShouldInstall (Get-ConfigValue $adminConfig "windows-terminal")
        
        Install-WingetPackage "Notepad++.Notepad++" "Notepad++" `
            -ShouldInstall (Get-ConfigValue $adminConfig "notepadplusplus")
        
        Install-BeyondCompare -ShouldInstall (Get-ConfigValue $adminConfig "beyondcompare")
    }
    
    $browserConfig = $config.AdminLevel.Browsers
    if ($browserConfig) {
        Write-Host "`nBrowsers" -ForegroundColor Yellow
        
        Install-WingetPackage "Google.Chrome" "Google Chrome" `
            -ShouldInstall (Get-ConfigValue $browserConfig "chrome")
        
        Install-WingetPackage "Mozilla.Firefox" "Firefox" `
            -ShouldInstall (Get-ConfigValue $browserConfig "firefox")
    }
    
    Write-Section "Admin Installation Complete!"
    
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║             🎉 ADMIN-LEVEL INSTALLATION COMPLETE! 🎉           ║
╚════════════════════════════════════════════════════════════════╝

Selected admin tools have been installed!

⚠️  IMPORTANT:
- If Docker Desktop was installed, restart your computer
- Some tools may require logout/login to take effect
- Windows Terminal may need to be launched once to complete setup
- PowerToys settings can be configured from the system tray

💡 Next steps:
- Restart your computer if Docker Desktop was installed
- Configure PowerToys keyboard shortcuts
- Set Windows Terminal as default terminal (optional)

"@ -ForegroundColor Green
}

Write-Host "═" * 70 -ForegroundColor Cyan
Write-Host ""
