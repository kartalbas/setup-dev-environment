# Windows Modules Examples

This folder contains examples demonstrating how to use the Windows PowerShell modules for development environment setup.

## Available Examples

### 1. example-integration.ps1

A comprehensive demonstration script showing how to use all three modules together.

**What it demonstrates:**
- Loading modules
- PATH management operations
- Scoop package operations
- Winget package operations
- Combined workflows
- Error handling patterns

**How to run:**
```powershell
cd modules\windows\examples
.\example-integration.ps1
```

**Note:** This script is safe to run - it doesn't make any permanent changes to your system. It only demonstrates the module functions with example code.

## Quick Start Examples

### Basic Module Loading

```powershell
# Load all modules
$ModulesPath = "D:\path\to\modules\windows"

Import-Module (Join-Path $ModulesPath "path-manager\path-manager.ps1") -Force
Import-Module (Join-Path $ModulesPath "winget-manager\winget-manager.ps1") -Force
Import-Module (Join-Path $ModulesPath "scoop-manager\scoop-manager.ps1") -Force

Write-Host "✓ Modules loaded" -ForegroundColor Green
```

### Example 1: Simple Package Installation

```powershell
# Install Git via Scoop
if (-not (Test-ScoopPackageInstalled -Package "git")) {
    Install-ScoopPackage -Package "git" -DisplayName "Git"
}

# Add Scoop shims to PATH
$scoopPath = Get-ScoopPath
$shimsPath = Join-Path $scoopPath "shims"
Add-ToPath -Path $shimsPath -Scope User
```

### Example 2: Multi-Package Setup

```powershell
# Define packages to install
$scoopPackages = @("git", "curl", "wget", "jq", "ripgrep", "fd")

# Install each package
foreach ($package in $scoopPackages) {
    if (-not (Test-ScoopPackageInstalled -Package $package)) {
        Install-ScoopPackage -Package $package -DisplayName $package
    } else {
        Write-Host "  ✓ $package already installed" -ForegroundColor Green
    }
}
```

### Example 3: GUI Applications via Winget

```powershell
# Install GUI applications
$wingetApps = @(
    @{ Id = "Git.Git"; Name = "Git for Windows" }
    @{ Id = "Microsoft.VisualStudioCode"; Name = "VS Code" }
    @{ Id = "Docker.DockerDesktop"; Name = "Docker Desktop" }
)

foreach ($app in $wingetApps) {
    if (-not (Test-WingetPackageInstalled -PackageId $app.Id)) {
        Install-WingetPackage -PackageId $app.Id -Name $app.Name
    }
}
```

### Example 4: PATH Management

```powershell
# Get current PATH entries
$paths = Get-PathEntries -Scope User
Write-Host "User PATH has $($paths.User.Count) entries"

# Clean duplicates
Clean-Path -Scope User

# Add new path if not present
$myToolPath = "C:\MyTools\bin"
if (Test-Path $myToolPath) {
    if (-not (Test-InPath -Path $myToolPath)) {
        Add-ToPath -Path $myToolPath -Scope User
        Write-Host "✓ Added to PATH: $myToolPath" -ForegroundColor Green
    }
}

# Refresh current session
Refresh-SessionPath
```

### Example 5: Backup Before Changes

```powershell
# Backup PATH before making changes
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "path-backup-$timestamp.json"
Backup-Path -FilePath $backupFile -Scope Both
Write-Host "✓ PATH backed up to: $backupFile" -ForegroundColor Green

# Make changes...
Add-ToPath -Path "C:\NewTool\bin"

# If something goes wrong, you have a backup!
```

### Example 6: Complete Dev Environment Setup

```powershell
# 1. Add Scoop buckets
$buckets = @("extras", "versions", "java", "nerd-fonts")
foreach ($bucket in $buckets) {
    Add-ScoopBucket -Bucket $bucket
}

# 2. Install core CLI tools
$coreTools = @("git", "curl", "wget", "jq", "yq", "ripgrep", "fd", "fzf", "bat")
foreach ($tool in $coreTools) {
    Install-ScoopPackage -Package $tool
}

# 3. Install editors from extras bucket
$editors = @("vscode", "sublime-text", "neovim")
foreach ($editor in $editors) {
    Install-ScoopPackage -Package $editor -Bucket "extras"
}

# 4. Install fonts
$fonts = @("FiraCode-NF", "CascadiaCode-NF", "JetBrainsMono-NF")
foreach ($font in $fonts) {
    Install-ScoopPackage -Package $font -Bucket "nerd-fonts"
}

# 5. Update PATH
$scoopPath = Get-ScoopPath
$shimsPath = Join-Path $scoopPath "shims"
Add-ToPath -Path $shimsPath -Scope User

# 6. Clean up
Clean-Path -Scope User
Refresh-SessionPath

Write-Host "`n✓ Development environment setup complete!" -ForegroundColor Green
```

### Example 7: Conditional Installation (Scoop or Winget)

```powershell
function Install-Tool {
    param(
        [string]$Name,
        [string]$ScoopPackage,
        [string]$WingetPackageId
    )

    # Try Scoop first (user-level, no admin needed)
    if ($ScoopPackage -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
        if (-not (Test-ScoopPackageInstalled -Package $ScoopPackage)) {
            Install-ScoopPackage -Package $ScoopPackage -DisplayName $Name
            return
        }
    }

    # Fallback to Winget
    if ($WingetPackageId -and (Get-Command winget -ErrorAction SilentlyContinue)) {
        if (-not (Test-WingetPackageInstalled -PackageId $WingetPackageId)) {
            Install-WingetPackage -PackageId $WingetPackageId -Name $Name
            return
        }
    }

    Write-Host "  ✓ $Name already installed" -ForegroundColor Green
}

# Usage
Install-Tool -Name "Git" -ScoopPackage "git" -WingetPackageId "Git.Git"
Install-Tool -Name "VS Code" -ScoopPackage "vscode" -WingetPackageId "Microsoft.VisualStudioCode"
```

### Example 8: Update All Packages

```powershell
Write-Host "Updating all packages..." -ForegroundColor Cyan

# Update Scoop packages
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "`nUpdating Scoop..." -ForegroundColor Cyan
    scoop update

    Write-Host "Updating Scoop packages..." -ForegroundColor Cyan
    Update-ScoopPackage

    Write-Host "Cleaning Scoop cache..." -ForegroundColor Cyan
    Clear-ScoopCache
}

# Update Winget packages
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "`nUpdating Winget packages..." -ForegroundColor Cyan
    Update-WingetPackage
}

Write-Host "`n✓ All updates complete!" -ForegroundColor Green
```

### Example 9: Search and Install

```powershell
# Search for a tool
$searchTerm = "python"

Write-Host "Searching Scoop for: $searchTerm" -ForegroundColor Cyan
$scoopResults = Search-ScoopPackage -Query $searchTerm
Write-Host "Found $($scoopResults.Count) Scoop packages"

Write-Host "`nSearching Winget for: $searchTerm" -ForegroundColor Cyan
$wingetResults = Search-WingetPackage -Query $searchTerm
Write-Host "Found $($wingetResults.Count) Winget packages"

# Display first 5 results
Write-Host "`nTop Scoop results:" -ForegroundColor Yellow
$scoopResults | Select-Object -First 5 | ForEach-Object {
    Write-Host "  - $_"
}

Write-Host "`nTop Winget results:" -ForegroundColor Yellow
$wingetResults | Select-Object -First 5 | ForEach-Object {
    Write-Host "  - $($_.Id): $($_.Name)"
}
```

### Example 10: Installation Report

```powershell
# Generate installation report
Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Installation Report" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

# Scoop packages
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    $scoopInstalled = Get-ScoopInstalledPackages
    Write-Host "`nScoop Packages: $($scoopInstalled.Count)" -ForegroundColor Green
    $scoopInstalled | ForEach-Object {
        Write-Host "  ✓ $_" -ForegroundColor Gray
    }
}

# Winget packages
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $wingetInstalled = Get-WingetInstalledPackages
    Write-Host "`nWinget Packages: $($wingetInstalled.Count)" -ForegroundColor Green
    $wingetInstalled | Select-Object -First 10 | ForEach-Object {
        Write-Host "  ✓ $($_.Name)" -ForegroundColor Gray
    }
    if ($wingetInstalled.Count -gt 10) {
        Write-Host "  ... and $($wingetInstalled.Count - 10) more" -ForegroundColor Gray
    }
}

# PATH entries
$pathInfo = Get-PathEntries -Scope User
Write-Host "`nUser PATH Entries: $($pathInfo.User.Count)" -ForegroundColor Green

# Scoop path
$scoopPath = Get-ScoopPath
if ($scoopPath) {
    Write-Host "`nScoop Location: $scoopPath" -ForegroundColor Gray
}

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
```

## Error Handling Best Practices

### Pattern 1: Try-Catch with Fallback

```powershell
try {
    Install-WingetPackage -PackageId "Git.Git" -Name "Git"
}
catch {
    Write-Host "Winget installation failed, trying Scoop..." -ForegroundColor Yellow
    Install-ScoopPackage -Package "git" -DisplayName "Git"
}
```

### Pattern 2: Check Availability First

```powershell
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Scoop is not installed" -ForegroundColor Red
    Write-Host "Install from: https://scoop.sh" -ForegroundColor Yellow
    exit 1
}

# Proceed with Scoop operations...
```

### Pattern 3: Validate Path Before Adding

```powershell
$toolPath = "C:\MyTool\bin"

if (Test-Path $toolPath) {
    Add-ToPath -Path $toolPath -Scope User
} else {
    Write-Host "Warning: Path does not exist: $toolPath" -ForegroundColor Yellow
    Write-Host "Skipping PATH addition" -ForegroundColor Gray
}
```

## Running the Examples

### Run example-integration.ps1

```powershell
# Navigate to examples folder
cd D:\repos\kartalbas\setup-dev-environment\modules\windows\examples

# Run the example script
.\example-integration.ps1
```

### Create Your Own Script

1. Copy `example-integration.ps1` as a template
2. Modify to fit your needs
3. Run your custom script

```powershell
# Copy the example
Copy-Item example-integration.ps1 my-custom-setup.ps1

# Edit with your favorite editor
code my-custom-setup.ps1

# Run your script
.\my-custom-setup.ps1
```

## Tips

1. **Start Simple** - Begin with one module at a time
2. **Check Before Install** - Always verify if a package is already installed
3. **Use Try-Catch** - Wrap installations in error handling
4. **Test in Isolation** - Test each function independently first
5. **Backup PATH** - Always backup before making PATH changes
6. **Use Verbose** - Add `-Verbose` flag for detailed output during debugging

## Additional Resources

- [path-manager Module](../path-manager/README.md) - Complete PATH management documentation
- [winget-manager Module](../winget-manager/README.md) - Complete Winget package manager documentation
- [scoop-manager Module](../scoop-manager/README.md) - Complete Scoop package manager documentation
- [Main Project README](../../../README.md) - Overall project documentation

## Support

If you encounter issues:

1. Check module README files for detailed function documentation
2. Review examples in this folder for usage patterns
3. Run with `-Verbose` flag for detailed output
4. Verify prerequisites are installed (Scoop, Winget, PowerShell 5.1+)

## License

MIT License - See [LICENSE](../../../../LICENSE)
