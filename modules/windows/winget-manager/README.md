# Winget Manager Module

PowerShell module for managing Windows Package Manager (winget) operations.

## Overview

The Winget Manager module provides a comprehensive wrapper around the Windows Package Manager (winget) command-line tool. It simplifies package installation, updates, searches, and management with consistent error handling and user-friendly output.

## Installation

This module is automatically loaded by the setup script when enabled in the configuration file.

### Manual Loading

```powershell
Import-Module "path\to\winget-manager.ps1" -Force
```

## Prerequisites

- Windows Package Manager (winget) must be installed
- Windows 10 1809 (build 17763) or later
- Winget typically comes pre-installed on Windows 11

### Check Winget Availability

```powershell
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Winget is available"
} else {
    Write-Host "Winget is not installed"
}
```

## Functions

### Install-WingetPackage

Installs a package using Windows Package Manager.

**Parameters:**
- `PackageId` (string, required) - Winget package ID (e.g., "Git.Git")
- `Name` (string) - Display name (default: PackageId)
- `Silent` (bool) - Silent installation (default: true)
- `AcceptAgreements` (bool) - Auto-accept agreements (default: true)
- `Force` (bool) - Force reinstall if already installed (default: false)

**Example:**
```powershell
# Basic installation
Install-WingetPackage -PackageId "Git.Git" -Name "Git for Windows"

# Force reinstall
Install-WingetPackage -PackageId "Git.Git" -Force $true

# Interactive installation
Install-WingetPackage -PackageId "Git.Git" -Silent $false
```

### Test-WingetPackageInstalled

Checks if a package is installed via winget.

**Parameters:**
- `PackageId` (string, required) - Winget package ID to check

**Returns:** Boolean

**Example:**
```powershell
$isInstalled = Test-WingetPackageInstalled -PackageId "Git.Git"
if ($isInstalled) {
    Write-Host "Git is already installed"
} else {
    Install-WingetPackage -PackageId "Git.Git" -Name "Git"
}
```

### Uninstall-WingetPackage

Uninstalls a package using Windows Package Manager.

**Parameters:**
- `PackageId` (string, required) - Winget package ID to uninstall
- `Silent` (bool) - Silent uninstallation (default: true)

**Example:**
```powershell
# Uninstall package
Uninstall-WingetPackage -PackageId "Git.Git"

# Interactive uninstall
Uninstall-WingetPackage -PackageId "Git.Git" -Silent $false
```

### Update-WingetPackage

Updates one or all packages.

**Parameters:**
- `PackageId` (string) - Specific package ID, or empty for all packages
- `Silent` (bool) - Silent update (default: true)

**Example:**
```powershell
# Update specific package
Update-WingetPackage -PackageId "Git.Git"

# Update all packages
Update-WingetPackage

# Interactive update
Update-WingetPackage -PackageId "Git.Git" -Silent $false
```

### Search-WingetPackage

Searches for packages in winget repositories.

**Parameters:**
- `Query` (string, required) - Search query

**Returns:** Array of matching packages

**Example:**
```powershell
# Search for Git-related packages
$results = Search-WingetPackage -Query "git"
$results | ForEach-Object {
    Write-Host "$($_.Id) - $($_.Name)"
}

# Search for Python
Search-WingetPackage -Query "python"
```

### Get-WingetInstalledPackages

Lists all packages installed via winget.

**Returns:** Array of installed packages

**Example:**
```powershell
# Get all installed packages
$installed = Get-WingetInstalledPackages
Write-Host "Total packages: $($installed.Count)"

$installed | ForEach-Object {
    Write-Host "  $($_.Name) ($($_.Id))"
}
```

### Get-WingetPackageInfo

Gets detailed information about a specific package.

**Parameters:**
- `PackageId` (string, required) - Package ID to query

**Returns:** Package information object

**Example:**
```powershell
# Get package details
$info = Get-WingetPackageInfo -PackageId "Git.Git"
Write-Host "Name: $($info.Name)"
Write-Host "Version: $($info.Version)"
Write-Host "Publisher: $($info.Publisher)"
```

## Usage Patterns

### Pattern 1: Check Before Install

```powershell
$packageId = "Git.Git"
$packageName = "Git for Windows"

if (-not (Test-WingetPackageInstalled -PackageId $packageId)) {
    Write-Host "Installing $packageName..."
    Install-WingetPackage -PackageId $packageId -Name $packageName
} else {
    Write-Host "$packageName is already installed"
}
```

### Pattern 2: Install Multiple Packages

```powershell
$packages = @(
    @{ Id = "Git.Git"; Name = "Git for Windows" }
    @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code" }
    @{ Id = "Docker.DockerDesktop"; Name = "Docker Desktop" }
)

foreach ($pkg in $packages) {
    if (-not (Test-WingetPackageInstalled -PackageId $pkg.Id)) {
        Install-WingetPackage -PackageId $pkg.Id -Name $pkg.Name
    }
}
```

### Pattern 3: Update All Packages

```powershell
Write-Host "Checking for updates..."
$installed = Get-WingetInstalledPackages

Write-Host "Found $($installed.Count) packages"
Write-Host "Updating all packages..."
Update-WingetPackage  # Updates all
```

### Pattern 4: Search and Install

```powershell
# Search for package
$results = Search-WingetPackage -Query "nodejs"

# Display results
Write-Host "Found $($results.Count) matches:"
$results | ForEach-Object {
    Write-Host "  [$($_.Id)] $($_.Name)"
}

# Install first match
if ($results.Count -gt 0) {
    $selected = $results[0]
    Install-WingetPackage -PackageId $selected.Id -Name $selected.Name
}
```

### Pattern 5: Conditional Reinstall

```powershell
$packageId = "Git.Git"

# Check if installed
if (Test-WingetPackageInstalled -PackageId $packageId) {
    Write-Host "Git is installed. Reinstalling..."
    Install-WingetPackage -PackageId $packageId -Force $true
} else {
    Write-Host "Git is not installed. Installing..."
    Install-WingetPackage -PackageId $packageId
}
```

## Common Package IDs

Here are some commonly used winget package IDs:

### Development Tools
```powershell
Install-WingetPackage -PackageId "Git.Git"                           # Git
Install-WingetPackage -PackageId "GitHub.GitHubDesktop"              # GitHub Desktop
Install-WingetPackage -PackageId "Microsoft.VisualStudioCode"        # VS Code
Install-WingetPackage -PackageId "JetBrains.Toolbox"                 # JetBrains Toolbox
```

### Languages & Runtimes
```powershell
Install-WingetPackage -PackageId "Python.Python.3.11"                # Python
Install-WingetPackage -PackageId "GoLang.Go"                         # Go
Install-WingetPackage -PackageId "Oracle.JavaRuntimeEnvironment"     # Java JRE
Install-WingetPackage -PackageId "OpenJS.NodeJS"                     # Node.js
```

### Containers & Cloud
```powershell
Install-WingetPackage -PackageId "Docker.DockerDesktop"              # Docker Desktop
Install-WingetPackage -PackageId "Kubernetes.kubectl"                # kubectl
Install-WingetPackage -PackageId "Amazon.AWSCLI"                     # AWS CLI
Install-WingetPackage -PackageId "Microsoft.Azure.CLI"               # Azure CLI
```

### Utilities
```powershell
Install-WingetPackage -PackageId "7zip.7zip"                         # 7-Zip
Install-WingetPackage -PackageId "Notepad++.Notepad++"               # Notepad++
Install-WingetPackage -PackageId "Microsoft.PowerToys"               # PowerToys
```

## Error Handling

All functions include comprehensive error handling:

```powershell
try {
    Install-WingetPackage -PackageId "Git.Git" -Name "Git"
}
catch {
    Write-Host "Installation failed: $_" -ForegroundColor Red
    # Fallback or alternative action
}
```

## Verbose Output

Enable verbose output for detailed operation logging:

```powershell
Install-WingetPackage -PackageId "Git.Git" -Verbose
Update-WingetPackage -Verbose
```

## Troubleshooting

### Winget Not Found

```powershell
# Check if winget is installed
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Winget is not installed or not in PATH"
    Write-Host "Please install from: https://aka.ms/getwinget"
}
```

### Package Not Found

```powershell
# Search before installing
$query = "git"
$results = Search-WingetPackage -Query $query
if ($results.Count -eq 0) {
    Write-Host "No packages found matching: $query"
} else {
    Write-Host "Found $($results.Count) packages"
}
```

### Installation Hangs

If installation appears to hang, it may be waiting for user input. Use `-Silent $false` to see prompts:

```powershell
Install-WingetPackage -PackageId "Git.Git" -Silent $false
```

## Best Practices

1. **Always check if package is already installed**
   ```powershell
   if (-not (Test-WingetPackageInstalled -PackageId "Git.Git")) {
       Install-WingetPackage -PackageId "Git.Git"
   }
   ```

2. **Use full package IDs** - Avoid ambiguity by using complete IDs

3. **Update packages regularly**
   ```powershell
   Update-WingetPackage  # Updates all packages
   ```

4. **Search before installing** to verify correct package ID

5. **Use silent mode** for automated scripts (default behavior)

## Requirements

- PowerShell 5.1 or higher
- Windows 10 1809+ or Windows 11
- Windows Package Manager (winget)
- Internet connection for package downloads

## Version

Current Version: 1.0.0

## Related Modules

- [path-manager](../path-manager/README.md) - PATH environment variable management
- [scoop-manager](../scoop-manager/README.md) - Scoop package manager operations

## License

MIT License - See [LICENSE](../../../LICENSE)
