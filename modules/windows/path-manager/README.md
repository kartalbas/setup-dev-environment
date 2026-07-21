# Path Manager Module

PowerShell module for managing Windows PATH environment variable operations.

## Overview

The Path Manager module provides a comprehensive set of functions to safely manage the Windows PATH environment variable at both User and Machine (system) levels. It includes functionality for adding, removing, checking, cleaning, and backing up PATH entries.

## Installation

This module is automatically loaded by the setup script when enabled in the configuration file.

### Manual Loading

```powershell
Import-Module "path\to\path-manager.ps1" -Force
```

## Functions

### Add-ToPath

Safely adds a directory to the PATH environment variable.

**Parameters:**
- `Path` (string, required) - Directory path to add
- `Scope` (string) - "User" or "Machine" (default: "User")
- `UpdateSession` (bool) - Update current session PATH (default: true)

**Example:**
```powershell
# Add to User PATH
Add-ToPath -Path "C:\MyApp\bin"

# Add to Machine PATH (requires admin)
Add-ToPath -Path "C:\MyApp\bin" -Scope Machine

# Add without updating current session
Add-ToPath -Path "C:\MyApp\bin" -UpdateSession $false
```

### Remove-FromPath

Removes a directory from the PATH environment variable.

**Parameters:**
- `Path` (string, required) - Directory path to remove
- `Scope` (string) - "User", "Machine", or "Both" (default: "User")

**Example:**
```powershell
# Remove from User PATH
Remove-FromPath -Path "C:\OldApp\bin"

# Remove from both User and Machine PATH
Remove-FromPath -Path "C:\OldApp\bin" -Scope Both
```

### Test-InPath

Checks if a directory exists in the PATH environment variable.

**Parameters:**
- `Path` (string, required) - Directory path to check
- `Scope` (string) - "User", "Machine", or "Both" (default: "Both")

**Returns:** Boolean

**Example:**
```powershell
$exists = Test-InPath -Path "C:\MyApp\bin"
if ($exists) {
    Write-Host "Path is in PATH"
}

# Check only User PATH
$inUserPath = Test-InPath -Path "C:\MyApp\bin" -Scope User
```

### Get-PathEntries

Retrieves all PATH entries for specified scope(s).

**Parameters:**
- `Scope` (string) - "User", "Machine", or "Both" (default: "Both")

**Returns:** Hashtable with User and/or Machine arrays

**Example:**
```powershell
# Get all PATH entries
$paths = Get-PathEntries -Scope Both
Write-Host "User PATH has $($paths.User.Count) entries"
Write-Host "Machine PATH has $($paths.Machine.Count) entries"

# Get only User PATH
$userPaths = Get-PathEntries -Scope User
$userPaths.User | ForEach-Object { Write-Host $_ }
```

### Clean-Path

Removes duplicate and optionally invalid PATH entries.

**Parameters:**
- `Scope` (string) - "User", "Machine", or "Both" (default: "User")
- `RemoveInvalid` (bool) - Remove non-existent paths (default: false)

**Example:**
```powershell
# Remove duplicates from User PATH
Clean-Path -Scope User

# Remove duplicates and invalid paths from both
Clean-Path -Scope Both -RemoveInvalid $true
```

### Refresh-SessionPath

Reloads PATH in the current PowerShell session from registry.

**Example:**
```powershell
# After making PATH changes
Add-ToPath -Path "C:\NewApp\bin"
Refresh-SessionPath
# PATH is now updated in current session
```

### Backup-Path

Backs up current PATH configuration to a JSON file.

**Parameters:**
- `FilePath` (string) - Output file path
- `Scope` (string) - "User", "Machine", or "Both" (default: "Both")

**Example:**
```powershell
# Backup both User and Machine PATH
$backupFile = "C:\Backup\path-backup.json"
Backup-Path -FilePath $backupFile -Scope Both

# Backup only User PATH
Backup-Path -FilePath "path-user.json" -Scope User
```

## Best Practices

### 1. Always Check Before Adding

```powershell
if (-not (Test-InPath -Path "C:\MyApp\bin")) {
    Add-ToPath -Path "C:\MyApp\bin"
}
```

### 2. Clean PATH Regularly

```powershell
# Remove duplicates but keep invalid paths (safer)
Clean-Path -Scope User

# Or remove both duplicates and invalid paths
Clean-Path -Scope User -RemoveInvalid $true
```

### 3. Backup Before Major Changes

```powershell
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupFile = "path-backup-$timestamp.json"
Backup-Path -FilePath $backupFile -Scope Both

# Make changes...
Add-ToPath -Path "C:\NewApp\bin"
```

### 4. Use Appropriate Scope

- **User Scope**: For personal tools, no admin required
- **Machine Scope**: For system-wide tools, requires admin

```powershell
# Regular user installation
Add-ToPath -Path "C:\Users\$env:USERNAME\Tools\bin" -Scope User

# System-wide installation (admin)
if ($isAdmin) {
    Add-ToPath -Path "C:\ProgramData\Tools\bin" -Scope Machine
}
```

### 5. Refresh Session After Changes

```powershell
Add-ToPath -Path "C:\MyApp\bin"
Refresh-SessionPath
# Now you can use commands from C:\MyApp\bin immediately
```

## Common Patterns

### Pattern 1: Conditional Installation

```powershell
$toolPath = "C:\Tools\MyTool\bin"

if (Test-Path $toolPath) {
    if (-not (Test-InPath -Path $toolPath)) {
        Add-ToPath -Path $toolPath
        Write-Host "Added to PATH: $toolPath"
    } else {
        Write-Host "Already in PATH: $toolPath"
    }
} else {
    Write-Host "Warning: Path does not exist: $toolPath"
}
```

### Pattern 2: Cleanup and Add

```powershell
# Remove old path if exists
$oldPath = "C:\OldApp\bin"
if (Test-InPath -Path $oldPath) {
    Remove-FromPath -Path $oldPath
}

# Add new path
$newPath = "C:\NewApp\bin"
Add-ToPath -Path $newPath

# Clean up duplicates
Clean-Path -Scope User
```

### Pattern 3: Migration Script

```powershell
# Backup current PATH
Backup-Path -FilePath "path-backup-migration.json" -Scope Both

# Remove old paths
@("C:\OldTool1\bin", "C:\OldTool2\bin") | ForEach-Object {
    Remove-FromPath -Path $_ -Scope Both
}

# Add new paths
@("C:\NewTool1\bin", "C:\NewTool2\bin") | ForEach-Object {
    Add-ToPath -Path $_ -Scope User
}

# Cleanup
Clean-Path -Scope User -RemoveInvalid $true
Refresh-SessionPath
```

## Error Handling

All functions include built-in error handling:

```powershell
try {
    Add-ToPath -Path "C:\MyApp\bin" -Scope Machine
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    # Fall back to user scope
    Add-ToPath -Path "C:\MyApp\bin" -Scope User
}
```

## Verbose Output

Enable verbose output for debugging:

```powershell
Add-ToPath -Path "C:\MyApp\bin" -Verbose
Clean-Path -Scope User -Verbose
```

## Requirements

- PowerShell 5.1 or higher
- Windows 10/11
- Administrator rights required for Machine scope operations

## Version

Current Version: 1.0.0

## Related Modules

- [winget-manager](../winget-manager/README.md) - Windows Package Manager operations
- [scoop-manager](../scoop-manager/README.md) - Scoop package manager operations

## License

MIT License - See [LICENSE](../../../LICENSE)
