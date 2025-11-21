# winget-manager.ps1
# PowerShell module for managing Windows Package Manager (winget)
# Version: 1.0.0

<#
.SYNOPSIS
    Manages winget (Windows Package Manager) operations
.DESCRIPTION
    Provides functions to install, uninstall, update, and search packages using winget
    Includes checks for winget availability and graceful fallbacks
#>

# ============================================================================
# PRIVATE FUNCTIONS
# ============================================================================

function Test-WingetAvailable {
    <#
    .SYNOPSIS
        Checks if winget is available on the system
    #>
    [CmdletBinding()]
    param()

    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Write-WingetOutput {
    <#
    .SYNOPSIS
        Formats winget output for better readability
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )

    $color = switch ($Level) {
        "Info" { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }

    $prefix = switch ($Level) {
        "Info" { "  →" }
        "Success" { "  ✓" }
        "Warning" { "  ⚠" }
        "Error" { "  ✗" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Checks if a package is installed via winget
.PARAMETER PackageId
    The winget package ID (e.g., "Git.Git", "Microsoft.PowerToys")
.EXAMPLE
    Test-WingetPackageInstalled -PackageId "Git.Git"
#>
function Test-WingetPackageInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageId
    )

    if (-not (Test-WingetAvailable)) {
        Write-Verbose "Winget not available"
        return $false
    }

    try {
        $result = winget list --id $PackageId --accept-source-agreements 2>&1 | Out-String
        return $result -match $PackageId
    }
    catch {
        Write-Verbose "Error checking package: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Installs a package using winget
.PARAMETER PackageId
    The winget package ID (e.g., "Git.Git")
.PARAMETER Name
    Display name for the package
.PARAMETER Silent
    If true, runs installation silently (default: true)
.PARAMETER AcceptAgreements
    If true, accepts source and package agreements (default: true)
.PARAMETER Force
    If true, forces reinstallation even if already installed
.EXAMPLE
    Install-WingetPackage -PackageId "Git.Git" -Name "Git for Windows"
#>
function Install-WingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageId,

        [Parameter(Mandatory=$false)]
        [string]$Name = $PackageId,

        [Parameter(Mandatory=$false)]
        [bool]$Silent = $true,

        [Parameter(Mandatory=$false)]
        [bool]$AcceptAgreements = $true,

        [Parameter(Mandatory=$false)]
        [bool]$Force = $false
    )

    # Check winget availability
    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available - cannot install $Name" "Error"
        return $false
    }

    # Check if already installed
    if (-not $Force -and (Test-WingetPackageInstalled -PackageId $PackageId)) {
        Write-WingetOutput "$Name already installed" "Success"
        return $true
    }

    # Build install arguments
    $args = @("install", "--id=$PackageId")

    if ($Silent) {
        $args += "--silent"
    }

    if ($AcceptAgreements) {
        $args += @("--accept-source-agreements", "--accept-package-agreements")
    }

    if ($Force) {
        $args += "--force"
    }

    # Install package
    Write-WingetOutput "Installing $Name..." "Info"

    try {
        $result = & winget @args 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0 -or $exitCode -eq -1978335189) {
            # Exit code -1978335189 (0x8A15000B) means "already installed" which we treat as success
            Write-WingetOutput "$Name installed successfully" "Success"
            return $true
        }
        else {
            Write-WingetOutput "$Name installation may have failed (exit code: $exitCode)" "Warning"
            Write-Verbose "Output: $result"
            return $false
        }
    }
    catch {
        Write-WingetOutput "Failed to install $Name : $_" "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Uninstalls a package using winget
.PARAMETER PackageId
    The winget package ID
.PARAMETER Name
    Display name for the package
.PARAMETER Silent
    If true, runs uninstallation silently (default: true)
.EXAMPLE
    Uninstall-WingetPackage -PackageId "Git.Git" -Name "Git for Windows"
#>
function Uninstall-WingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageId,

        [Parameter(Mandatory=$false)]
        [string]$Name = $PackageId,

        [Parameter(Mandatory=$false)]
        [bool]$Silent = $true
    )

    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available - cannot uninstall $Name" "Error"
        return $false
    }

    if (-not (Test-WingetPackageInstalled -PackageId $PackageId)) {
        Write-WingetOutput "$Name not installed" "Info"
        return $true
    }

    # Build uninstall arguments
    $args = @("uninstall", "--id=$PackageId")

    if ($Silent) {
        $args += "--silent"
    }

    Write-WingetOutput "Uninstalling $Name..." "Info"

    try {
        $result = & winget @args 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-WingetOutput "$Name uninstalled successfully" "Success"
            return $true
        }
        else {
            Write-WingetOutput "$Name uninstallation failed (exit code: $exitCode)" "Error"
            return $false
        }
    }
    catch {
        Write-WingetOutput "Failed to uninstall $Name : $_" "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Updates a package using winget
.PARAMETER PackageId
    The winget package ID (optional - if not specified, updates all)
.PARAMETER Name
    Display name for the package
.PARAMETER Silent
    If true, runs update silently (default: true)
.EXAMPLE
    Update-WingetPackage -PackageId "Git.Git"
.EXAMPLE
    Update-WingetPackage  # Updates all packages
#>
function Update-WingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$PackageId = "",

        [Parameter(Mandatory=$false)]
        [string]$Name = "",

        [Parameter(Mandatory=$false)]
        [bool]$Silent = $true
    )

    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available" "Error"
        return $false
    }

    # Build update arguments
    $args = @("upgrade")

    if ($PackageId) {
        $args += "--id=$PackageId"
        $displayName = if ($Name) { $Name } else { $PackageId }
        Write-WingetOutput "Updating $displayName..." "Info"
    }
    else {
        $args += "--all"
        Write-WingetOutput "Updating all packages..." "Info"
    }

    if ($Silent) {
        $args += "--silent"
    }

    $args += @("--accept-source-agreements", "--accept-package-agreements")

    try {
        $result = & winget @args 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-WingetOutput "Update completed successfully" "Success"
            return $true
        }
        else {
            Write-WingetOutput "Update may have had issues (exit code: $exitCode)" "Warning"
            return $false
        }
    }
    catch {
        Write-WingetOutput "Failed to update: $_" "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Searches for packages using winget
.PARAMETER Query
    Search query
.PARAMETER Tag
    Optional tag filter
.EXAMPLE
    Search-WingetPackage -Query "Visual Studio Code"
#>
function Search-WingetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,

        [Parameter(Mandatory=$false)]
        [string]$Tag = ""
    )

    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available" "Error"
        return @()
    }

    $args = @("search", $Query, "--accept-source-agreements")

    if ($Tag) {
        $args += "--tag", $Tag
    }

    try {
        $result = & winget @args 2>&1 | Out-String
        return $result
    }
    catch {
        Write-WingetOutput "Search failed: $_" "Error"
        return @()
    }
}

<#
.SYNOPSIS
    Lists all installed packages from winget
.EXAMPLE
    Get-WingetInstalledPackages
#>
function Get-WingetInstalledPackages {
    [CmdletBinding()]
    param()

    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available" "Error"
        return @()
    }

    try {
        $result = winget list --accept-source-agreements 2>&1 | Out-String
        return $result
    }
    catch {
        Write-WingetOutput "Failed to list packages: $_" "Error"
        return @()
    }
}

<#
.SYNOPSIS
    Gets information about a specific package
.PARAMETER PackageId
    The winget package ID
.EXAMPLE
    Get-WingetPackageInfo -PackageId "Git.Git"
#>
function Get-WingetPackageInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageId
    )

    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available" "Error"
        return $null
    }

    try {
        $result = winget show --id $PackageId --accept-source-agreements 2>&1 | Out-String
        return $result
    }
    catch {
        Write-WingetOutput "Failed to get package info: $_" "Error"
        return $null
    }
}

<#
.SYNOPSIS
    Gets list of packages with available updates
.EXAMPLE
    Get-WingetAvailableUpdates
#>
function Get-WingetAvailableUpdates {
    [CmdletBinding()]
    param()

    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available" "Error"
        return @()
    }

    try {
        # Update sources first
        winget source update 2>&1 | Out-Null

        # Get upgrade list
        $rawOutput = winget upgrade --accept-source-agreements 2>&1 | Out-String
        return $rawOutput
    }
    catch {
        Write-WingetOutput "Failed to get updates: $_" "Error"
        return @()
    }
}

<#
.SYNOPSIS
    Updates winget sources
.EXAMPLE
    Update-WingetSources
#>
function Update-WingetSources {
    [CmdletBinding()]
    param()

    if (-not (Test-WingetAvailable)) {
        Write-WingetOutput "Winget not available" "Error"
        return $false
    }

    try {
        Write-WingetOutput "Updating package sources..." "Info"
        winget source update 2>&1 | Out-Null
        Write-WingetOutput "Sources updated" "Success"
        return $true
    }
    catch {
        Write-WingetOutput "Failed to update sources: $_" "Error"
        return $false
    }
}

<#
.SYNOPSIS
    Upgrades a package with retry logic
.PARAMETER PackageId
    The winget package ID
.PARAMETER MaxRetries
    Maximum number of retry attempts (default: 3)
.EXAMPLE
    Invoke-WingetUpgradeWithRetry -PackageId "Git.Git"
#>
function Invoke-WingetUpgradeWithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PackageId,

        [Parameter(Mandatory=$false)]
        [int]$MaxRetries = 3
    )

    if (-not (Test-WingetAvailable)) {
        return $false
    }

    $attempts = @(
        @{ Args = @("upgrade", "--id", $PackageId, "--silent", "--accept-source-agreements", "--accept-package-agreements") },
        @{ Args = @("upgrade", "--id", $PackageId, "--force", "--accept-source-agreements", "--accept-package-agreements") },
        @{ Args = @("upgrade", "--id", $PackageId, "--force", "--accept-source-agreements", "--accept-package-agreements") },
        @{ Args = @("install", "--id", $PackageId, "--force", "--accept-source-agreements", "--accept-package-agreements") }
    )

    $attemptNum = 0
    foreach ($attempt in $attempts) {
        $attemptNum++
        if ($attemptNum -gt $MaxRetries) { break }

        try {
            $result = & winget $attempt.Args 2>&1 | Out-String
            $exitCode = $LASTEXITCODE

            if ($exitCode -eq 0) {
                return $true
            }
        }
        catch {
            continue
        }
    }

    return $false
}

# ============================================================================
# EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Test-WingetPackageInstalled',
    'Install-WingetPackage',
    'Uninstall-WingetPackage',
    'Update-WingetPackage',
    'Search-WingetPackage',
    'Get-WingetInstalledPackages',
    'Get-WingetPackageInfo',
    'Get-WingetAvailableUpdates',
    'Update-WingetSources',
    'Invoke-WingetUpgradeWithRetry'
)
