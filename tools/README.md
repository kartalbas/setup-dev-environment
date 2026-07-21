# Custom Tools Collection

This directory contains custom PowerShell tools that are automatically deployed during the environment setup.

## How It Works

When you run `setup-dev-environment-windows.ps1`, all `.ps1` files in this directory are:

1. **Copied** to `{InstallPath}\tools\` (e.g., `D:\bin\scoop\tools\`)
2. **Added to PATH** automatically
3. **Available globally** after installation

## Included Tools

- **winget-manager.ps1** - Winget package manager utilities
- **path-manager.ps1** - PATH environment variable management utilities

## Adding Your Own Tools

Simply drop any PowerShell script (`.ps1`) into this directory and it will be automatically deployed on next installation.

## Usage

After installation, you can run tools from anywhere:

```powershell
# Run from anywhere
pwsh D:\bin\scoop\tools\winget-manager.ps1
pwsh D:\bin\scoop\tools\path-manager.ps1
```

## Location

After installation, tools are located at:
- Install Path: `{config.General.InstallPath}\tools\`
- Default: `D:\bin\scoop\tools\`
