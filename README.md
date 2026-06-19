# Claude Code CLI - Team Setup (Windows)

One-command installer for Claude Code CLI and all its dependencies on Windows 10/11.

## Quick Start (Recommended)

1. Open **PowerShell as Administrator** (right-click > "Run as administrator")
2. Paste the following command and press Enter:

```powershell
irm https://raw.githubusercontent.com/IAMASIN7/cc-setup-CG/main/Install.ps1 | iex
```

3. Wait for the installer to finish - everything installs automatically and verifies itself when done
4. Type **`cc`** in the new terminal that opens to launch Claude Code

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

- **`cc`** shortcut - launches Claude Code in the current folder, from **any shell** (PowerShell, cmd, Git Bash, the VS Code terminal). Installed as a real command (`cc.cmd`) on your PATH, plus a PowerShell profile function, so it works no matter where you type it.
- **`ccb`** shortcut - launches Claude Code in bypass mode (auto-approves all tool use)
- **Auto mode ON by default** - `permissions.defaultMode` is set to `auto` in `~/.claude/settings.json`, so Claude starts in auto mode (auto-approves with background safety checks) on every launch
- **xhigh reasoning by default** - `effortLevel` is set to `xhigh` in `~/.claude/settings.json` (the deepest reasoning level that can be made permanent - see [Ultracode](#ultracode) below)
- `~/.claude.json` - pre-configured with team plugins and settings
- Execution policy set to `RemoteSigned` so PowerShell profiles load correctly

## Ultracode

You asked for **ultracode** on by default. Important caveat: full ultracode (deepest reasoning **plus** auto-running multi-agent workflows) **cannot** be set as a permanent default - there is no settings key, environment variable, or launch flag that accepts `ultracode`. It is session-scoped only.

This setup gets you as close as possible automatically:

- The **reasoning half** of ultracode is made permanent via `effortLevel: "xhigh"` (the highest persistent level).

To turn on **full ultracode** for an entire session, type this once inside Claude Code:

```text
/effort ultracode
```

It stays on for the rest of that session (it resets when you start a new one). Alternatively, prefix a single prompt with the word `ultracode` to get a workflow for just that one task.

> Tip: `xhigh` / ultracode use a lot more tokens and run slower. If you ever want lighter sessions, run `/effort high` (or `medium`), or edit `effortLevel` in `~/.claude/settings.json`.

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
Close **all** terminal windows and open a brand-new one - a fresh terminal is needed to pick up the updated PATH. `cc` is installed as `cc.cmd` in `%USERPROFILE%\.local\bin` (which the installer adds to your PATH), so it works in PowerShell, cmd, and the VS Code terminal.

If it still isn't found, confirm the shim and PATH:

```powershell
Test-Path "$env:USERPROFILE\.local\bin\cc.cmd"    # should print True
$env:Path -split ';' | Select-String '.local\\bin' # should list the folder
```

If the shim exists but isn't found, re-run the installer (it's safe to run again) or sign out and back in to refresh PATH system-wide.

### Claude CLI not found after install
Run manually:
```powershell
irm https://claude.ai/install.ps1 | iex
```

### Corporate proxy / firewall issues
Ask IT to allowlist: `claude.ai`, `cdn.anthropic.com`, `winget.azureedge.net`

## Re-running

Safe to run at any time. Already-installed tools are detected and skipped.
