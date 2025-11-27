# 🚀 Cross-Platform Development Environment Setup

[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Ubuntu%20%7C%20macOS-blue)]()
[![License](https://img.shields.io/badge/License-MIT-green)]()

Automated development environment setup scripts for Windows, Ubuntu/Debian, and macOS. Configure once, install everywhere!

## ✨ Features

- **Cross-Platform**: Single config format for Windows, Ubuntu, and macOS
- **Configurable**: Edit simple config files to choose what to install
- **Modern Stack**: Official NVM, Yarn via Corepack, pnpm, and latest tools
- **Smart Installation**: Checks for existing tools, skips if already installed
- **User-Friendly**: Color-coded output, progress tracking, helpful error messages
- **Comprehensive**: Supports 50+ development tools, languages, and utilities

## 📋 Supported Tools

<details>
<summary><b>Core Development Tools</b></summary>

- Git (with Git Bash on Windows)
- GitHub CLI (gh)
- curl, wget
- jq, yq
- ripgrep, fd, fzf, bat
- tree, htop

</details>

<details>
<summary><b>Programming Languages</b></summary>

- **Node.js**: Official NVM (installs LTS automatically)
- **Python**: With pip and common packages
- **Go**: Latest stable version
- **Rust**: Via rustup
- **Java**: OpenJDK with Maven/Gradle
- **Ruby**, **PHP**, **.NET**: Optional

</details>

<details>
<summary><b>Package Managers</b></summary>

- **Yarn**: Via Corepack or official installer
- **pnpm**: Via official installer
- **npm**: Global packages (TypeScript, ESLint, Prettier)

</details>

<details>
<summary><b>Databases</b></summary>

- SQLite, PostgreSQL, MySQL
- MongoDB, Redis

</details>

<details>
<summary><b>Containers & Cloud</b></summary>

- Docker, Docker Compose
- Kubernetes (kubectl, helm, k9s, kind, minikube)
- ArgoCD CLI
- AWS CLI, Azure CLI, Google Cloud SDK
- Terraform, Packer, Vault, Consul

</details>

<details>
<summary><b>Editors & IDEs</b></summary>

- Visual Studio Code
- Neovim, Vim, Nano
- JetBrains Toolbox
- Sublime Text

</details>

<details>
<summary><b>Terminal Enhancements</b></summary>

- Starship (cross-shell prompt)
- Zoxide (smart cd)
- tldr (simplified man pages)
- tmux, screen

</details>

<details>
<summary><b>Testing & Security</b></summary>

- Postman, Insomnia, httpie
- nmap, openssl, mkcert

</details>

## 🎯 Quick Start

### Windows

1. Download the repository
2. Edit `setup-dev-environment-windows.config`
3. Run PowerShell as **regular user** (NOT admin):
   ```powershell
   .\setup-dev-environment-windows.ps1 -ToolsUserRights
   ```
4. Optionally, run as **administrator** for system tools:
   ```powershell
   .\setup-dev-environment-windows.ps1 -ToolsAdminRights
   ```

### Ubuntu/Debian

1. Clone the repository
2. Edit `setup-dev-environment-ubuntu.config`
3. Make scripts executable:
   ```bash
   chmod +x setup-dev-environment-ubuntu.sh
   ```
4. Run for user-level tools:
   ```bash
   ./setup-dev-environment-ubuntu.sh --user
   ```
5. Optionally, run with sudo for system packages:
   ```bash
   sudo ./setup-dev-environment-ubuntu.sh --admin
   ```

### macOS

1. Clone the repository
2. Edit `setup-dev-environment-macos.config`
3. Make scripts executable:
   ```bash
   chmod +x setup-dev-environment-macos.sh
   ```
4. Run for CLI tools:
   ```bash
   ./setup-dev-environment-macos.sh --user
   ```
5. Run for GUI applications:
   ```bash
   ./setup-dev-environment-macos.sh --apps
   ```

## 📝 Configuration

Each platform has its own config file:

- `setup-dev-environment-windows.config` - Windows configuration
- `setup-dev-environment-ubuntu.config` - Ubuntu/Debian configuration
- `setup-dev-environment-macos.config` - macOS configuration

### Config File Format

```ini
[General]
MinimalInstall=false

[UserLevel.CoreTools]
git=true
curl=true
wget=true

[UserLevel.Languages.NodeJS]
nvm=true                        # Install NVM (installs Node.js LTS automatically)
yarn=true                       # Install Yarn via Corepack
pnpm=true                       # Install pnpm via official installer
npm-global-packages=true        # Install TypeScript, ESLint, Prettier

[UserLevel.Languages.Python]
install=true
pip-packages=true               # Install pylint, black, flake8, mypy, pytest
```

Simply set values to `true` or `false` to enable/disable specific tools.

## 📖 Getting Help

### Windows PowerShell Help

The Windows script includes comprehensive built-in help documentation using PowerShell's native help system:

```powershell
# Display basic help
Get-Help .\setup-dev-environment-windows.ps1

# Display detailed help
Get-Help .\setup-dev-environment-windows.ps1 -Detailed

# Display full help with examples
Get-Help .\setup-dev-environment-windows.ps1 -Full

# Display only examples
Get-Help .\setup-dev-environment-windows.ps1 -Examples

# Run script without parameters to see usage
.\setup-dev-environment-windows.ps1
```

The help system includes:
- **Synopsis**: Brief description of what the script does
- **Description**: Detailed explanation of functionality
- **Parameters**: Complete parameter documentation with descriptions
- **Examples**: Real-world usage examples for common scenarios
- **Notes**: Important information about prerequisites and workflow
- **Links**: Related resources and documentation

### Quick Help (All Platforms)

Running any script without parameters shows a helpful usage guide:

**Windows:**
```powershell
.\setup-dev-environment-windows.ps1
# Shows comprehensive help with parameters, examples, and workflow
```

**Ubuntu/Debian:**
```bash
./setup-dev-environment-ubuntu.sh --help
# Shows usage information and available options
```

**macOS:**
```bash
./setup-dev-environment-macos.sh --help
# Shows usage information and available options
```

## 🔧 Advanced Usage

### Force Install Specific Tools

Install only specific tools, ignoring the config file:

**Windows:**
```powershell
.\setup-dev-environment-windows.ps1 -ToolsUserRights -ForceInstall git,curl,docker
```

**Ubuntu:**
```bash
./setup-dev-environment-ubuntu.sh --user --force-install git,curl,docker
```

**macOS:**
```bash
./setup-dev-environment-macos.sh --user --force-install git,curl,docker
```

### Custom Config File

**Windows:**
```powershell
.\setup-dev-environment-windows.ps1 -ToolsUserRights -ConfigFile "path\to\custom.config"
```

**Ubuntu:**
```bash
./setup-dev-environment-ubuntu.sh --user --config /path/to/custom.config
```

**macOS:**
```bash
./setup-dev-environment-macos.sh --user --config /path/to/custom.config
```

## 🎨 Screenshots

### Windows Installation
```
╔════════════════════════════════════════════════════════════════╗
║     🚀 DEVELOPMENT ENVIRONMENT INSTALLER 🚀                   ║
║     Mode: USER-LEVEL (No Admin)                                ║
╚════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════
 🔧 Core Development Tools
═══════════════════════════════════════════════════════════════
  ✓ Git for Windows installed
  ✓ GitHub CLI installed
  ✓ curl installed

═══════════════════════════════════════════════════════════════
 💻 Programming Languages
═══════════════════════════════════════════════════════════════
📍 Node.js (via NVM)
  → Installing NVM for Windows...
  ✓ NVM installed successfully
  ✓ Node.js v20.11.0 installed
```

## 🌟 Key Features by Platform

### Windows (PowerShell)
- **Scoop**: User-level package manager (no admin required)
- **Winget**: System-level applications
- **NVM for Windows**: Official installer with LTS auto-install
- **Git for Windows**: Includes Git Bash for Claude Code compatibility

### Ubuntu/Debian (Bash)
- **apt**: System package manager
- **snap**: GUI applications
- **Official NVM**: Bash-based Node.js version manager
- **Native Unix tools**: No need for Git Bash

### macOS (Bash)
- **Homebrew**: Primary package manager
- **Homebrew Casks**: GUI applications
- **Official NVM**: Same as Ubuntu
- **Xcode CLI Tools**: Auto-installed when needed

## 🔄 Node.js Installation Strategy

All platforms use the **same modern approach**:

1. **NVM (Node Version Manager)**: Official installer
2. **Node.js LTS**: Automatically installed via `nvm install --lts`
3. **Yarn**: Installed via Corepack (built into Node.js 16.10+) or official installer
4. **pnpm**: Installed via official installer script
5. **Global packages**: TypeScript, ts-node, ESLint, Prettier (optional)

This ensures consistency across all platforms and avoids platform-specific Node.js quirks.

## 📦 What Gets Installed Where

### User-Level (No Admin)
- CLI tools (git, curl, wget, etc.)
- Programming languages (via version managers)
- Development tools (vim, neovim, etc.)
- Terminal enhancements (starship, zoxide)
- Cloud CLIs (AWS, Azure, Terraform)

### Admin-Level (Requires Admin/Sudo)
- System packages (Windows: via Winget, Linux: via apt)
- GUI applications (Docker Desktop, browsers, etc.)
- System fonts
- Database servers

## 🛠️ Troubleshooting

### Windows

**Issue**: "Running scripts is disabled"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Issue**: "Scoop must be installed as regular user"
- Close admin PowerShell
- Open regular PowerShell
- Run script again

### Ubuntu/Debian

**Issue**: "Permission denied"
```bash
chmod +x setup-dev-environment.sh
```

**Issue**: Node/npm not found after NVM install
```bash
source ~/.bashrc
nvm use --lts
```

### macOS

**Issue**: "Xcode Command Line Tools required"
- The script will prompt you to install
- Complete the installation dialog
- Re-run the script

**Issue**: Homebrew not in PATH (Apple Silicon)
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Adding a New Tool

1. Add the tool to the appropriate config file section
2. Add installation logic to the corresponding script
3. Test on the target platform
4. Update README.md

## 📄 License

MIT License - feel free to use this for your own projects!

## 🙏 Acknowledgments

- [Scoop](https://scoop.sh/) - Windows package manager
- [Homebrew](https://brew.sh/) - macOS package manager
- [NVM](https://github.com/nvm-sh/nvm) - Node Version Manager
- [NVM for Windows](https://github.com/coreybutler/nvm-windows)
- All the amazing open-source tools this script helps install

## 📚 Related Resources

- [Claude Code Documentation](https://docs.anthropic.com/claude/docs/claude-code)
- [Scoop Documentation](https://github.com/ScoopInstaller/Scoop/wiki)
- [Homebrew Documentation](https://docs.brew.sh/)
- [NVM Documentation](https://github.com/nvm-sh/nvm#readme)

## 🔗 Useful Links

- [Report an Issue](https://github.com/kartalbas/setup-dev-environment/issues)
- [Request a Feature](https://github.com/kartalbas/setup-dev-environment/issues/new)

---

**Made with ❤️ for developers who want consistent environments across platforms**
