# Claude Code CLI - Team Setup (Windows)

One-command installer for Claude Code CLI and all its dependencies on Windows 10/11.

## Quick Start (Recommended)

Open **PowerShell** and paste:

```powershell
irm https://raw.githubusercontent.com/IAMASIN7/cc-setup-CG/main/Install.ps1 | iex
```

That's it. One UAC prompt, then everything installs automatically and verifies itself when done.

## What Gets Installed

| Tool              | Purpose                           |
|-------------------|-----------------------------------|
| PowerShell 7      | Modern shell                      |
| Git               | Version control                   |
| Node.js (LTS)     | JavaScript runtime                |
| Python 3.13       | Python runtime                    |
| GitHub CLI (`gh`) | GitHub operations from terminal   |
| uv                | Fast Python package manager       |
| Windows Terminal   | Modern terminal with tabs         |
| VS Code           | Code editor with Claude extension |
| Claude Code CLI   | AI coding assistant               |

## What Gets Configured

- **`cc`** shortcut - launches Claude Code
- **`ccb`** shortcut - launches Claude Code in bypass mode (auto-approves tool use)
- `~/.claude.json` - pre-configured with team plugins and settings
- Execution policy set to `RemoteSigned` so PowerShell profiles load correctly

## How It Works

1. **One UAC prompt** at the start - the installer elevates once, then all installs run silently
2. **Pre-flight checks** - validates internet, winget, and admin before starting
3. **Installs tools** via winget (skips anything already installed)
4. **Configures shortcuts** in your PowerShell profile
5. **Opens a fresh terminal** with a verification check that everything works
6. **Type `cc`** and sign in via browser (first time only)

## Manual Setup (Alternative)

If the one-liner doesn't work (corporate proxy, no internet, etc.):

1. Download this repository as a ZIP and extract it
2. Double-click **`Run-Setup.bat`**
3. Click **Yes** on the UAC prompt
4. Wait for the installer to finish
5. Type `cc` in the new terminal that opens

## Verifying Installation

Open PowerShell and run:

```powershell
.\Verify-Install.ps1
```

## Troubleshooting

### "winget not found"
Install **App Installer** from the Microsoft Store, then try again.

### "cc is not recognized"
Close all terminal windows and open a new one. The shortcuts need a fresh terminal to load the PowerShell profile.

### Claude CLI not found after install
Run manually:
```powershell
irm https://claude.ai/install.ps1 | iex
```

### Corporate proxy / firewall issues
Ask IT to allowlist: `claude.ai`, `cdn.anthropic.com`, `winget.azureedge.net`

## Re-running

Safe to run at any time. Already-installed tools are detected and skipped.
