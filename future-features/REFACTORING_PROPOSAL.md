# 🔧 Refactoring Proposal: Layered Architecture for Better Maintainability

## Executive Summary

Refactor the monolithic scripts into a clean, layered architecture that separates concerns, improves testability, and makes the codebase easier to maintain and extend.

## Current Problems

### 1. **Monolithic Structure**
- Single large file (70KB+ PowerShell, 25KB+ bash)
- All logic in one place
- Hard to find specific functionality
- Difficult to reason about

### 2. **Tight Coupling**
- Installation logic mixed with configuration
- UI/output mixed with business logic
- No clear boundaries between components

### 3. **No Separation of Concerns**
- Config parsing + validation + installation + UI all intertwined
- Hard to test individual pieces
- Changes ripple through entire codebase

### 4. **Difficult to Extend**
- Adding new tool requires editing massive file
- No plugin system
- Copy-paste for similar tools

---

## Proposed Layered Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    CLI Interface                         │  Entry point, arg parsing
├─────────────────────────────────────────────────────────┤
│                 Presentation Layer                       │  UI, colors, messages
├─────────────────────────────────────────────────────────┤
│               Application/Service Layer                  │  Orchestration, workflows
├─────────────────────────────────────────────────────────┤
│                   Business Logic                         │  Installation logic
├─────────────────────────────────────────────────────────┤
│                  Domain Layer                            │  Models, entities
├─────────────────────────────────────────────────────────┤
│              Infrastructure Layer                        │  External calls (scoop, apt)
├─────────────────────────────────────────────────────────┤
│                    Data Layer                            │  Config parsing
└─────────────────────────────────────────────────────────┘
```

---

## Layer-by-Layer Breakdown

### Layer 1: Data Layer (Bottom)
**Responsibility**: Read and parse configuration files

**Files:**
```
src/
├── data/
│   ├── config-parser.ps1        # Windows
│   ├── config-parser.sh         # Ubuntu/macOS
│   └── validators.ps1/sh        # Config validation
```

**Interface:**
```powershell
# config-parser.ps1
class ConfigParser {
    [hashtable] ParseFile([string]$filePath)
    [bool] ValidateConfig([hashtable]$config)
    [object] GetSection([hashtable]$config, [string]$section)
}
```

**Benefits:**
- Config parsing isolated
- Easy to test with fixture files
- Can swap config format (JSON, YAML, TOML)
- Single responsibility

---

### Layer 2: Domain Layer
**Responsibility**: Core business entities and models

**Files:**
```
src/
├── domain/
│   ├── models/
│   │   ├── Package.ps1         # Package entity
│   │   ├── Language.ps1        # Language entity
│   │   ├── Tool.ps1            # Tool entity
│   │   └── InstallationPlan.ps1
│   └── interfaces/
│       ├── IPackageManager.ps1
│       ├── IInstaller.ps1
│       └── IValidator.ps1
```

**Example:**
```powershell
# Package.ps1
class Package {
    [string]$Name
    [string]$DisplayName
    [string]$Version
    [bool]$IsInstalled
    [string]$Source  # scoop, winget, manual

    [bool] ShouldInstall([hashtable]$config) {
        # Business rule: should this package be installed?
    }
}

# InstallationPlan.ps1
class InstallationPlan {
    [Package[]]$Packages
    [Language[]]$Languages
    [Tool[]]$Tools

    [void] AddPackage([Package]$pkg) { }
    [int] GetTotalCount() { }
}
```

**Benefits:**
- Clear data structures
- Business rules in one place
- Type safety
- Self-documenting

---

### Layer 3: Infrastructure Layer
**Responsibility**: External system interactions (scoop, apt, brew, curl)

**Files:**
```
src/
├── infrastructure/
│   ├── package-managers/
│   │   ├── ScoopManager.ps1
│   │   ├── WingetManager.ps1
│   │   ├── AptManager.sh
│   │   ├── BrewManager.sh
│   │   └── SnapManager.sh
│   ├── installers/
│   │   ├── NvmInstaller.ps1/sh
│   │   ├── RustupInstaller.ps1/sh
│   │   ├── YarnInstaller.ps1/sh
│   │   └── PnpmInstaller.ps1/sh
│   └── system/
│       ├── CommandChecker.ps1/sh
│       ├── PathManager.ps1/sh
│       └── EnvironmentManager.ps1/sh
```

**Example:**
```powershell
# ScoopManager.ps1
class ScoopManager : IPackageManager {
    [bool] IsInstalled($package) {
        $result = scoop list $package 2>$null
        return $result -ne $null
    }

    [bool] Install($package) {
        $result = scoop install $package 2>&1
        return $LASTEXITCODE -eq 0
    }

    [bool] Uninstall($package) {
        $result = scoop uninstall $package 2>&1
        return $LASTEXITCODE -eq 0
    }
}

# NvmInstaller.ps1
class NvmInstaller : IInstaller {
    [string]$Version = "1.1.12"
    [string]$DownloadUrl = "https://github.com/coreybutler/nvm-windows/releases/download/$($this.Version)/nvm-setup.exe"

    [bool] IsInstalled() {
        return Test-CommandExists "nvm"
    }

    [bool] Install() {
        $installer = $this.Download()
        return $this.RunInstaller($installer)
    }

    [bool] InstallLts() {
        nvm install --lts
        nvm use --lts
    }
}
```

**Benefits:**
- Easy to mock for testing
- Platform-specific implementations
- Swap implementations (real/test)
- Clear interface contracts

---

### Layer 4: Business Logic Layer
**Responsibility**: Core installation workflows and decision logic

**Files:**
```
src/
├── services/
│   ├── InstallationService.ps1
│   ├── PackageSelector.ps1
│   ├── DependencyResolver.ps1
│   ├── VersionChecker.ps1
│   └── ValidationService.ps1
```

**Example:**
```powershell
# InstallationService.ps1
class InstallationService {
    [IPackageManager]$PackageManager
    [ILogger]$Logger

    InstallationService([IPackageManager]$pm, [ILogger]$logger) {
        $this.PackageManager = $pm
        $this.Logger = $logger
    }

    [InstallationResult] InstallPackage([Package]$package) {
        if ($package.IsInstalled) {
            $this.Logger.Success("$($package.DisplayName) already installed")
            return [InstallationResult]::Skipped
        }

        $this.Logger.Info("Installing $($package.DisplayName)...")

        $success = $this.PackageManager.Install($package.Name)

        if ($success) {
            $this.Logger.Success("$($package.DisplayName) installed")
            return [InstallationResult]::Success
        } else {
            $this.Logger.Error("Failed to install $($package.DisplayName)")
            return [InstallationResult]::Failed
        }
    }

    [InstallationSummary] InstallAll([InstallationPlan]$plan) {
        $summary = [InstallationSummary]::new()

        foreach ($package in $plan.Packages) {
            $result = $this.InstallPackage($package)
            $summary.Add($package, $result)
        }

        return $summary
    }
}

# DependencyResolver.ps1
class DependencyResolver {
    [Package[]] ResolveDependencies([Package[]]$packages) {
        # Example: Node.js needed for Yarn
        # Git needed for GitHub CLI
        # etc.
    }

    [Package[]] TopologicalSort([Package[]]$packages) {
        # Install in correct order
    }
}
```

**Benefits:**
- Core business logic isolated
- Easy to test with mocks
- No UI concerns
- Reusable workflows

---

### Layer 5: Application/Service Layer (Orchestration)
**Responsibility**: High-level workflows, coordinate services

**Files:**
```
src/
├── application/
│   ├── UserLevelSetup.ps1
│   ├── AdminLevelSetup.ps1
│   ├── ConfigurationManager.ps1
│   └── SetupOrchestrator.ps1
```

**Example:**
```powershell
# SetupOrchestrator.ps1
class SetupOrchestrator {
    [ConfigParser]$ConfigParser
    [InstallationService]$InstallationService
    [DependencyResolver]$DependencyResolver
    [ILogger]$Logger

    [void] RunSetup([string]$configFile, [SetupOptions]$options) {
        # 1. Parse config
        $this.Logger.Section("Parsing configuration...")
        $config = $this.ConfigParser.ParseFile($configFile)

        # 2. Build installation plan
        $this.Logger.Section("Building installation plan...")
        $plan = $this.BuildInstallationPlan($config, $options)

        # 3. Resolve dependencies
        $this.Logger.Section("Resolving dependencies...")
        $orderedPackages = $this.DependencyResolver.ResolveDependencies($plan.Packages)
        $plan.Packages = $orderedPackages

        # 4. Execute installation
        $this.Logger.Section("Installing packages...")
        $summary = $this.InstallationService.InstallAll($plan)

        # 5. Post-install configuration
        $this.Logger.Section("Configuring environment...")
        $this.ConfigureEnvironment($plan)

        # 6. Display summary
        $this.Logger.Summary($summary)
    }
}
```

**Benefits:**
- High-level workflow visible
- Easy to add new workflows
- Coordinate multiple services
- Transaction-like behavior

---

### Layer 6: Presentation Layer
**Responsibility**: User interface, output formatting, colors

**Files:**
```
src/
├── presentation/
│   ├── Logger.ps1
│   ├── ConsoleUI.ps1
│   ├── ProgressBar.ps1
│   └── OutputFormatter.ps1
```

**Example:**
```powershell
# Logger.ps1
class Logger : ILogger {
    [bool]$UseColors = $true
    [bool]$Verbose = $false

    [void] Success([string]$message) {
        $this.WriteColored("  ✓ $message", "Green")
    }

    [void] Error([string]$message) {
        $this.WriteColored("  ✗ $message", "Red")
    }

    [void] Info([string]$message) {
        $this.WriteColored("  → $message", "Cyan")
    }

    [void] Section([string]$title) {
        Write-Host "`n$('═' * 70)" -ForegroundColor Cyan
        Write-Host " $title" -ForegroundColor Yellow
        Write-Host "$('═' * 70)" -ForegroundColor Cyan
    }

    [void] Summary([InstallationSummary]$summary) {
        $this.Section("Installation Complete!")
        Write-Host ""
        Write-Host "  Succeeded: $($summary.SuccessCount)" -ForegroundColor Green
        Write-Host "  Failed: $($summary.FailedCount)" -ForegroundColor Red
        Write-Host "  Skipped: $($summary.SkippedCount)" -ForegroundColor Gray
    }
}

# ProgressBar.ps1
class ProgressBar {
    [int]$Total
    [int]$Current = 0

    [void] Update([string]$currentItem) {
        $percent = ($this.Current / $this.Total) * 100
        Write-Progress -Activity "Installing packages" `
                       -Status "$currentItem ($($this.Current)/$($this.Total))" `
                       -PercentComplete $percent
    }
}
```

**Benefits:**
- UI completely separated
- Easy to add progress bars
- Can switch to GUI later
- Testable (mock logger)

---

### Layer 7: CLI Interface (Entry Point)
**Responsibility**: Parse arguments, bootstrap application

**Files:**
```
setup-dev-environment.ps1        # Slim entry point
setup-dev-environment-ubuntu.sh  # Slim entry point
setup-dev-environment-macos.sh   # Slim entry point
```

**Example:**
```powershell
# setup-dev-environment.ps1 (simplified)
param(
    [switch]$ToolsUserRights,
    [switch]$ToolsAdminRights,
    [switch]$DryRun,
    [string]$ConfigFile = ""
)

# Load modules
. "$PSScriptRoot/src/bootstrap.ps1"

# Create dependencies
$logger = [Logger]::new()
$configParser = [ConfigParser]::new()
$scoopManager = [ScoopManager]::new()
$installationService = [InstallationService]::new($scoopManager, $logger)
$dependencyResolver = [DependencyResolver]::new()
$orchestrator = [SetupOrchestrator]::new($configParser, $installationService, $dependencyResolver, $logger)

# Build options
$options = [SetupOptions]@{
    Mode = if ($ToolsUserRights) { "User" } else { "Admin" }
    DryRun = $DryRun
    ConfigFile = $ConfigFile
}

# Run setup
try {
    $orchestrator.RunSetup($options.ConfigFile, $options)
    exit 0
} catch {
    $logger.Error("Setup failed: $_")
    exit 1
}
```

**Benefits:**
- Super thin entry point
- Easy to understand flow
- All complexity hidden in layers
- Easy to add new flags

---

## Directory Structure (Refactored)

```
setup-dev-environment/
├── setup-dev-environment.ps1              # Entry point (50 lines)
├── setup-dev-environment-ubuntu.sh        # Entry point (50 lines)
├── setup-dev-environment-macos.sh         # Entry point (50 lines)
├── setup-dev-environment-windows.config
├── setup-dev-environment-ubuntu.config
├── setup-dev-environment-macos.config
├── README.md
├── LICENSE
├── .gitignore
│
├── src/
│   ├── bootstrap.ps1                      # Load all modules
│   ├── bootstrap.sh                       # Load all modules
│   │
│   ├── data/                              # Layer 1: Data
│   │   ├── ConfigParser.ps1
│   │   ├── ConfigParser.sh
│   │   ├── ConfigValidator.ps1
│   │   └── ConfigValidator.sh
│   │
│   ├── domain/                            # Layer 2: Domain
│   │   ├── models/
│   │   │   ├── Package.ps1
│   │   │   ├── Language.ps1
│   │   │   ├── Tool.ps1
│   │   │   ├── InstallationPlan.ps1
│   │   │   └── InstallationSummary.ps1
│   │   └── interfaces/
│   │       ├── IPackageManager.ps1
│   │       ├── IInstaller.ps1
│   │       ├── ILogger.ps1
│   │       └── IValidator.ps1
│   │
│   ├── infrastructure/                    # Layer 3: Infrastructure
│   │   ├── package-managers/
│   │   │   ├── windows/
│   │   │   │   ├── ScoopManager.ps1
│   │   │   │   └── WingetManager.ps1
│   │   │   ├── ubuntu/
│   │   │   │   ├── AptManager.sh
│   │   │   │   └── SnapManager.sh
│   │   │   └── macos/
│   │   │       ├── BrewManager.sh
│   │   │       └── BrewCaskManager.sh
│   │   ├── installers/
│   │   │   ├── NvmInstaller.ps1
│   │   │   ├── NvmInstaller.sh
│   │   │   ├── YarnInstaller.ps1
│   │   │   ├── YarnInstaller.sh
│   │   │   ├── PnpmInstaller.ps1
│   │   │   ├── PnpmInstaller.sh
│   │   │   ├── RustupInstaller.ps1
│   │   │   └── RustupInstaller.sh
│   │   └── system/
│   │       ├── CommandChecker.ps1
│   │       ├── CommandChecker.sh
│   │       ├── PathManager.ps1
│   │       ├── PathManager.sh
│   │       ├── EnvironmentManager.ps1
│   │       └── EnvironmentManager.sh
│   │
│   ├── services/                          # Layer 4: Business Logic
│   │   ├── InstallationService.ps1
│   │   ├── InstallationService.sh
│   │   ├── PackageSelector.ps1
│   │   ├── PackageSelector.sh
│   │   ├── DependencyResolver.ps1
│   │   ├── DependencyResolver.sh
│   │   ├── VersionChecker.ps1
│   │   └── VersionChecker.sh
│   │
│   ├── application/                       # Layer 5: Orchestration
│   │   ├── SetupOrchestrator.ps1
│   │   ├── SetupOrchestrator.sh
│   │   ├── UserLevelSetup.ps1
│   │   ├── UserLevelSetup.sh
│   │   ├── AdminLevelSetup.ps1
│   │   └── ConfigurationManager.ps1
│   │
│   └── presentation/                      # Layer 6: UI
│       ├── Logger.ps1
│       ├── Logger.sh
│       ├── ConsoleUI.ps1
│       ├── ConsoleUI.sh
│       ├── ProgressBar.ps1
│       └── OutputFormatter.ps1
│
├── tests/                                 # Tests mirror src structure
│   ├── unit/
│   │   ├── data/
│   │   ├── domain/
│   │   ├── infrastructure/
│   │   ├── services/
│   │   └── presentation/
│   ├── integration/
│   ├── e2e/
│   └── smoke/
│
└── future-features/
    ├── TESTING_PROPOSAL.md
    └── REFACTORING_PROPOSAL.md            # This document
```

---

## Migration Strategy

### Phase 1: Extract Data Layer (Week 1)
1. Create `src/data/ConfigParser.ps1`
2. Move config parsing logic
3. Add tests for config parser
4. Replace inline parsing with new module
5. Verify existing functionality works

### Phase 2: Extract Infrastructure Layer (Week 2-3)
1. Create package manager interfaces
2. Implement ScoopManager, AptManager, BrewManager
3. Add tests with mocks
4. Replace direct scoop/apt/brew calls
5. Verify installations still work

### Phase 3: Extract Business Logic (Week 4-5)
1. Create InstallationService
2. Move installation logic
3. Create DependencyResolver
4. Add comprehensive tests
5. Wire up services

### Phase 4: Extract Presentation (Week 6)
1. Create Logger class
2. Move all UI/output logic
3. Consistent formatting
4. Add color themes

### Phase 5: Create Domain Models (Week 7)
1. Define Package, Tool, Language models
2. Move data structures
3. Add validation rules
4. Type safety

### Phase 6: Orchestration Layer (Week 8)
1. Create SetupOrchestrator
2. High-level workflows
3. Coordinate all services
4. Clean entry points

### Phase 7: Testing & Documentation (Week 9-10)
1. Comprehensive test suite
2. Update all documentation
3. Migration guide
4. Performance testing

---

## Benefits of This Approach

### 1. **Testability**
- Each layer independently testable
- Easy to mock dependencies
- Fast unit tests
- Comprehensive coverage

### 2. **Maintainability**
- Small, focused files (100-200 lines each)
- Single Responsibility Principle
- Easy to find code
- Clear boundaries

### 3. **Extensibility**
- Add new package managers easily
- Plugin system possible
- Swap implementations
- Version compatibility

### 4. **Readability**
- Clear file structure
- Self-documenting architecture
- Obvious dependencies
- Easy onboarding

### 5. **Reusability**
- Services can be reused
- Infrastructure shared
- Domain models portable
- Less duplication

### 6. **Performance**
- Lazy loading possible
- Parallel installation easier
- Progress tracking natural
- Caching opportunities

---

## Example: Adding a New Package Manager

**Before (Current Monolithic):**
```powershell
# Add 200+ lines to already-huge file
# Search for similar patterns
# Copy-paste-modify
# Hope nothing breaks
```

**After (Layered):**
```powershell
# 1. Create new file: src/infrastructure/package-managers/ChocolateyManager.ps1
class ChocolateyManager : IPackageManager {
    [bool] IsInstalled($package) { choco list --local-only $package }
    [bool] Install($package) { choco install $package -y }
    [bool] Uninstall($package) { choco uninstall $package -y }
}

# 2. Register in bootstrap.ps1
$chocoManager = [ChocolateyManager]::new()

# 3. Use in service
$installationService = [InstallationService]::new($chocoManager, $logger)

# Done! ~20 lines of code, no risk to existing functionality
```

---

## Trade-offs

### Pros
✅ Much better architecture
✅ Highly testable
✅ Easy to maintain
✅ Professional codebase
✅ Extensible
✅ Reusable components

### Cons
❌ Significant refactoring effort (~80-120 hours)
❌ More files to manage
❌ Steeper learning curve for contributors
❌ Initial complexity increase
❌ Need to learn OOP patterns

---

## Recommendation

**Hybrid Approach:**

1. **Start with Infrastructure Layer** (Week 1-3)
   - Extract package managers first
   - Immediate testability improvement
   - Low risk, high value

2. **Add Business Logic Layer** (Week 4-6)
   - Extract services
   - Clean up main script
   - Better separation

3. **Evaluate** (Week 7)
   - Is this good enough?
   - Do we need full Domain layer?
   - Continue or stabilize?

This gives quick wins without committing to full refactoring upfront.

---

## Next Steps

1. **Decision**: Which approach?
   - [ ] Minimal (just Infrastructure)
   - [ ] Moderate (Infrastructure + Services)
   - [ ] Full (All layers)

2. **Timeline**: When to start?
   - [ ] Immediately
   - [ ] After testing is added
   - [ ] Next quarter

3. **Resources**: Who will do it?
   - [ ] Solo effort
   - [ ] Team effort
   - [ ] Community contributions

---

**Document Version**: 1.0
**Last Updated**: 2024-11-11
**Status**: Proposal
**Dependencies**: None (can start immediately)
**Risk Level**: Medium (significant changes, but incremental)
