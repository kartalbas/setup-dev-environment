# path-manager.ps1
# PowerShell module for managing Windows PATH environment variable
# Version: 1.0.0

<#
.SYNOPSIS
    Manages Windows PATH environment variable operations
.DESCRIPTION
    Provides functions to add, remove, check, and clean PATH entries
    Supports both User and Machine scope
#>

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

<#
.SYNOPSIS
    Adds a path to the PATH environment variable if not already present
.PARAMETER Path
    The directory path to add
.PARAMETER Scope
    User or Machine (default: User)
.PARAMETER UpdateSession
    If true, updates the current session's PATH (default: true)
.EXAMPLE
    Add-ToPath "C:\MyApp\bin"
.EXAMPLE
    Add-ToPath "C:\MyApp\bin" -Scope Machine -UpdateSession $false
#>
function Add-ToPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User",

        [Parameter(Mandatory=$false)]
        [bool]$UpdateSession = $true
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Path does not exist: $Path"
        return $false
    }

    $currentPath = [Environment]::GetEnvironmentVariable("Path", $Scope)
    $pathEntries = $currentPath -split ';' | Where-Object { $_ }

    # Check if already in PATH
    if ($pathEntries | Where-Object { $_ -eq $Path }) {
        Write-Verbose "PATH already contains: $Path"
        return $true
    }

    # Add to PATH
    $newPath = if ($currentPath) { "$currentPath;$Path" } else { $Path }
    [Environment]::SetEnvironmentVariable("Path", $newPath, $Scope)

    # Update current session if requested
    if ($UpdateSession) {
        $env:Path = "$env:Path;$Path"
    }

    Write-Verbose "Added to PATH ($Scope): $Path"
    return $true
}

<#
.SYNOPSIS
    Removes a path from the PATH environment variable
.PARAMETER Path
    The directory path to remove
.PARAMETER Scope
    User or Machine (default: User)
.PARAMETER UpdateSession
    If true, updates the current session's PATH (default: true)
.EXAMPLE
    Remove-FromPath "C:\MyApp\bin"
#>
function Remove-FromPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet("User", "Machine")]
        [string]$Scope = "User",

        [Parameter(Mandatory=$false)]
        [bool]$UpdateSession = $true
    )

    $currentPath = [Environment]::GetEnvironmentVariable("Path", $Scope)
    $pathEntries = $currentPath -split ';' | Where-Object { $_ -and $_ -ne $Path }

    $newPath = $pathEntries -join ';'
    [Environment]::SetEnvironmentVariable("Path", $newPath, $Scope)

    # Update current session if requested
    if ($UpdateSession) {
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("Path", "User")
    }

    Write-Verbose "Removed from PATH ($Scope): $Path"
    return $true
}

<#
.SYNOPSIS
    Checks if a path exists in the PATH environment variable
.PARAMETER Path
    The directory path to check
.PARAMETER Scope
    User, Machine, or Both (default: Both)
.EXAMPLE
    Test-InPath "C:\MyApp\bin"
#>
function Test-InPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [ValidateSet("User", "Machine", "Both")]
        [string]$Scope = "Both"
    )

    $scopes = switch ($Scope) {
        "User" { @("User") }
        "Machine" { @("Machine") }
        "Both" { @("User", "Machine") }
    }

    foreach ($s in $scopes) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", $s)
        $pathEntries = $currentPath -split ';' | Where-Object { $_ }

        if ($pathEntries | Where-Object { $_ -eq $Path }) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
    Gets all PATH entries for a given scope
.PARAMETER Scope
    User, Machine, or Both (default: Both)
.EXAMPLE
    Get-PathEntries
.EXAMPLE
    Get-PathEntries -Scope User
#>
function Get-PathEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("User", "Machine", "Both")]
        [string]$Scope = "Both"
    )

    $result = @{
        User = @()
        Machine = @()
    }

    if ($Scope -in @("User", "Both")) {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        $result.User = $userPath -split ';' | Where-Object { $_ }
    }

    if ($Scope -in @("Machine", "Both")) {
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $result.Machine = $machinePath -split ';' | Where-Object { $_ }
    }

    return $result
}

<#
.SYNOPSIS
    Cleans up PATH by removing duplicates and invalid entries
.PARAMETER Scope
    User, Machine, or Both (default: User)
.PARAMETER RemoveInvalid
    If true, removes paths that don't exist on disk (default: false)
.EXAMPLE
    Clean-Path
.EXAMPLE
    Clean-Path -Scope Both -RemoveInvalid $true
#>
function Clean-Path {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("User", "Machine", "Both")]
        [string]$Scope = "User",

        [Parameter(Mandatory=$false)]
        [bool]$RemoveInvalid = $false
    )

    $scopes = switch ($Scope) {
        "User" { @("User") }
        "Machine" { @("Machine") }
        "Both" { @("User", "Machine") }
    }

    foreach ($s in $scopes) {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", $s)
        $pathEntries = $currentPath -split ';' | Where-Object { $_ }

        # Remove duplicates
        $uniqueEntries = $pathEntries | Select-Object -Unique

        # Optionally remove invalid paths
        if ($RemoveInvalid) {
            $uniqueEntries = $uniqueEntries | Where-Object { Test-Path $_ }
        }

        $newPath = $uniqueEntries -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, $s)

        Write-Verbose "Cleaned PATH ($s): Removed $($pathEntries.Count - $uniqueEntries.Count) entries"
    }

    # Refresh session
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    return $true
}

<#
.SYNOPSIS
    Refreshes the current session's PATH from User and Machine scopes
.EXAMPLE
    Refresh-SessionPath
#>
function Refresh-SessionPath {
    [CmdletBinding()]
    param()

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    Write-Verbose "Session PATH refreshed"
    return $true
}

<#
.SYNOPSIS
    Backs up the current PATH to a file
.PARAMETER FilePath
    Path to save the backup
.PARAMETER Scope
    User, Machine, or Both (default: Both)
.EXAMPLE
    Backup-Path -FilePath "path-backup.txt"
#>
function Backup-Path {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [ValidateSet("User", "Machine", "Both")]
        [string]$Scope = "Both"
    )

    $backup = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Scope = $Scope
    }

    if ($Scope -in @("User", "Both")) {
        $backup.UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    }

    if ($Scope -in @("Machine", "Both")) {
        $backup.MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    }

    $backup | ConvertTo-Json | Out-File -FilePath $FilePath -Encoding UTF8

    Write-Verbose "PATH backed up to: $FilePath"
    return $true
}

# ============================================================================
# EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Add-ToPath',
    'Remove-FromPath',
    'Test-InPath',
    'Get-PathEntries',
    'Clean-Path',
    'Refresh-SessionPath',
    'Backup-Path'
)
