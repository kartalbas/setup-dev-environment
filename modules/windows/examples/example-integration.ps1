# example-integration.ps1
# Example showing how to integrate the modules into setup-dev-environment.ps1
# This is a simplified example focusing on the module integration

param(
    [switch]$ToolsUserRights = $false
)

# ============================================================================
# LOAD MODULES
# ============================================================================

$ScriptDir = Split-Path -Parent $PSCommandPath
$ModulesPath = Split-Path -Parent $ScriptDir

Write-Host "Loading modules from: $ModulesPath" -ForegroundColor Cyan

try {
    Import-Module (Join-Path $ModulesPath "path-manager\path-manager.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $ModulesPath "winget-manager\winget-manager.psm1") -Force -ErrorAction Stop
    Import-Module (Join-Path $ModulesPath "scoop-manager\scoop-manager.psm1") -Force -ErrorAction Stop
    Write-Host "✓ Modules loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to load modules: $_" -ForegroundColor Red
    exit 1
}

# ============================================================================
# EXAMPLE 1: PATH MANAGEMENT
# ============================================================================

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Example 1: PATH Management" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

# Get current PATH entries
$pathInfo = Get-PathEntries -Scope User
Write-Host "`nUser PATH has $($pathInfo.User.Count) entries" -ForegroundColor Gray

# Add a test path (example only - won't actually add)
$testPath = "C:\Example\Tools\bin"
Write-Host "`nExample: Adding path to PATH..." -ForegroundColor Gray
Write-Host "  Add-ToPath -Path '$testPath' -Scope User" -ForegroundColor Gray

# Check if a specific path exists
$scoopPath = "C:\Users\$env:USERNAME\scoop\shims"
if (Test-Path $scoopPath) {
    $inPath = Test-InPath -Path $scoopPath -Scope User
    Write-Host "`nScoop shims in PATH: $inPath" -ForegroundColor $(if($inPath){"Green"}else{"Yellow"})
}

# Clean PATH (dry run example)
Write-Host "`nExample: Clean PATH (remove duplicates)" -ForegroundColor Gray
Write-Host "  Clean-Path -Scope User -RemoveInvalid `$false" -ForegroundColor Gray

# ============================================================================
# EXAMPLE 2: SCOOP PACKAGE MANAGEMENT
# ============================================================================

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Example 2: Scoop Package Management" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

# Check if Scoop is available
$scoopAvailable = Get-Command scoop -ErrorAction SilentlyContinue
if ($scoopAvailable) {
    Write-Host "`n✓ Scoop is available" -ForegroundColor Green

    # Check if git is installed
    $gitInstalled = Test-ScoopPackageInstalled -Package "git"
    Write-Host "  Git installed: $gitInstalled" -ForegroundColor $(if($gitInstalled){"Green"}else{"Yellow"})

    # Example installation (commented out to avoid actual installation)
    Write-Host "`nExample: Install package via Scoop" -ForegroundColor Gray
    Write-Host "  Install-ScoopPackage -Package 'git' -DisplayName 'Git'" -ForegroundColor Gray

    # Add bucket example
    Write-Host "`nExample: Add Scoop bucket" -ForegroundColor Gray
    Write-Host "  Add-ScoopBucket -Bucket 'extras'" -ForegroundColor Gray

    # Get Scoop path
    $scoopInstallPath = Get-ScoopPath
    if ($scoopInstallPath) {
        Write-Host "`nScoop installation path: $scoopInstallPath" -ForegroundColor Gray
    }
}
else {
    Write-Host "`n✗ Scoop is not installed" -ForegroundColor Yellow
    Write-Host "  Example: Install-ScoopPackage would fail without Scoop" -ForegroundColor Gray
}

# ============================================================================
# EXAMPLE 3: WINGET PACKAGE MANAGEMENT
# ============================================================================

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Example 3: Winget Package Management" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

# Check if winget is available
$wingetAvailable = Get-Command winget -ErrorAction SilentlyContinue
if ($wingetAvailable) {
    Write-Host "`n✓ Winget is available" -ForegroundColor Green

    # Check if Git for Windows is installed
    $gitWinInstalled = Test-WingetPackageInstalled -PackageId "Git.Git"
    Write-Host "  Git for Windows installed: $gitWinInstalled" -ForegroundColor $(if($gitWinInstalled){"Green"}else{"Yellow"})

    # Example installation (commented out to avoid actual installation)
    Write-Host "`nExample: Install package via Winget" -ForegroundColor Gray
    Write-Host "  Install-WingetPackage -PackageId 'Git.Git' -Name 'Git for Windows'" -ForegroundColor Gray

    # Example search
    Write-Host "`nExample: Search for packages" -ForegroundColor Gray
    Write-Host "  Search-WingetPackage -Query 'Python'" -ForegroundColor Gray
}
else {
    Write-Host "`n✗ Winget is not available" -ForegroundColor Yellow
    Write-Host "  Example: Install-WingetPackage would fail without winget" -ForegroundColor Gray
}

# ============================================================================
# EXAMPLE 4: COMBINED WORKFLOW
# ============================================================================

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Example 4: Combined Workflow" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`nTypical installation workflow:" -ForegroundColor Gray
Write-Host @"

# 1. Install Scoop package
if (Get-ConfigValue `$config "install-git") {
    Install-ScoopPackage -Package "git" -DisplayName "Git"
}

# 2. Add to PATH if needed
`$gitPath = "C:\Scoop\shims"
if (Test-Path `$gitPath) {
    Add-ToPath -Path `$gitPath -Scope User
}

# 3. Verify installation
if (Test-ScoopPackageInstalled -Package "git") {
    Write-Host "✓ Git installed successfully" -ForegroundColor Green
}

# 4. Clean up PATH at the end
Clean-Path -Scope User
Refresh-SessionPath

"@ -ForegroundColor DarkGray

# ============================================================================
# EXAMPLE 5: ERROR HANDLING
# ============================================================================

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Example 5: Error Handling" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`nExample with error handling:" -ForegroundColor Gray
Write-Host @"

try {
    # Try to install package
    `$result = Install-ScoopPackage -Package "nonexistent-package"

    if (`$result) {
        Write-Host "✓ Package installed" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Package installation failed" -ForegroundColor Red
    }
}
catch {
    Write-Host "✗ Error: `$_" -ForegroundColor Red
}

"@ -ForegroundColor DarkGray

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "`n═══════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Summary" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan

Write-Host @"

✓ Modules loaded and working
✓ PATH management functions available
✓ Scoop management functions available
✓ Winget management functions available

Next steps:
1. Integrate these modules into setup-dev-environment.ps1
2. Replace old functions with module functions
3. Test thoroughly
4. Enjoy cleaner, more maintainable code!

For detailed integration steps, see:
  modules/windows/INTEGRATION_GUIDE.md

"@ -ForegroundColor Green

Write-Host "Example complete!" -ForegroundColor Cyan
