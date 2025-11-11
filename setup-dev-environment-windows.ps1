# setup-dev-environment.ps1
# Dynamic development environment setup with configuration file
# Config file: setup-dev-environment-windows.config
# Version: 4.0.0
#
# Changelog:
# v4.0.0 - BREAKING: Renamed config to setup-dev-environment-windows.config
#          Changed to official NVM for Windows (removed Scoop's NVM)
#          Node.js now installed via NVM LTS only
#          Yarn installed via Corepack or official installer
#          pnpm installed via official installer
#          Simplified Node.js setup (removed complex NVM configuration)
# v3.1.4 - Fixed: ForceInstall now handles claude-code (npm package) correctly
#          Automatically installs Node.js if needed when installing claude-code
# v3.1.3 - Fixed: Admin tools section now gracefully skips when winget is missing in ForceAdmin mode
#          Enabled Node.js by default in config (required for Claude Code)
# v3.1.2 - Added winget availability check with Scoop fallback for Git installation
#          Script now gracefully handles missing winget by installing git via Scoop
# v3.1.1 - Fixed: ForceAdmin now properly installs Scoop with -RunAsAdmin parameter
#          Fixed: Environment variables use Machine scope when ForceAdmin is enabled
# v3.1.0 - Added -ForceAdmin parameter to install all tools with admin rights
#          Bypasses Scoop's security restrictions (NOT RECOMMENDED for regular use)
# v3.0.2 - Fixed: Skip bucket addition in ForceInstall mode to avoid git errors
# v3.0.1 - Fixed ForceInstall mode to use Git for Windows instead of Scoop's git
#          Auto-removes Scoop's git if present before installing Git for Windows
# v3.0 - Changed to install Git for Windows (via winget) instead of Scoop's git
#        Automatically sets CLAUDE_CODE_GIT_BASH_PATH for Claude Code compatibility
# v2.9.2 - Fixed ForceInstall to skip all sections and install only specified tools
# v2.9.1 - Fixed config parser to properly handle inline comments
# v2.9 - Added -ForceInstall parameter to install specific tools regardless of config
#        Added ArgoCD CLI to configuration
# v2.8 - Added Claude Code CLI installation (AI coding assistant)
# v2.7 - Fixed NVM PATH cleanup (removes wrong nodejs\nodejs paths from Scoop)
# v2.6 - Added Beyond Compare with auto-download of latest version from website
# v2.5 - Added Argo CD CLI for Kubernetes GitOps workflows
# v2.4 - Added Flutter SDK installation support
# v2.3 - Added both NVM_HOME and NVM_SYMLINK to PATH for complete functionality
# v2.2 - Added NVM_SYMLINK to PATH for node/npm command access
# v2.1 - Fixed NVM configuration: automatically creates settings.txt and sets environment variables
# v2.0 - Updated startup message for better UX

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
    $ConfigFile = Join-Path $scriptDir "$scriptName-windows.config"
}

if (-not (Test-Path $ConfigFile)) {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                     ⚠️  CONFIG FILE NOT FOUND  ⚠️               ║
╚════════════════════════════════════════════════════════════════╝

Configuration file not found: $ConfigFile

Please create the configuration file or specify a different path:
  .\setup-dev-environment.ps1 -ToolsUserRights -ConfigFile "path\to\config"

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

Write-Host "⚙️  Parsing configuration file..." -ForegroundColor Cyan
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

# Check if modules configuration exists
if ($config.General.ContainsKey("Modules")) {
    Write-Host "`n📦 Loading modules..." -ForegroundColor Cyan

    $modulesConfig = $config.General.Modules
    $modulesLoaded = 0
    $modulesFailed = 0

    # Load path-manager module
    if ($modulesConfig.ContainsKey("path-manager") -and $modulesConfig["path-manager"]) {
        $pathManagerPath = Join-Path $ModulesPath "path-manager\path-manager.ps1"
        if (Test-Path $pathManagerPath) {
            try {
                Import-Module $pathManagerPath -Force -ErrorAction Stop
                Write-Host "  ✓ path-manager loaded" -ForegroundColor Green
                $modulesLoaded++
            }
            catch {
                Write-Host "  ✗ Failed to load path-manager: $_" -ForegroundColor Red
                $modulesFailed++
            }
        }
        else {
            Write-Host "  ✗ path-manager.ps1 not found at: $pathManagerPath" -ForegroundColor Red
            $modulesFailed++
        }
    }

    # Load winget-manager module
    if ($modulesConfig.ContainsKey("winget-manager") -and $modulesConfig["winget-manager"]) {
        $wingetManagerPath = Join-Path $ModulesPath "winget-manager\winget-manager.ps1"
        if (Test-Path $wingetManagerPath) {
            try {
                Import-Module $wingetManagerPath -Force -ErrorAction Stop
                Write-Host "  ✓ winget-manager loaded" -ForegroundColor Green
                $modulesLoaded++
            }
            catch {
                Write-Host "  ✗ Failed to load winget-manager: $_" -ForegroundColor Red
                $modulesFailed++
            }
        }
        else {
            Write-Host "  ✗ winget-manager.ps1 not found at: $wingetManagerPath" -ForegroundColor Red
            $modulesFailed++
        }
    }

    # Load scoop-manager module
    if ($modulesConfig.ContainsKey("scoop-manager") -and $modulesConfig["scoop-manager"]) {
        $scoopManagerPath = Join-Path $ModulesPath "scoop-manager\scoop-manager.ps1"
        if (Test-Path $scoopManagerPath) {
            try {
                Import-Module $scoopManagerPath -Force -ErrorAction Stop
                Write-Host "  ✓ scoop-manager loaded" -ForegroundColor Green
                $modulesLoaded++
            }
            catch {
                Write-Host "  ✗ Failed to load scoop-manager: $_" -ForegroundColor Red
                $modulesFailed++
            }
        }
        else {
            Write-Host "  ✗ scoop-manager.ps1 not found at: $scoopManagerPath" -ForegroundColor Red
            $modulesFailed++
        }
    }

    if ($modulesLoaded -gt 0) {
        Write-Host "✓ $modulesLoaded module(s) loaded successfully" -ForegroundColor Green
    }
    if ($modulesFailed -gt 0) {
        Write-Host "⚠️  $modulesFailed module(s) failed to load" -ForegroundColor Yellow
    }
}
else {
    Write-Host "`n⚠️  No module configuration found in config file" -ForegroundColor Yellow
    Write-Host "  Add [General.Modules] section to enable module loading" -ForegroundColor Gray
}

# ============================================================================
# VALIDATE PARAMETERS
# ============================================================================

if (-not $ToolsUserRights -and -not $ToolsAdminRights) {
    Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║                     ⚠️  MISSING PARAMETER  ⚠️                   ║
╚════════════════════════════════════════════════════════════════╝

Please specify installation mode:

  -ToolsUserRights     Install user-level tools (NO ADMIN)
  -ToolsAdminRights    Install admin-level tools (REQUIRES ADMIN)
  -ForceAdmin          Install EVERYTHING with admin rights (NOT RECOMMENDED)
                       Bypasses Scoop security restrictions

Optional parameters:

  -ForceInstall <tool1>,<tool2>,...
                      Install ONLY these specific tools (ignores config)

Examples:

  .\setup-dev-environment.ps1 -ToolsUserRights
  .\setup-dev-environment.ps1 -ToolsAdminRights
  .\setup-dev-environment.ps1 -ForceAdmin
  .\setup-dev-environment.ps1 -ToolsUserRights -ForceInstall argocd
  .\setup-dev-environment.ps1 -ToolsUserRights -ForceInstall argocd,terraform,kubectl


Edit $ConfigFile to select which tools to install.

"@ -ForegroundColor Yellow
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
╔════════════════════════════════════════════════════════════════╗
║                          ⚠️  ERROR  ⚠️                          ║
╚════════════════════════════════════════════════════════════════╝

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
║     🚀 CLAUDE CODE DEVELOPMENT ENVIRONMENT INSTALLER 🚀        ║
║                                                                ║
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
    Write-Host "`n" -NoNewline
    Write-Host "═" * 70 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "═" * 70 -ForegroundColor Cyan
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
        scoop install $Package 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ $Package installed" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to install $Package" -ForegroundColor Red
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
        Write-Host "  ℹ️  Note: Claude Code requires git-bash. Install Git for Windows manually for full support." -ForegroundColor Cyan
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
        
        Write-Host "  💡 Restart your terminal to use git" -ForegroundColor Yellow
    } else {
        Write-Host "  ✗ Failed to install Git for Windows" -ForegroundColor Red
        Write-Host "  💡 Falling back to Scoop's git..." -ForegroundColor Yellow
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
        # Download latest NVM for Windows installer
        $nvmVersion = "1.1.12"  # Latest stable version
        $installerUrl = "https://github.com/coreybutler/nvm-windows/releases/download/$nvmVersion/nvm-setup.exe"
        $installerPath = Join-Path $env:TEMP "nvm-setup.exe"

        Write-Host "  → Downloading NVM $nvmVersion..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop

        Write-Host "  → Running installer (this may take a moment)..." -ForegroundColor Gray
        Start-Process -FilePath $installerPath -ArgumentList "/VERYSILENT" -Wait -NoNewWindow

        # Cleanup
        Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

        # Refresh environment
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
                Write-Host "  💡 Restart terminal to use node/npm commands" -ForegroundColor Yellow
            } else {
                Write-Host "  ⚠ Node.js installed but not in PATH yet" -ForegroundColor Yellow
                Write-Host "  💡 Restart terminal and run: nvm use lts" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ✗ NVM installation may have failed" -ForegroundColor Red
            Write-Host "  💡 Download manually from: https://github.com/coreybutler/nvm-windows/releases" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ✗ Failed to install NVM: $_" -ForegroundColor Red
        Write-Host "  💡 Download manually from: https://github.com/coreybutler/nvm-windows/releases" -ForegroundColor Yellow
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
        iwr https://get.pnpm.io/install.ps1 -useb | iex

        if (Test-CommandExists pnpm) {
            Write-Host "  ✓ pnpm installed successfully" -ForegroundColor Green
        } else {
            Write-Host "  ✗ pnpm installation failed" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ Failed to install pnpm: $_" -ForegroundColor Red
        Write-Host "  💡 Try manually: iwr https://get.pnpm.io/install.ps1 -useb | iex" -ForegroundColor Yellow
    }
}

# ============================================================================
# USER-LEVEL TOOLS INSTALLATION
# ============================================================================

if ($ToolsUserRights) {
    
    # ========================================================================
    # INSTALL SCOOP
    # ========================================================================
    
    Write-Section "📦 Installing Scoop Package Manager"
    
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
            iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
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
        scoop bucket add extras 2>&1 | Out-Null
        scoop bucket add versions 2>&1 | Out-Null
        scoop bucket add java 2>&1 | Out-Null
        scoop bucket add nerd-fonts 2>&1 | Out-Null
    }
    
    # Update PATH
    $scoopShims = Join-Path $installPath "shims"
    if (Test-Path $scoopShims) {
        Update-SystemPath $scoopShims
    }
    
    # ========================================================================
    # FORCE INSTALL MODE - Skip all sections and install only specified tools
    # ========================================================================
    
    if ($ForceInstall.Count -gt 0) {
        Write-Section "🎯 Force Install Mode - Installing Specified Tools Only"
        
        foreach ($tool in $ForceInstall) {
            Write-Host "`n→ Force installing: $tool" -ForegroundColor Magenta
            
            # Special handling for git - use Git for Windows
            if ($tool -eq "git") {
                Install-GitForWindows -ShouldInstall $true
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
                        continue
                    }
                }
                
                # Check if already installed
                $claudeInstalled = npm list -g @anthropic-ai/claude-code 2>&1 | Select-String "@anthropic-ai/claude-code"
                if ($claudeInstalled) {
                    Write-Host "  ✓ claude-code already installed" -ForegroundColor Green
                } else {
                    Write-Host "  → Installing claude-code via npm..." -ForegroundColor Cyan
                    npm install -g @anthropic-ai/claude-code --silent 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "  ✓ claude-code installed successfully" -ForegroundColor Green
                    } else {
                        Write-Host "  ✗ Failed to install claude-code" -ForegroundColor Red
                        Write-Host "  💡 Try manually: npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
                    }
                }
                continue
            }
            
            $installed = scoop list 2>$null | Select-String -Pattern "^$tool "
            if ($installed) {
                Write-Host "  ✓ $tool already installed" -ForegroundColor Green
            } else {
                Write-Host "  → Installing $tool..." -ForegroundColor Cyan
                scoop install $tool 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ $tool installed successfully" -ForegroundColor Green
                } else {
                    Write-Host "  ✗ Failed to install $tool" -ForegroundColor Red
                    Write-Host "  💡 Try: scoop search $tool" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host "`n✅ Force install complete!" -ForegroundColor Green
        Write-Host "Installed tools: $($ForceInstall -join ', ')" -ForegroundColor Cyan
        exit 0
    }
    
    # ========================================================================
    # CORE TOOLS
    # ========================================================================
    
    Write-Section "🔧 Core Development Tools"
    
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
    
    Write-Section "🐧 Unix/Linux Tools"
    
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
                Write-Host "  💡 Tip: Use 'busybox tree' as alternative" -ForegroundColor Yellow
            }
        } elseif (Get-ConfigValue $unixTools "busybox") {
            Write-Host "  💡 Tree available via: busybox tree" -ForegroundColor Gray
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
                Write-Host "  💡 Tip: Use 'busybox rsync' as alternative" -ForegroundColor Yellow
            }
        } elseif (Get-ConfigValue $unixTools "busybox") {
            Write-Host "  💡 Rsync available via: busybox rsync" -ForegroundColor Gray
        }
    }
    
    # ========================================================================
    # PROGRAMMING LANGUAGES
    # ========================================================================
    
    Write-Section "💻 Programming Languages"
    
    # Python (Enhanced with better error handling)
    $pythonConfig = $config.UserLevel.'Languages.Python'
    if ($pythonConfig -and (Get-ConfigValue $pythonConfig "install")) {
        Write-Host "`n📍 Python" -ForegroundColor Yellow
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
        Write-Host "`n📍 Node.js (via NVM)" -ForegroundColor Yellow
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
        Write-Host "`n📍 Go" -ForegroundColor Yellow
        Install-ScoopPackage "go" -ShouldInstall $true
    }
    
    # Rust
    $rustConfig = $config.UserLevel.'Languages.Rust'
    if ($rustConfig -and (Get-ConfigValue $rustConfig "install")) {
        Write-Host "`n📍 Rust" -ForegroundColor Yellow
        Install-ScoopPackage "rustup" -ShouldInstall $true
        if (Test-CommandExists rustup) {
            Write-Host "  → Setting up Rust stable..." -ForegroundColor Gray
            rustup default stable --quiet 2>&1 | Out-Null
        }
    }
    
    # Java
    $javaConfig = $config.UserLevel.'Languages.Java'
    if ($javaConfig -and (Get-ConfigValue $javaConfig "install")) {
        Write-Host "`n📍 Java" -ForegroundColor Yellow
        Install-ScoopPackage "openjdk" -Bucket "java" -ShouldInstall $true
        Install-ScoopPackage "maven" -ShouldInstall (Get-ConfigValue $javaConfig "maven")
        Install-ScoopPackage "gradle" -ShouldInstall (Get-ConfigValue $javaConfig "gradle")
    }
    
    # Ruby
    $rubyConfig = $config.UserLevel.'Languages.Ruby'
    if ($rubyConfig -and (Get-ConfigValue $rubyConfig "install")) {
        Write-Host "`n📍 Ruby" -ForegroundColor Yellow
        Install-ScoopPackage "ruby" -ShouldInstall $true
        if ((Get-ConfigValue $rubyConfig "bundler") -and (Test-CommandExists gem)) {
            Write-Host "  → Installing bundler..." -ForegroundColor Gray
            gem install bundler --quiet
        }
    }
    
    # PHP
    $phpConfig = $config.UserLevel.'Languages.PHP'
    if ($phpConfig -and (Get-ConfigValue $phpConfig "install")) {
        Write-Host "`n📍 PHP" -ForegroundColor Yellow
        Install-ScoopPackage "php" -ShouldInstall $true
        Install-ScoopPackage "composer" -ShouldInstall (Get-ConfigValue $phpConfig "composer")
    }
    
    # .NET
    $dotnetConfig = $config.UserLevel.'Languages.DotNet'
    if ($dotnetConfig -and (Get-ConfigValue $dotnetConfig "install")) {
        Write-Host "`n📍 .NET" -ForegroundColor Yellow
        Install-ScoopPackage "dotnet-sdk" -ShouldInstall $true
    }
    
    # Flutter
    $flutterConfig = $config.UserLevel.'Languages.Flutter'
    if ($flutterConfig -and (Get-ConfigValue $flutterConfig "install")) {
        Write-Host "`n📍 Flutter SDK" -ForegroundColor Yellow
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
            
            Write-Host "  💡 Run 'flutter doctor' to check your Flutter setup" -ForegroundColor Cyan
        }
    }
    
    # ========================================================================
    # DATABASES
    # ========================================================================
    
    Write-Section "🗄️ Databases"
    
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
    
    Write-Section "🐳 Container Tools"
    
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
    
    Write-Section "☁️ Cloud Tools"
    
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
    
    Write-Section "🔨 Build Tools"
    
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
    
    Write-Section "✏️ Editors"
    
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
    
    Write-Section "🧪 Testing Tools"
    
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
    
    Write-Section "🔒 Security Tools"
    
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
    
    Write-Section "📝 Documentation Tools"
    
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
    
    Write-Section "🎨 Terminal Enhancements"
    
    $termConfig = $config.UserLevel.Terminal
    if ($termConfig) {
        Install-ScoopPackage "starship" -ShouldInstall (Get-ConfigValue $termConfig "starship")
        Install-ScoopPackage "zoxide" -ShouldInstall (Get-ConfigValue $termConfig "zoxide")
        Install-ScoopPackage "tldr" -ShouldInstall (Get-ConfigValue $termConfig "tldr")
    }
    
    # ========================================================================
    # VERSION CONTROL
    # ========================================================================
    
    Write-Section "🌿 Version Control Helpers"
    
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
    
    Write-Section "🛠️ Utilities"
    
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
            Write-Host "`n📍 Claude Code" -ForegroundColor Yellow
            
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
                    Write-Host "  💡 Run 'claude --help' to get started" -ForegroundColor Cyan
                } else {
                    Write-Host "  ✗ Failed to install Claude Code via npm" -ForegroundColor Red
                    Write-Host "  → Try manually: npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # ========================================================================
    # FONTS
    # ========================================================================
    
    Write-Section "🔤 Fonts"
    
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
        Write-Section "⚙️ Configuring Git"
        
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
    
    Write-Section "⚙️ PowerShell Profile"
    
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

Write-Host "🚀 Dev environment loaded! Ready to code." -ForegroundColor Green
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
    
    Write-Section "✅ Installation Complete!"
    
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║              🎉 USER-LEVEL INSTALLATION COMPLETE! 🎉           ║
╚════════════════════════════════════════════════════════════════╝

📍 Installation Location: $installPath
📋 Configuration File: $ConfigFile

✅ All selected tools have been installed!

📝 NEXT STEPS:

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

💡 Useful commands:
   scoop update *          # Update all packages
   scoop list              # List installed
   scoop search <name>     # Search packages
   scoop cleanup *         # Remove old versions

📂 Installation paths:
   Tools: $installPath\apps
   Shims: $installPath\shims
   Config: $ConfigFile

Happy Coding! 🚀

"@ -ForegroundColor Green
    
    # Verification
    Write-Section "🔍 Verification"
    
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
    
    Write-Host "`n✅ $installedCount of $($commandsToCheck.Count) core tools verified" -ForegroundColor Green
}

# ============================================================================
# ADMIN-LEVEL TOOLS
# ============================================================================

if ($ToolsAdminRights) {
    
    Write-Section "🔐 Admin-Level Tools"
    
    if (-not (Test-CommandExists winget)) {
        Write-Host @"
  ⚠️  Winget not found - Admin tools require Windows Package Manager

  📦 Install winget from:
     https://github.com/microsoft/winget-cli/releases

  Or install via Microsoft Store:
     Search for "App Installer" and install/update it

  ℹ️  Once winget is installed, run this again:
     .\setup-dev-environment.ps1 -ToolsAdminRights

"@ -ForegroundColor Yellow
        
        if ($ForceAdmin) {
            Write-Host "  → Skipping admin tools section (winget not available)" -ForegroundColor Gray
            Write-Host "`n✅ User-level tools installation complete!" -ForegroundColor Green
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
                Write-Host "  💡 Try: winget search $tool" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`n✅ Force install complete!" -ForegroundColor Green
        Write-Host "Installed tools: $($ForceInstall -join ', ')" -ForegroundColor Cyan
        exit 0
    }
    
    $adminConfig = $config.AdminLevel.SystemTools
    
    if ($adminConfig) {
        Write-Host "`n📍 System Tools" -ForegroundColor Yellow
        
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
        Write-Host "`n📍 Browsers" -ForegroundColor Yellow
        
        Install-WingetPackage "Google.Chrome" "Google Chrome" `
            -ShouldInstall (Get-ConfigValue $browserConfig "chrome")
        
        Install-WingetPackage "Mozilla.Firefox" "Firefox" `
            -ShouldInstall (Get-ConfigValue $browserConfig "firefox")
    }
    
    Write-Section "✅ Admin Installation Complete!"
    
    Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║             🎉 ADMIN-LEVEL INSTALLATION COMPLETE! 🎉           ║
╚════════════════════════════════════════════════════════════════╝

✅ Selected admin tools have been installed!

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
