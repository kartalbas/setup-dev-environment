<#
.SYNOPSIS
  Interactive Winget Update Manager - Updates Windows packages using winget

.DESCRIPTION
  Provides an interactive interface for updating Windows packages.
  Uses the winget-manager module for core operations.

  Features:
  - Interactive package selection (1,3,5 or 1-4 or all)
  - Silent mode for automation (-Silent)
  - Package exclusion (-ExcludeIds)
  - Automatic retry logic for failed updates

.PARAMETER Silent
  Run in silent mode without prompts - automatically updates everything

.PARAMETER ExcludeIds
  Array of package IDs to exclude from updates

.EXAMPLE
  .\winget-manager.ps1
  Interactive mode - select packages to update

.EXAMPLE
  .\winget-manager.ps1 -Silent
  Update all packages automatically (like apt upgrade -y)

.EXAMPLE
  .\winget-manager.ps1 -ExcludeIds "Docker.DockerDesktop","Microsoft.Edge"
  Exclude specific packages from updates

.NOTES
  Requires winget-manager module.
  Run as Administrator for some packages.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeIds = @()
)

# ============================================================================
# IMPORT MODULE
# ============================================================================

$modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) "modules\windows\winget-manager\winget-manager.psm1"

if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction Stop
} elseif (Get-Module -ListAvailable -Name "winget-manager") {
    Import-Module "winget-manager" -Force -ErrorAction Stop
} else {
    Write-Host "Error: winget-manager module not found at: $modulePath" -ForegroundColor Red
    Write-Host "Please ensure the module is installed." -ForegroundColor Yellow
    exit 1
}

$ErrorActionPreference = "Continue"

# ============================================================================
# HELPER FUNCTION (UI only - core operations use module)
# ============================================================================

function Write-Step {
    param([string]$Message, [string]$Status = "Info")
    $prefix = switch ($Status) {
        "Success" { "✓"; $color = "Green" }
        "Error"   { "✗"; $color = "Red" }
        "Warning" { "⚠"; $color = "Yellow" }
        default   { "→"; $color = "Cyan" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

# Track successfully updated packages with unknown versions
$script:updatedUnknownPackages = @()

# Header
Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Winget Update Manager" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if winget exists
try {
    $null = Get-Command winget -ErrorAction Stop
    $version = (winget --version) -replace 'v', ''
    Write-Step "Winget version: $version" "Success"
} catch {
    Write-Step "Winget is not installed!" "Error"
    Write-Host "Install from: https://aka.ms/winget" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 1: Update sources
Write-Step "Updating package sources..." "Info"
Update-WingetSources | Out-Null
Write-Host ""

# Step 2: Check for updates
Write-Step "Checking for available updates..." "Info"
Write-Host ""

$updateOutput = winget update --include-unknown 2>&1

# Parse package lines into structured data
$packages = @()
$updateOutput | ForEach-Object {
    if ($_ -match '^(.+?)\s{2,}(\S+)\s+(\S+)\s+(\S+)\s+(winget|msstore)') {
        $packages += [PSCustomObject]@{
            Name = $matches[1].Trim()
            Id = $matches[2]
            Version = $matches[3]
            Available = $matches[4]
            Source = $matches[5]
        }
    }
}

# Separate packages into normal and unknown version packages
$normalPackages = @()
$unknownPackages = @()

foreach ($pkg in $packages) {
    if ($script:updatedUnknownPackages -contains $pkg.Id) {
        continue
    }

    if ($pkg.Version -eq "Unknown") {
        $unknownPackages += $pkg
    } else {
        $normalPackages += $pkg
    }
}

$updateCount = $normalPackages.Count + $unknownPackages.Count

if ($updateCount -eq 0) {
    Write-Step "All packages are up to date!" "Success"
    exit 0
}

# Step 3: Display available updates
if ($normalPackages.Count -gt 0) {
    Write-Step "Found $($normalPackages.Count) package(s) with available updates:" "Success"
    Write-Host ""

    for ($i = 0; $i -lt $normalPackages.Count; $i++) {
        $pkg = $normalPackages[$i]
        $num = ($i + 1).ToString().PadLeft(2)
        Write-Host "  [$num] " -ForegroundColor Cyan -NoNewline
        Write-Host "$($pkg.Name) " -ForegroundColor White -NoNewline
        Write-Host "($($pkg.Version) → $($pkg.Available))" -ForegroundColor Yellow
    }
    Write-Host ""
}

# Display unknown version packages separately
if ($unknownPackages.Count -gt 0) {
    Write-Host "Unknown version packages:" -ForegroundColor DarkYellow
    Write-Host ""

    $startNum = $normalPackages.Count + 1
    for ($i = 0; $i -lt $unknownPackages.Count; $i++) {
        $pkg = $unknownPackages[$i]
        $num = ($startNum + $i).ToString().PadLeft(2)
        Write-Host "  [$num] " -ForegroundColor Cyan -NoNewline
        Write-Host "$($pkg.Name) " -ForegroundColor White -NoNewline
        Write-Host "(Unknown → $($pkg.Available))" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Combine both lists for selection
$packages = $normalPackages + $unknownPackages

if ($packages.Count -eq 0) {
    Write-Step "All packages are up to date!" "Success"
    exit 0
}

# Step 4: Ask user which packages to update
if (-not $Silent) {
    Write-Host "Enter package numbers to update:" -ForegroundColor Cyan
    Write-Host "  • Single: 1,3,5" -ForegroundColor Gray
    Write-Host "  • Range: 1-4" -ForegroundColor Gray
    Write-Host "  • Mixed: 1,3,5-8,10" -ForegroundColor Gray
    Write-Host "  • All: all or press Enter" -ForegroundColor Gray
    Write-Host ""

    $selection = Read-Host "Selection"

    $packagesToUpdate = @()

    if ([string]::IsNullOrWhiteSpace($selection) -or $selection.Trim().ToLower() -eq 'all') {
        $packagesToUpdate = $packages
        Write-Host ""
        Write-Step "Updating ALL packages..." "Info"
    } else {
        $selectedIndices = @()
        $parts = $selection -split ','
        foreach ($part in $parts) {
            $part = $part.Trim()
            if ($part -match '^(\d+)-(\d+)$') {
                $start = [int]$matches[1]
                $end = [int]$matches[2]
                $selectedIndices += ($start..$end)
            } elseif ($part -match '^\d+$') {
                $selectedIndices += [int]$part
            }
        }

        foreach ($idx in $selectedIndices) {
            if ($idx -ge 1 -and $idx -le $packages.Count) {
                $packagesToUpdate += $packages[$idx - 1]
            }
        }

        if ($packagesToUpdate.Count -eq 0) {
            Write-Step "No valid packages selected" "Warning"
            exit 0
        }

        Write-Host ""
        Write-Step "Updating $($packagesToUpdate.Count) selected package(s)..." "Info"
    }
} else {
    $packagesToUpdate = $packages
}

# Filter out excluded packages
if ($ExcludeIds.Count -gt 0) {
    Write-Host ""
    Write-Step "Excluding: $($ExcludeIds -join ', ')" "Warning"
    $packagesToUpdate = $packagesToUpdate | Where-Object { $_.Id -notin $ExcludeIds }
}

if ($packagesToUpdate.Count -eq 0) {
    Write-Step "No packages to update after filtering" "Warning"
    exit 0
}

# Step 5: Update selected packages
Write-Host ""
Write-Step "Updating $($packagesToUpdate.Count) package(s)..." "Info"
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($pkg in $packagesToUpdate) {
    Write-Host ""
    Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "→ Updating: " -ForegroundColor Cyan -NoNewline
    Write-Host "$($pkg.Name) " -ForegroundColor White -NoNewline
    Write-Host "($($pkg.Id))" -ForegroundColor Gray
    Write-Host "────────────────────────────────────────" -ForegroundColor DarkGray

    # Use module function for upgrade with retry
    $updated = Invoke-WingetUpgradeWithRetry -PackageId $pkg.Id -MaxRetries 4

    if ($updated) {
        Write-Host "  ✓ Success" -ForegroundColor Green
        $successCount++
        if ($pkg.Version -eq "Unknown") {
            $script:updatedUnknownPackages += $pkg.Id
        }
    } else {
        Write-Host "  ✗ Failed after all retry attempts" -ForegroundColor Red
        Write-Host "     Try manually: winget install --id $($pkg.Id) --force" -ForegroundColor Gray
        $failCount++
    }
}

# Step 6: Summary
Write-Host ""
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Update Summary" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ✓ Successful: $successCount" -ForegroundColor Green
if ($failCount -gt 0) {
    Write-Host "  ✗ Failed: $failCount" -ForegroundColor Red
}
Write-Host ""

if ($script:updatedUnknownPackages.Count -gt 0) {
    Write-Host "ℹ Unknown version packages updated: " -ForegroundColor Cyan -NoNewline
    Write-Host ($script:updatedUnknownPackages -join ", ") -ForegroundColor Gray
    Write-Host ""
}

if ($failCount -eq 0) {
    Write-Step "All updates completed successfully!" "Success"
} else {
    Write-Step "Some updates failed. Check the output above." "Warning"
}

Write-Host ""
