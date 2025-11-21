# scoop-manager.ps1
# PowerShell module for managing Scoop package manager
# Version: 1.0.0

<#
.SYNOPSIS
    Manages Scoop package manager operations
.DESCRIPTION
    Provides functions to install, uninstall, update, and search packages using Scoop
    Includes bucket management and installation verification
#>

# ============================================================================
# PRIVATE FUNCTIONS
# ============================================================================

function Test-ScoopAvailable {
    <#
    .SYNOPSIS
        Checks if Scoop is available on the system
    #>
    [CmdletBinding()]
    param()

    try {
        $null = Get-Command scoop -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Write-ScoopOutput {
    <#
    .SYNOPSIS
        Formats Scoop output for better readability
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Success", "Warning", "Error", "Gray")]
        [string]$Level = "Info"
    )

    $color = switch ($Level) {
        "Info" { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Gray" { "Gray" }
    }

    $prefix = switch ($Level) {
        "Info" { "  →" }
        "Success" { "  ✓" }
        "Warning" { "  ⚠" }
        "Error" { "  ✗" }
        "Gray" { "  ⊘" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Checks if a package is installed via Scoop
.PARAMETER Package
    The Scoop package name (e.g., "git", "python")
.EXAMPLE
    Test-ScoopPackageInstalled -Package "git"
#>
function Test-ScoopPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Package
    )

    if (-not (Test-ScoopAvailable)) {
        Write-Verbose "Scoop not available"
        return $false
    }

    try {
        $installed = scoop list 2>$null | Select-String -Pattern "^$Package "
        return $null -ne $installed
    }
    catch {
        Write-Verbose "Error checking package: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Installs a package using Scoop
.PARAMETER Package
    The Scoop package name
.PARAMETER Bucket
    Optional bucket to add before installing (e.g., "extras", "java")
.PARAMETER DisplayName
    Display name for output (defaults to Package name)
.PARAMETER Force
    If true, reinstalls even if already installed
.EXAMPLE
    Install-ScoopPackage -Package "git"
.EXAMPLE
    Install-ScoopPackage -Package "vscode" -Bucket "extras"
#>
function Install-ScoopPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Package,

        [Parameter(Mandatory=$false)]
        [string]$Bucket = "",

        [Parameter(Mandatory=$false)]
        [string]$DisplayName = "",

        [Parameter(Mandatory=$false)]
        [bool]$Force = $false
    )

    if (-not (Test-ScoopAvailable)) {
        Write-ScoopOutput "Scoop not available - cannot install $Package" "Error"
        return $false
    }

    $name = if ($DisplayName) { $DisplayName } else { $Package }

    # Add bucket if specified
    if ($Bucket) {
        $buckets = scoop bucket list 2>$null
        if ($buckets -notmatch $Bucket) {
            Write-ScoopOutput "Adding bucket: $Bucket" "Info"
            scoop bucket add $Bucket 2>&1 | Out-Null
        }
    }

    # Check if already installed
    if (-not $Force -and (Test-ScoopPackageInstalled -Package $Package)) {
        Write-ScoopOutput "$name already installed" "Success"
        return $true
    }

    # Install package
    Write-ScoopOutput "Installing $name..." "Info"

    try {
        $result = scoop install $Package 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-ScoopOutput "$name installed successfully" "Success"
            return $true
        }
        else {
            Write-ScoopOutput "Failed to install $name (exit code: $exitCode)" "Error"
            Write-Verbose "Output: $result"
            return $false
        }
    }
    catch {
        Write-ScoopOutput "Failed to install $name : $_" "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Uninstalls a package using Scoop
.PARAMETER Package
    The Scoop package name
.PARAMETER DisplayName
    Display name for output
.PARAMETER Purge
    If true, also removes config files (default: false)
.EXAMPLE
    Uninstall-ScoopPackage -Package "git"
.EXAMPLE
    Uninstall-ScoopPackage -Package "python" -Purge $true
#>
function Uninstall-ScoopPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Package,

        [Parameter(Mandatory=$false)]
        [string]$DisplayName = "",

        [Parameter(Mandatory=$false)]
        [bool]$Purge = $false
    )

    if (-not (Test-ScoopAvailable)) {
        Write-ScoopOutput "Scoop not available - cannot uninstall $Package" "Error"
        return $false
    }

    $name = if ($DisplayName) { $DisplayName } else { $Package }

    if (-not (Test-ScoopPackageInstalled -Package $Package)) {
        Write-ScoopOutput "$name not installed" "Info"
        return $true
    }

    Write-ScoopOutput "Uninstalling $name..." "Info"

    try {
        if ($Purge) {
            $result = scoop uninstall $Package --purge 2>&1 | Out-String
        }
        else {
            $result = scoop uninstall $Package 2>&1 | Out-String
        }

        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-ScoopOutput "$name uninstalled successfully" "Success"
            return $true
        }
        else {
            Write-ScoopOutput "Failed to uninstall $name (exit code: $exitCode)" "Error"
            return $false
        }
    }
    catch {
        Write-ScoopOutput "Failed to uninstall $name : $_" "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Updates a package using Scoop
.PARAMETER Package
    The Scoop package name (optional - if not specified, updates all)
.PARAMETER DisplayName
    Display name for output
.EXAMPLE
    Update-ScoopPackage -Package "git"
.EXAMPLE
    Update-ScoopPackage  # Updates all packages
#>
function Update-ScoopPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Package = "",

        [Parameter(Mandatory=$false)]
        [string]$DisplayName = ""
    )

    if (-not (Test-ScoopAvailable)) {
        Write-ScoopOutput "Scoop not available" "Error"
        return $false
    }

    if ($Package) {
        $name = if ($DisplayName) { $DisplayName } else { $Package }
        Write-ScoopOutput "Updating $name..." "Info"
        $result = scoop update $Package 2>&1 | Out-String
    }
    else {
        Write-ScoopOutput "Updating all packages..." "Info"
        $result = scoop update * 2>&1 | Out-String
    }

    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-ScoopOutput "Update completed successfully" "Success"
        return $true
    }
    else {
        Write-ScoopOutput "Update may have had issues (exit code: $exitCode)" "Warning"
        return $false
    }
}

<#
.SYNOPSIS
    Searches for packages in Scoop
.PARAMETER Query
    Search query
.EXAMPLE
    Search-ScoopPackage -Query "python"
#>
function Search-ScoopPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query
    )

    if (-not (Test-ScoopAvailable)) {
        Write-ScoopOutput "Scoop not available" "Error"
        return @()
    }

    try {
        $result = scoop search $Query 2>&1 | Out-String
        return $result
    }
    catch {
        Write-ScoopOutput "Search failed: $_" "Error"
        return @()
    }
}

<#
.SYNOPSIS
    Lists all installed Scoop packages
.EXAMPLE
    Get-ScoopInstalledPackages
#>
function Get-ScoopInstalledPackages {
    [CmdletBinding()]
    param()

    if (-not (Test-ScoopAvailable)) {
        Write-ScoopOutput "Scoop not available" "Error"
        return @()
    }

    try {
        $result = scoop list 2>&1 | Out-String
        return $result
    }
    catch {
        Write-ScoopOutput "Failed to list packages: $_" "Error"
        return @()
    }
}

<#
.SYNOPSIS
    Adds a Scoop bucket
.PARAMETER Bucket
    Bucket name (e.g., "extras", "java", "nerd-fonts")
.EXAMPLE
    Add-ScoopBucket -Bucket "extras"
#>
function Add-ScoopBucket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Bucket
    )

    if (-not (Test-ScoopAvailable)) {
        Write-ScoopOutput "Scoop not available" "Error"
        return $false
    }

    # Check if bucket already added
    $buckets = scoop bucket list 2>$null
    if ($buckets -match $Bucket) {
        Write-ScoopOutput "Bucket '$Bucket' already added" "Success"
        return $true
    }

    Write-ScoopOutput "Adding bucket: $Bucket" "Info"

    try {
        $result = scoop bucket add $Bucket 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-ScoopOutput "Bucket '$Bucket' added successfully" "Success"
            return $true
        }
        else {
            Write-ScoopOutput "Failed to add bucket '$Bucket'" "Error"
            return $false
        }
    }
    catch {
        Write-ScoopOutput "Failed to add bucket: $_" "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Gets Scoop installation path
.EXAMPLE
    Get-ScoopPath
#>
function Get-ScoopPath {
    [CmdletBinding()]
    param()

    if (-not (Test-ScoopAvailable)) {
        return $null
    }

    return $env:SCOOP
}

<#
.SYNOPSIS
    Cleans up old versions of packages
.EXAMPLE
    Clear-ScoopCache
#>
function Clear-ScoopCache {
    [CmdletBinding()]
    param()

    if (-not (Test-ScoopAvailable)) {
        Write-ScoopOutput "Scoop not available" "Error"
        return $false
    }

    Write-ScoopOutput "Cleaning up Scoop cache..." "Info"

    try {
        $result = scoop cleanup * 2>&1 | Out-String
        Write-ScoopOutput "Cache cleaned successfully" "Success"
        return $true
    }
    catch {
        Write-ScoopOutput "Failed to clean cache: $_" "Error"
        return $false
    }
}

# ============================================================================
# EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Test-ScoopPackageInstalled',
    'Install-ScoopPackage',
    'Uninstall-ScoopPackage',
    'Update-ScoopPackage',
    'Search-ScoopPackage',
    'Get-ScoopInstalledPackages',
    'Add-ScoopBucket',
    'Get-ScoopPath',
    'Clear-ScoopCache'
)
