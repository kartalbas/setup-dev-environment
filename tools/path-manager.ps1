<#
.SYNOPSIS
  Interactive PATH Manager for Windows (User/System)

.DESCRIPTION
  Provides a menu-driven interface to manage PATH environment variable.
  Uses the path-manager module for core operations.

.NOTES
  Run as Administrator for System scope changes.
  Requires path-manager module to be installed.
#>

# ============================================================================
# IMPORT MODULE
# ============================================================================

$modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) "modules\windows\path-manager\path-manager.psm1"

if (Test-Path $modulePath) {
    Import-Module $modulePath -Force -ErrorAction Stop
} elseif (Get-Module -ListAvailable -Name "path-manager") {
    Import-Module "path-manager" -Force -ErrorAction Stop
} else {
    Write-Host "Error: path-manager module not found at: $modulePath" -ForegroundColor Red
    Write-Host "Please ensure the module is installed." -ForegroundColor Yellow
    exit 1
}

# ============================================================================
# INTERACTIVE MENU FUNCTIONS
# ============================================================================

function Show-Menu {
    param([string]$Scope)
    Clear-Host
    Write-Host "=== PATH Manager ($Scope) ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. List entries"
    Write-Host "2. Export to file"
    Write-Host "3. Import from file (merge)"
    Write-Host "4. Add entry"
    Write-Host "5. Remove entry"
    Write-Host "6. Edit entry"
    Write-Host "7. Clean duplicates"
    Write-Host "8. Diff two export files"
    Write-Host "0. Exit"
    Write-Host ""
}

function Run-Manager {
    param([ValidateSet("User","Machine")]$Scope)

    do {
        Show-Menu $Scope
        $choice = Read-Host "Select option"

        # Get current entries using module function
        $pathInfo = Get-PathEntries -Scope $Scope
        $entries = if ($Scope -eq "User") { $pathInfo.User } else { $pathInfo.Machine }

        switch ($choice) {
            "1" {
                Write-Host "`n[$Scope PATH entries]`n" -ForegroundColor Yellow
                for ($i=0; $i -lt $entries.Count; $i++) {
                    Write-Host "[$i] $($entries[$i])"
                }
                Read-Host "`nPress Enter to continue"
            }
            "2" {
                $file = Read-Host "Enter export filename"
                if ($file) {
                    Backup-Path -FilePath $file -Scope $Scope
                    Write-Host "Exported to $file" -ForegroundColor Green
                }
                Read-Host "`nPress Enter to continue"
            }
            "3" {
                $file = Read-Host "Enter import filename"
                if (Test-Path $file) {
                    $imported = Get-Content $file | ForEach-Object {
                        ($_ -split ';') | ForEach-Object { $_.Trim() }
                    } | Where-Object { $_ -ne "" }

                    foreach ($path in $imported) {
                        if (Test-Path $path) {
                            Add-ToPath -Path $path -Scope $Scope -UpdateSession $false
                        }
                    }
                    Refresh-SessionPath
                    Write-Host "Imported and merged entries from $file" -ForegroundColor Green
                } else {
                    Write-Host "File not found." -ForegroundColor Red
                }
                Read-Host "`nPress Enter to continue"
            }
            "4" {
                $new = Read-Host "Enter new path to add"
                if ($new) {
                    if (Test-InPath -Path $new -Scope $Scope) {
                        Write-Host "Already exists in PATH." -ForegroundColor Yellow
                    } else {
                        $result = Add-ToPath -Path $new -Scope $Scope
                        if ($result) {
                            Write-Host "Added successfully." -ForegroundColor Green
                        }
                    }
                }
                Read-Host "`nPress Enter to continue"
            }
            "5" {
                for ($i=0; $i -lt $entries.Count; $i++) {
                    Write-Host "[$i] $($entries[$i])"
                }
                $idx = Read-Host "Index to remove"
                if ($idx -match '^\d+$' -and [int]$idx -lt $entries.Count) {
                    Remove-FromPath -Path $entries[[int]$idx] -Scope $Scope
                    Write-Host "Removed." -ForegroundColor Green
                }
                Read-Host "`nPress Enter to continue"
            }
            "6" {
                for ($i=0; $i -lt $entries.Count; $i++) {
                    Write-Host "[$i] $($entries[$i])"
                }
                $idx = Read-Host "Index to edit"
                if ($idx -match '^\d+$' -and [int]$idx -lt $entries.Count) {
                    $oldPath = $entries[[int]$idx]
                    $newVal = Read-Host "New value (current: $oldPath)"
                    if ($newVal -and $newVal -ne $oldPath) {
                        Remove-FromPath -Path $oldPath -Scope $Scope -UpdateSession $false
                        Add-ToPath -Path $newVal -Scope $Scope
                        Write-Host "Updated." -ForegroundColor Green
                    }
                }
                Read-Host "`nPress Enter to continue"
            }
            "7" {
                Clean-Path -Scope $Scope
                Write-Host "Duplicates removed." -ForegroundColor Green
                Read-Host "`nPress Enter to continue"
            }
            "8" {
                $file1 = Read-Host "First file"
                $file2 = Read-Host "Second file"
                if ((Test-Path $file1) -and (Test-Path $file2)) {
                    $a = Get-Content $file1 | ForEach-Object {
                        ($_ -split ';') | ForEach-Object { $_.Trim() }
                    } | Where-Object { $_ -ne "" }

                    $b = Get-Content $file2 | ForEach-Object {
                        ($_ -split ';') | ForEach-Object { $_.Trim() }
                    } | Where-Object { $_ -ne "" }

                    Write-Host "`nIn $file1 but not in ${file2}:" -ForegroundColor Yellow
                    ($a | Where-Object { $_ -notin $b }) | ForEach-Object { Write-Host "  $_" }

                    Write-Host "`nIn $file2 but not in ${file1}:" -ForegroundColor Yellow
                    ($b | Where-Object { $_ -notin $a }) | ForEach-Object { Write-Host "  $_" }
                } else {
                    Write-Host "One or both files not found." -ForegroundColor Red
                }
                Read-Host "`nPress Enter to continue"
            }
        }
    } while ($choice -ne "0")
}

# ============================================================================
# ENTRY POINT
# ============================================================================

Clear-Host
Write-Host "PATH Manager" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan
Write-Host ""
Write-Host "Choose scope:"
Write-Host "1. User"
Write-Host "2. System (requires Admin)"
Write-Host ""
$scopeChoice = Read-Host "Enter 1 or 2"

if ($scopeChoice -eq "1") {
    Run-Manager -Scope User
}
elseif ($scopeChoice -eq "2") {
    Run-Manager -Scope Machine
}
else {
    Write-Host "Invalid choice." -ForegroundColor Red
}
