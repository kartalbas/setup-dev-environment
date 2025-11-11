# Scoop Manager Module

PowerShell module for managing Scoop package manager operations.

## Overview

The Scoop Manager module provides a comprehensive wrapper around the Scoop command-line package manager for Windows. It simplifies package installation, updates, bucket management, and cache cleanup with consistent error handling and user-friendly output.

## Installation

This module is automatically loaded by the setup script when enabled in the configuration file.

### Manual Loading

```powershell
Import-Module "path\to\scoop-manager.ps1" -Force
```

## Prerequisites

- Scoop must be installed
- PowerShell 5.1 or higher
- Windows 10/11

### Install Scoop

If Scoop is not installed, install it first:

```powershell
# Run in PowerShell (non-admin)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex
```

### Check Scoop Availability

```powershell
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "Scoop is available"
} else {
    Write-Host "Scoop is not installed"
}
```

## Functions

### Install-ScoopPackage

Installs a package using Scoop.

**Parameters:**
- `Package` (string, required) - Package name
- `Bucket` (string) - Bucket name (auto-added if needed)
- `DisplayName` (string) - Friendly display name
- `Force` (bool) - Force reinstall (default: false)

**Example:**
```powershell
# Basic installation
Install-ScoopPackage -Package "git"

# Install from specific bucket
Install-ScoopPackage -Package "vscode" -Bucket "extras"

# With display name
Install-ScoopPackage -Package "git" -DisplayName "Git"

# Force reinstall
Install-ScoopPackage -Package "git" -Force $true
```

### Test-ScoopPackageInstalled

Checks if a package is installed via Scoop.

**Parameters:**
- `Package` (string, required) - Package name to check

**Returns:** Boolean

**Example:**
```powershell
$isInstalled = Test-ScoopPackageInstalled -Package "git"
if ($isInstalled) {
    Write-Host "Git is already installed"
} else {
    Install-ScoopPackage -Package "git"
}
```

### Uninstall-ScoopPackage

Uninstalls a package from Scoop.

**Parameters:**
- `Package` (string, required) - Package name to uninstall

**Example:**
```powershell
# Uninstall package
Uninstall-ScoopPackage -Package "git"
```

### Update-ScoopPackage

Updates one or all packages.

**Parameters:**
- `Package` (string) - Specific package name, or empty for all packages

**Example:**
```powershell
# Update specific package
Update-ScoopPackage -Package "git"

# Update all packages
Update-ScoopPackage

# Update Scoop itself
scoop update
```

### Search-ScoopPackage

Searches for packages in Scoop repositories.

**Parameters:**
- `Query` (string, required) - Search query

**Returns:** Array of matching packages

**Example:**
```powershell
# Search for packages
$results = Search-ScoopPackage -Query "python"
$results | ForEach-Object {
    Write-Host $_
}
```

### Get-ScoopInstalledPackages

Lists all packages installed via Scoop.

**Returns:** Array of installed packages

**Example:**
```powershell
# Get all installed packages
$installed = Get-ScoopInstalledPackages
Write-Host "Total packages: $($installed.Count)"

$installed | ForEach-Object {
    Write-Host "  $_"
}
```

### Add-ScoopBucket

Adds a Scoop bucket (repository).

**Parameters:**
- `Bucket` (string, required) - Bucket name

**Example:**
```powershell
# Add common buckets
Add-ScoopBucket -Bucket "extras"
Add-ScoopBucket -Bucket "versions"
Add-ScoopBucket -Bucket "java"
Add-ScoopBucket -Bucket "nerd-fonts"
```

### Get-ScoopPath

Gets the Scoop installation path.

**Returns:** String with Scoop path

**Example:**
```powershell
$scoopPath = Get-ScoopPath
Write-Host "Scoop installed at: $scoopPath"

$shimsPath = Join-Path $scoopPath "shims"
Write-Host "Shims at: $shimsPath"
```

### Clear-ScoopCache

Cleans up old package versions from cache.

**Parameters:**
- `Package` (string) - Specific package, or empty for all

**Example:**
```powershell
# Clear cache for specific package
Clear-ScoopCache -Package "git"

# Clear all cache
Clear-ScoopCache
```

## Common Scoop Buckets

### Default Buckets

```powershell
# Main bucket (included by default)
# Contains core CLI tools

# Extras bucket - GUI applications
Add-ScoopBucket -Bucket "extras"

# Versions bucket - Alternative versions
Add-ScoopBucket -Bucket "versions"

# Java bucket - Java versions
Add-ScoopBucket -Bucket "java"

# Nerd Fonts bucket - Programming fonts
Add-ScoopBucket -Bucket "nerd-fonts"
```

## Usage Patterns

### Pattern 1: Check Before Install

```powershell
$package = "git"

if (-not (Test-ScoopPackageInstalled -Package $package)) {
    Write-Host "Installing $package..."
    Install-ScoopPackage -Package $package -DisplayName "Git"
} else {
    Write-Host "$package is already installed"
}
```

### Pattern 2: Install Multiple Packages

```powershell
$packages = @(
    @{ Name = "git"; Display = "Git" }
    @{ Name = "curl"; Display = "curl" }
    @{ Name = "wget"; Display = "wget" }
    @{ Name = "jq"; Display = "jq" }
)

foreach ($pkg in $packages) {
    if (-not (Test-ScoopPackageInstalled -Package $pkg.Name)) {
        Install-ScoopPackage -Package $pkg.Name -DisplayName $pkg.Display
    }
}
```

### Pattern 3: Install with Bucket

```powershell
# Packages from extras bucket
$extrasPackages = @(
    @{ Name = "vscode"; Bucket = "extras" }
    @{ Name = "sublime-text"; Bucket = "extras" }
)

foreach ($pkg in $extrasPackages) {
    Install-ScoopPackage -Package $pkg.Name -Bucket $pkg.Bucket
}
```

### Pattern 4: Update All Packages

```powershell
Write-Host "Updating Scoop..."
scoop update

Write-Host "Updating all packages..."
Update-ScoopPackage  # Updates all

Write-Host "Cleaning up old versions..."
Clear-ScoopCache
```

### Pattern 5: Complete Setup

```powershell
# Add buckets
$buckets = @("extras", "versions", "java", "nerd-fonts")
foreach ($bucket in $buckets) {
    Add-ScoopBucket -Bucket $bucket
}

# Install packages
$packages = @("git", "curl", "wget", "jq", "ripgrep", "fd")
foreach ($package in $packages) {
    Install-ScoopPackage -Package $package
}

# Install from extras
Install-ScoopPackage -Package "vscode" -Bucket "extras"

# Update PATH
$scoopPath = Get-ScoopPath
$shimsPath = Join-Path $scoopPath "shims"
# Add to PATH using path-manager module
Add-ToPath -Path $shimsPath
```

## Common Packages

### Core Tools
```powershell
Install-ScoopPackage -Package "git"           # Git
Install-ScoopPackage -Package "curl"          # curl
Install-ScoopPackage -Package "wget"          # wget
Install-ScoopPackage -Package "jq"            # JSON processor
Install-ScoopPackage -Package "yq"            # YAML processor
```

### Search & Navigation
```powershell
Install-ScoopPackage -Package "ripgrep"       # Fast grep
Install-ScoopPackage -Package "fd"            # Fast find
Install-ScoopPackage -Package "fzf"           # Fuzzy finder
Install-ScoopPackage -Package "bat"           # Better cat
Install-ScoopPackage -Package "tree"          # Directory tree
```

### Compression
```powershell
Install-ScoopPackage -Package "7zip"          # 7-Zip
Install-ScoopPackage -Package "zip"           # zip/unzip
```

### Editors (from extras)
```powershell
Install-ScoopPackage -Package "vscode" -Bucket "extras"
Install-ScoopPackage -Package "sublime-text" -Bucket "extras"
Install-ScoopPackage -Package "notepadplusplus" -Bucket "extras"
```

### Fonts (from nerd-fonts)
```powershell
Install-ScoopPackage -Package "FiraCode-NF" -Bucket "nerd-fonts"
Install-ScoopPackage -Package "CascadiaCode-NF" -Bucket "nerd-fonts"
```

## Error Handling

All functions include comprehensive error handling:

```powershell
try {
    Install-ScoopPackage -Package "git"
}
catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    # Fallback or alternative action
}
```

## Verbose Output

Enable verbose output for detailed operation logging:

```powershell
Install-ScoopPackage -Package "git" -Verbose
Update-ScoopPackage -Verbose
```

## Troubleshooting

### Scoop Not Found

```powershell
# Check if Scoop is installed
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Scoop is not installed"
    Write-Host "Install from: https://scoop.sh"
}
```

### Package Not Found

```powershell
# Search before installing
$results = Search-ScoopPackage -Query "python"
if ($results.Count -eq 0) {
    Write-Host "No packages found. Try different search term or add bucket."
    Add-ScoopBucket -Bucket "versions"
    $results = Search-ScoopPackage -Query "python"
}
```

### Bucket Not Available

```powershell
# Add bucket before installing package
Add-ScoopBucket -Bucket "extras"
Install-ScoopPackage -Package "vscode" -Bucket "extras"
```

### PATH Not Updated

```powershell
# Verify Scoop shims are in PATH
$scoopPath = Get-ScoopPath
$shimsPath = Join-Path $scoopPath "shims"

if (-not (Test-InPath -Path $shimsPath)) {
    Add-ToPath -Path $shimsPath
    Refresh-SessionPath
}
```

## Best Practices

1. **Add buckets first**
   ```powershell
   Add-ScoopBucket -Bucket "extras"
   Install-ScoopPackage -Package "vscode" -Bucket "extras"
   ```

2. **Check before installing**
   ```powershell
   if (-not (Test-ScoopPackageInstalled -Package "git")) {
       Install-ScoopPackage -Package "git"
   }
   ```

3. **Update regularly**
   ```powershell
   scoop update           # Update Scoop itself
   Update-ScoopPackage    # Update all packages
   ```

4. **Clean cache periodically**
   ```powershell
   Clear-ScoopCache       # Remove old versions
   ```

5. **Use main bucket for CLI tools, extras for GUI apps**
   ```powershell
   Install-ScoopPackage -Package "git"                    # CLI - main bucket
   Install-ScoopPackage -Package "vscode" -Bucket "extras" # GUI - extras bucket
   ```

## Advantages of Scoop

- **No admin rights required** - Installs to user directory
- **Portable** - Easy to backup and restore
- **No UAC prompts** - User-level installations
- **Clean uninstalls** - No registry pollution
- **Version management** - Easy to switch versions
- **Shim system** - All executables in one place

## Requirements

- PowerShell 5.1 or higher
- Windows 10/11
- Scoop package manager
- Internet connection for package downloads

## Version

Current Version: 1.0.0

## Related Modules

- [path-manager](../path-manager/README.md) - PATH environment variable management
- [winget-manager](../winget-manager/README.md) - Windows Package Manager operations

## License

MIT License - See [LICENSE](../../../LICENSE)
