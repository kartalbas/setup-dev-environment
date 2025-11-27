# 🧪 Testing Proposal for Cross-Platform Dev Environment Setup

## Executive Summary

This document outlines a comprehensive testing strategy for the setup scripts across Windows, Ubuntu, and macOS platforms. The goal is to ensure reliability, catch regressions, and enable confident contributions.

## Current State Analysis

### Testability Assessment

**Current Strengths:**
- ✅ Modular functions (good separation of concerns)
- ✅ Config parsing is isolated
- ✅ Helper functions exist (command_exists, get_config_value)
- ✅ Clear function boundaries

**Current Limitations:**
- ❌ Tightly coupled (installation logic mixed with execution)
- ❌ Side effects everywhere (direct system calls, no mocking points)
- ❌ Hard to isolate (functions modify system state)
- ❌ No dependency injection (can't swap real installers with test doubles)

## Testing Strategy Overview

We propose a **4-layered pyramid approach**:

```
        ┌─────────────┐
        │  E2E Tests  │  Slow, Real System (CI/CD)
        └─────────────┘
      ┌───────────────────┐
      │ Integration Tests │  Medium, Mocked System
      └───────────────────┘
    ┌───────────────────────┐
    │     Unit Tests        │  Fast, Pure Logic
    └───────────────────────┘
  ┌───────────────────────────┐
  │      Smoke Tests          │  Quick Validation
  └───────────────────────────┘
```

---

## 1. Unit Tests (Fast, Isolated)

### Scope
Test individual functions without system side effects.

### What to Test
- Config file parsing
- Helper functions (command_exists, get_config_value, path resolution)
- String manipulation and validation
- Logic branches (if/else conditions)

### Testing Frameworks

**Windows (PowerShell):**
- **Pester** - Native PowerShell testing framework
- Install: `Install-Module -Name Pester -Force`

**Ubuntu/macOS (Bash):**
- **Bats** (Bash Automated Testing System)
- Install: `npm install -g bats` or `brew install bats-core`
- Alternative: **shUnit2**

### Example Test Structure

```
tests/
├── unit/
│   ├── windows/
│   │   ├── ConfigParser.Tests.ps1
│   │   ├── HelperFunctions.Tests.ps1
│   │   └── PathResolution.Tests.ps1
│   ├── ubuntu/
│   │   ├── config_parser.bats
│   │   ├── helper_functions.bats
│   │   └── path_resolution.bats
│   └── macos/
│       ├── config_parser.bats
│       ├── helper_functions.bats
│       └── homebrew_helpers.bats
```

### Example: Pester Test (Windows)

```powershell
# tests/unit/windows/ConfigParser.Tests.ps1

Describe "Config Parser" {
    BeforeAll {
        # Source the main script functions
        . "$PSScriptRoot/../../../setup-dev-environment.ps1" -WhatIf
    }

    Context "When parsing valid config" {
        It "Should parse General section correctly" {
            $testConfig = @"
[General]
MinimalInstall=false
"@
            $testConfigFile = New-TemporaryFile
            $testConfig | Out-File $testConfigFile

            $result = Read-ConfigFile -FilePath $testConfigFile

            $result.General.MinimalInstall | Should -Be "false"
        }

        It "Should parse NodeJS config with inline comments" {
            $testConfig = @"
[UserLevel.Languages.NodeJS]
nvm=true    # Install NVM
"@
            $testConfigFile = New-TemporaryFile
            $testConfig | Out-File $testConfigFile

            $result = Read-ConfigFile -FilePath $testConfigFile

            $result['UserLevel.Languages.NodeJS'].nvm | Should -Be "true"
        }
    }

    Context "When parsing invalid config" {
        It "Should handle missing section gracefully" {
            $testConfig = "nvm=true"
            $testConfigFile = New-TemporaryFile
            $testConfig | Out-File $testConfigFile

            { Read-ConfigFile -FilePath $testConfigFile } | Should -Not -Throw
        }
    }
}
```

### Example: Bats Test (Ubuntu/macOS)

```bash
#!/usr/bin/env bats
# tests/unit/ubuntu/config_parser.bats

setup() {
    # Load the functions from the main script
    source "${BATS_TEST_DIRNAME}/../../../setup-dev-environment-ubuntu.sh"

    # Create temp config file
    TEST_CONFIG=$(mktemp)
}

teardown() {
    rm -f "$TEST_CONFIG"
}

@test "parse_config: handles General section" {
    cat > "$TEST_CONFIG" << EOF
[General]
MinimalInstall=false
EOF

    parse_config "$TEST_CONFIG"

    [[ "${CONFIG[General.MinimalInstall]}" == "false" ]]
}

@test "parse_config: strips inline comments" {
    cat > "$TEST_CONFIG" << EOF
[UserLevel.Languages.NodeJS]
nvm=true    # Install NVM
EOF

    parse_config "$TEST_CONFIG"

    [[ "${CONFIG[UserLevel.Languages.NodeJS.nvm]}" == "true" ]]
}

@test "get_config_value: returns value if exists" {
    CONFIG[test.key]="value"

    result=$(get_config_value "test.key")

    [[ "$result" == "value" ]]
}

@test "get_config_value: returns default if key missing" {
    result=$(get_config_value "nonexistent.key" "default")

    [[ "$result" == "default" ]]
}
```

---

## 2. Integration Tests (Medium Speed, Mocked)

### Scope
Test installation workflows with mocked system calls.

### What to Test
- Package installation flow (mocked scoop/apt/brew)
- NVM installation (mocked curl/installers)
- Config-to-installation pipeline
- Error handling and recovery
- Flag combinations (--force-install, --dry-run)

### Approach: Mock External Commands

**Windows (PowerShell):**
```powershell
# tests/integration/windows/Installation.Tests.ps1

Describe "Package Installation" {
    BeforeAll {
        # Mock scoop commands
        Mock scoop {
            param($Command, $Package)
            if ($Command -eq "list") {
                return @()  # Package not installed
            }
            return 0  # Success
        }
    }

    It "Should install package when not present" {
        Install-ScoopPackage -Package "git" -ShouldInstall $true

        Assert-MockCalled scoop -Times 2
    }

    It "Should skip package when already installed" {
        Mock scoop {
            if ($Command -eq "list") {
                return "git"  # Package installed
            }
        }

        Install-ScoopPackage -Package "git" -ShouldInstall $true

        Assert-MockCalled scoop -Times 1  # Only called for check, not install
    }
}
```

**Ubuntu/macOS (Bash):**
```bash
#!/usr/bin/env bats
# tests/integration/ubuntu/installation.bats

setup() {
    # Mock apt-get
    apt-get() {
        echo "Mock: apt-get $@" >&2
        return 0
    }
    export -f apt-get

    # Mock dpkg
    dpkg() {
        if [[ "$1" == "-l" ]]; then
            echo ""  # Package not installed
        fi
        return 0
    }
    export -f dpkg
}

@test "install_apt_package: installs when not present" {
    run install_apt_package "git" "Git" "true"

    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Installing Git" ]]
}
```

---

## 3. End-to-End (E2E) Tests (Slow, Real System)

### Scope
Test full installations in isolated environments.

### Platforms

**Ubuntu - Docker Containers:**
```dockerfile
# tests/e2e/ubuntu/Dockerfile.test
FROM ubuntu:22.04

# Install prerequisites
RUN apt-get update && apt-get install -y \
    curl \
    git \
    sudo

# Copy scripts
COPY setup-dev-environment-ubuntu.sh /test/
COPY setup-dev-environment-ubuntu.config /test/

# Run tests
WORKDIR /test
CMD ["./setup-dev-environment-ubuntu.sh", "--user"]
```

**Windows - Windows Sandbox or VM:**
```powershell
# tests/e2e/windows/run-e2e.ps1

# Create Windows Sandbox config
@"
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>$PSScriptRoot\..\..</HostFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -File setup-dev-environment.ps1 -ToolsUserRights</Command>
  </LogonCommand>
</Configuration>
"@ | Out-File "$PSScriptRoot\sandbox.wsb"

# Launch sandbox
Start-Process "$PSScriptRoot\sandbox.wsb"
```

**macOS - CI Runner or VM:**
```bash
# tests/e2e/macos/run-e2e.sh
#!/bin/bash

# Run in macOS VM or GitHub Actions runner
./setup-dev-environment-macos.sh --user

# Verify installations
command -v git || exit 1
command -v node || exit 1
command -v python3 || exit 1
```

### Test Script Example

```bash
#!/usr/bin/env bats
# tests/e2e/ubuntu/full-install.bats

@test "Full installation completes successfully" {
    run ./setup-dev-environment-ubuntu.sh --user

    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "Installation Complete" ]]
}

@test "Git is installed and in PATH" {
    command -v git
}

@test "Node.js is installed via NVM" {
    source "$HOME/.nvm/nvm.sh"
    command -v node
}

@test "Python3 is installed" {
    command -v python3
}
```

---

## 4. Smoke Tests (Quick Validation)

### Scope
Quick checks after installation to ensure basic functionality.

### What to Test
- Installed tools are in PATH
- Tools can execute basic commands
- Versions are reasonable

### Example

```bash
#!/bin/bash
# tests/smoke/verify-installation.sh

echo "🔍 Running smoke tests..."

# Check Git
if command -v git &>/dev/null; then
    echo "✓ Git installed: $(git --version)"
else
    echo "✗ Git not found"
    exit 1
fi

# Check Node.js
if command -v node &>/dev/null; then
    echo "✓ Node.js installed: $(node --version)"
else
    echo "✗ Node.js not found"
    exit 1
fi

# Check Python
if command -v python3 &>/dev/null; then
    echo "✓ Python3 installed: $(python3 --version)"
else
    echo "✗ Python3 not found"
    exit 1
fi

echo "✅ All smoke tests passed!"
```

---

## Refactoring Requirements

### Option 1: Minimal Refactoring (Recommended)

Add testability hooks without major changes.

**Changes Required:**

1. **Add `--dry-run` flag** (all scripts)
   ```powershell
   param([switch]$DryRun = $false)
   ```

2. **Add `--test-mode` flag** (all scripts)
   ```powershell
   param([switch]$TestMode = $false)
   ```

3. **Extract pure functions** (separate logic from side effects)
   ```powershell
   # Pure logic (testable)
   function Get-PackagesToInstall {
       param($Config)
       # Logic only, no installation
       return $packages
   }

   # Side effects (calls installers)
   function Install-Packages {
       param($Packages)
       # Actual installation
   }
   ```

4. **Add output capture** for testing
   ```powershell
   function Write-TestableOutput {
       param($Message, $Level)
       if ($TestMode) {
           return [PSCustomObject]@{
               Message = $Message
               Level = $Level
           }
       }
       Write-Host $Message -ForegroundColor $Level
   }
   ```

### Option 2: Moderate Refactoring

Separate concerns more cleanly.

**Changes Required:**

1. **Dependency Injection**
   ```powershell
   function Install-Package {
       param(
           $Package,
           [scriptblock]$Installer = { scoop install $args[0] }
       )
       & $Installer $Package
   }

   # Test usage
   $mockInstaller = { param($pkg); Write-Host "Mock: $pkg" }
   Install-Package "git" -Installer $mockInstaller
   ```

2. **Interface-based design**
   ```powershell
   class IPackageManager {
       [void] Install($package) { throw "Not implemented" }
   }

   class ScoopPackageManager : IPackageManager {
       [void] Install($package) { scoop install $package }
   }

   class MockPackageManager : IPackageManager {
       [void] Install($package) { Write-Host "Mock: $package" }
   }
   ```

---

## CI/CD Integration (GitHub Actions)

### Workflow Structure

```yaml
# .github/workflows/test.yml

name: Cross-Platform Tests

on:
  push:
    branches: [ master, develop ]
  pull_request:
    branches: [ master ]

jobs:
  unit-tests-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Pester
        shell: powershell
        run: Install-Module -Name Pester -Force -SkipPublisherCheck
      - name: Run Unit Tests
        shell: powershell
        run: Invoke-Pester -Path tests/unit/windows -OutputFormat NUnitXml -OutputFile test-results.xml
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: windows-unit-tests
          path: test-results.xml

  unit-tests-ubuntu:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Bats
        run: npm install -g bats
      - name: Run Unit Tests
        run: bats tests/unit/ubuntu

  unit-tests-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Bats
        run: brew install bats-core
      - name: Run Unit Tests
        run: bats tests/unit/macos

  integration-tests-ubuntu:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Integration Tests
        run: bats tests/integration/ubuntu

  e2e-tests-ubuntu:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Docker Test Image
        run: docker build -f tests/e2e/ubuntu/Dockerfile.test -t setup-test .
      - name: Run E2E Tests
        run: docker run setup-test

  e2e-tests-macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run E2E Tests
        run: ./tests/e2e/macos/run-e2e.sh

  smoke-tests:
    needs: [e2e-tests-ubuntu, e2e-tests-macos]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Full Installation
        run: ./setup-dev-environment-ubuntu.sh --user
      - name: Run Smoke Tests
        run: ./tests/smoke/verify-installation.sh
```

---

## Directory Structure

```
setup-dev-environment/
├── setup-dev-environment.ps1
├── setup-dev-environment-ubuntu.sh
├── setup-dev-environment-macos.sh
├── setup-dev-environment-windows.config
├── setup-dev-environment-ubuntu.config
├── setup-dev-environment-macos.config
├── README.md
├── LICENSE
├── .gitignore
├── .github/
│   └── workflows/
│       └── test.yml                    # CI/CD pipeline
├── tests/
│   ├── unit/
│   │   ├── windows/
│   │   │   ├── ConfigParser.Tests.ps1
│   │   │   ├── HelperFunctions.Tests.ps1
│   │   │   └── PathResolution.Tests.ps1
│   │   ├── ubuntu/
│   │   │   ├── config_parser.bats
│   │   │   ├── helper_functions.bats
│   │   │   └── installation_logic.bats
│   │   └── macos/
│   │       ├── config_parser.bats
│   │       ├── helper_functions.bats
│   │       └── homebrew_helpers.bats
│   ├── integration/
│   │   ├── windows/
│   │   │   └── Installation.Tests.ps1
│   │   ├── ubuntu/
│   │   │   └── installation.bats
│   │   └── macos/
│   │       └── installation.bats
│   ├── e2e/
│   │   ├── windows/
│   │   │   ├── sandbox.wsb
│   │   │   └── run-e2e.ps1
│   │   ├── ubuntu/
│   │   │   ├── Dockerfile.test
│   │   │   ├── run-e2e.sh
│   │   │   └── full-install.bats
│   │   └── macos/
│   │       ├── run-e2e.sh
│   │       └── full-install.bats
│   ├── smoke/
│   │   └── verify-installation.sh      # Cross-platform
│   └── fixtures/
│       ├── valid-config.config
│       ├── invalid-config.config
│       └── minimal-config.config
└── future-features/
    └── TESTING_PROPOSAL.md             # This document
```

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)
- [ ] Set up test directory structure
- [ ] Install Pester (Windows)
- [ ] Install Bats (Ubuntu/macOS)
- [ ] Create first unit test for config parsing
- [ ] Add `--dry-run` flag to all scripts

### Phase 2: Unit Tests (Week 3-4)
- [ ] Write unit tests for all helper functions
- [ ] Test config parsing edge cases
- [ ] Test path resolution logic
- [ ] Test validation functions
- [ ] Achieve 80%+ coverage of pure functions

### Phase 3: Integration Tests (Week 5-6)
- [ ] Mock system commands (scoop, apt, brew)
- [ ] Test installation workflows
- [ ] Test error handling
- [ ] Test flag combinations

### Phase 4: E2E & CI/CD (Week 7-8)
- [ ] Create Docker test images
- [ ] Set up Windows Sandbox tests
- [ ] Configure GitHub Actions
- [ ] Add smoke tests
- [ ] Test on all platforms

### Phase 5: Refinement (Week 9-10)
- [ ] Improve test coverage
- [ ] Optimize test speed
- [ ] Add test documentation
- [ ] Review and refactor

---

## Success Criteria

1. **Coverage**: 80%+ unit test coverage of testable code
2. **Speed**: Unit tests run in < 30 seconds
3. **Reliability**: E2E tests pass 95%+ of the time
4. **CI/CD**: All tests run automatically on PR
5. **Documentation**: Clear instructions for running tests locally

---

## Estimated Effort

- **Minimal Refactoring + Basic Tests**: ~40 hours
- **Moderate Refactoring + Comprehensive Tests**: ~80 hours
- **Full Refactoring + Enterprise-Grade Tests**: ~120 hours

---

## Recommendation

**Start with Phase 1-2 (Minimal Refactoring)**
- Low risk, high value
- Quick wins with unit tests
- Foundation for future improvements
- ~20-30 hours of work

Then evaluate if deeper refactoring is needed based on test coverage gaps.

---

## Questions & Next Steps

1. Which testing approach do you prefer?
   - [ ] Minimal refactoring (recommended)
   - [ ] Moderate refactoring
   - [ ] Full refactoring

2. What's the priority?
   - [ ] Unit tests first
   - [ ] E2E tests first
   - [ ] CI/CD first

3. Timeline?
   - [ ] Implement immediately
   - [ ] Plan for future release
   - [ ] Incremental rollout

---

**Document Version**: 1.0
**Last Updated**: 2024-11-11
**Status**: Proposal
**Next Review**: TBD
