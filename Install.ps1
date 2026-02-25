# ============================================================
#  Claude Code CLI - One-Line Installer (Windows)
#  Usage:  irm https://raw.githubusercontent.com/IAMASIN7/cc-setup-CG/main/Install.ps1 | iex
#
#  Single self-contained script: installs all prerequisites,
#  configures shortcuts and plugins, then verifies everything.
# ============================================================

# --- Handle irm | iex: save to temp file so we can self-elevate ---
if (-not $PSCommandPath) {
    $tempScript = Join-Path $env:TEMP "claude-install-$(Get-Random).ps1"
    # Re-download the script to a file (we can't capture piped input reliably)
    $scriptUrl = "https://raw.githubusercontent.com/IAMASIN7/cc-setup-CG/main/Install.ps1"
    try {
        Invoke-WebRequest -Uri $scriptUrl -OutFile $tempScript -UseBasicParsing
    } catch {
        Write-Host "  [ERROR] Could not download installer: $_" -ForegroundColor Red
        exit 1
    }
    $shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
    & $shell -ExecutionPolicy Bypass -NoProfile -File $tempScript
    Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    return
}

# --- Self-elevate past Constrained Language Mode ----
if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    exit
}

# --- Self-elevate to Administrator (single UAC prompt) --------
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host ""
    Write-Host "  This installer needs Administrator privileges for winget installs." -ForegroundColor Yellow
    Write-Host "  You will see ONE UAC prompt - click Yes to continue." -ForegroundColor Yellow
    Write-Host ""
    $argList = "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    try {
        if (Get-Command pwsh -ErrorAction SilentlyContinue) {
            Start-Process pwsh.exe -Verb RunAs -ArgumentList $argList -ErrorAction Stop
        } else {
            Start-Process powershell.exe -Verb RunAs -ArgumentList $argList -ErrorAction Stop
        }
    } catch {
        Write-Host "  [ERROR] Could not elevate to Administrator." -ForegroundColor Red
        Write-Host "  Please right-click PowerShell and choose 'Run as administrator'." -ForegroundColor Red
        Write-Host ""
        pause
        exit 1
    }
    exit 0
}

# ==============================================================
#  Helpers
# ==============================================================

function Write-Banner {
    Write-Host ""
    Write-Host "  ====================================================" -ForegroundColor Cyan
    Write-Host "   Claude Code CLI - Full Setup (Windows / winget)" -ForegroundColor Cyan
    Write-Host "  ====================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Number, [string]$Total, [string]$Message)
    Write-Host ""
    Write-Host "  [$Number/$Total] $Message" -ForegroundColor Yellow
}

function Write-Ok {
    param([string]$Message)
    Write-Host "        [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "        [--] $Message" -ForegroundColor DarkGray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "        [!!] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "        $Message" -ForegroundColor White
}

function Refresh-Path {
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

function Test-CommandExists {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-WithWinget {
    param(
        [string]$DisplayName,
        [string]$TestCommand,
        [string]$WingetId
    )
    # 1. Quick check: is the command already on PATH?
    if (Test-CommandExists $TestCommand) {
        $ver = $null
        try { $ver = (& $TestCommand --version 2>$null) } catch {}
        if (-not $ver) { try { $ver = (& $TestCommand -v 2>$null) } catch {} }
        Write-Skip "$DisplayName already installed ($ver)"
        return $true
    }

    # 2. Deeper check: is the package registered in winget even if command isn't on PATH?
    #    This prevents winget from re-running the installer and popping GUI dialogs.
    winget list --id $WingetId --exact --accept-source-agreements 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Skip "$DisplayName already installed (detected by winget)"
        return $true
    }

    Write-Info "Installing $DisplayName via winget..."
    try {
        winget install --id $WingetId --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>&1 | Out-Null
        Refresh-Path
        if (Test-CommandExists $TestCommand) {
            Write-Ok "$DisplayName installed"
            return $true
        } else {
            Write-Warn "$DisplayName installed but not yet on PATH - will be available after terminal restart"
            return $true
        }
    } catch {
        Write-Warn "Failed to install $DisplayName - you may need to install it manually"
        return $false
    }
}

# ==============================================================
#  Main
# ==============================================================

Write-Banner

$totalSteps = 13

# ------------------------------------------------------------------
#  Step 1 - Pre-flight checks (admin, internet, winget)
# ------------------------------------------------------------------
Write-Step "1" $totalSteps "Running pre-flight checks..."

# 1a. Confirm admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Ok "Running as Administrator"
} else {
    Write-Warn "Not running as Administrator - winget installs may prompt individually"
}

# 1b. Internet connectivity
$internetOk = $false
try {
    $null = Invoke-WebRequest -Uri "https://www.microsoft.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    $internetOk = $true
} catch {
    try {
        $null = [System.Net.Dns]::GetHostAddresses("claude.ai")
        $internetOk = $true
    } catch {}
}

if ($internetOk) {
    Write-Ok "Internet connection available"
} else {
    Write-Warn "No internet connection detected!"
    Write-Info "This installer requires internet to download packages."
    Write-Info "Please check your network connection and try again."
    Write-Host ""
    pause
    exit 1
}

# 1c. winget
if (Test-CommandExists "winget") {
    Write-Ok "winget found"
} else {
    Write-Warn "winget not found. It ships with Windows 11 and most Windows 10 builds."
    Write-Warn "Install it from the Microsoft Store (search 'App Installer') then re-run."
    Write-Host ""
    pause
    exit 1
}

# ------------------------------------------------------------------
#  Step 2 - Install PowerShell 7+
# ------------------------------------------------------------------
Write-Step "2" $totalSteps "Checking PowerShell 7..."

if (Test-CommandExists "pwsh") {
    $pwshVer = (pwsh --version 2>$null)
    Write-Skip "PowerShell 7 already installed ($pwshVer)"
} else {
    Write-Info "Installing PowerShell 7..."
    winget install --id Microsoft.PowerShell --accept-source-agreements --accept-package-agreements --silent --disable-interactivity 2>&1 | Out-Null
    Refresh-Path
    if (Test-CommandExists "pwsh") {
        Write-Ok "PowerShell 7 installed"
    } else {
        Write-Warn "PowerShell 7 installed but not on PATH yet - restart your terminal after setup"
    }
}

# ------------------------------------------------------------------
#  Step 3 - Install Git
# ------------------------------------------------------------------
Write-Step "3" $totalSteps "Checking Git..."
Install-WithWinget -DisplayName "Git" -TestCommand "git" -WingetId "Git.Git" | Out-Null

# Claude Code requires CLAUDE_CODE_GIT_BASH_PATH pointing to bash.exe.
# Find Git's bash.exe and set the env var (also ensure usr\bin is on PATH).
Refresh-Path
$gitBashLocations = @(
    "$env:ProgramFiles\Git\bin\bash.exe",
    "${env:ProgramFiles(x86)}\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
    "$env:ProgramFiles\Git\usr\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\usr\bin\bash.exe"
)
$bashExe = $null
foreach ($candidate in $gitBashLocations) {
    if (Test-Path $candidate) { $bashExe = $candidate; break }
}
if ($bashExe) {
    [System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_GIT_BASH_PATH", $bashExe, "User")
    $env:CLAUDE_CODE_GIT_BASH_PATH = $bashExe
    Write-Ok "CLAUDE_CODE_GIT_BASH_PATH = $bashExe"

    # Also ensure the directory is on PATH for other tools
    $bashDir = Split-Path $bashExe -Parent
    $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentUserPath -notlike "*$bashDir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$currentUserPath;$bashDir", "User")
    }
    if ($env:PATH -notlike "*$bashDir*") { $env:PATH = "$env:PATH;$bashDir" }
} else {
    Write-Warn "bash.exe not found - Claude Code needs it. Install Git with 'Add to PATH' option."
}

# ------------------------------------------------------------------
#  Step 4 - Install Node.js (LTS) + npm
# ------------------------------------------------------------------
Write-Step "4" $totalSteps "Checking Node.js + npm..."
Install-WithWinget -DisplayName "Node.js LTS" -TestCommand "node" -WingetId "OpenJS.NodeJS.LTS" | Out-Null

# ------------------------------------------------------------------
#  Step 5 - Install Python
# ------------------------------------------------------------------
Write-Step "5" $totalSteps "Checking Python..."
Install-WithWinget -DisplayName "Python" -TestCommand "python" -WingetId "Python.Python.3.13" | Out-Null

# ------------------------------------------------------------------
#  Step 6 - Install GitHub CLI
# ------------------------------------------------------------------
Write-Step "6" $totalSteps "Checking GitHub CLI..."
Install-WithWinget -DisplayName "GitHub CLI" -TestCommand "gh" -WingetId "GitHub.cli" | Out-Null

# ------------------------------------------------------------------
#  Step 7 - Install uv (fast Python package manager)
# ------------------------------------------------------------------
Write-Step "7" $totalSteps "Checking uv (Python package manager)..."
Install-WithWinget -DisplayName "uv" -TestCommand "uv" -WingetId "astral-sh.uv" | Out-Null

# ------------------------------------------------------------------
#  Step 8 - Install Windows Terminal
# ------------------------------------------------------------------
Write-Step "8" $totalSteps "Checking Windows Terminal..."
Install-WithWinget -DisplayName "Windows Terminal" -TestCommand "wt" -WingetId "Microsoft.WindowsTerminal" | Out-Null

# ------------------------------------------------------------------
#  Step 9 - Install VS Code
# ------------------------------------------------------------------
Write-Step "9" $totalSteps "Checking Visual Studio Code..."
Install-WithWinget -DisplayName "VS Code" -TestCommand "code" -WingetId "Microsoft.VisualStudioCode" | Out-Null

# ------------------------------------------------------------------
#  Step 10 - Ensure ~/.local/bin is on PATH (before installing Claude)
# ------------------------------------------------------------------
Write-Step "10" $totalSteps "Preparing PATH for Claude CLI..."

$claudeBin = "$env:USERPROFILE\.local\bin"
$currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($currentUserPath -notlike "*$claudeBin*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$currentUserPath;$claudeBin", "User")
    Write-Ok "Added $claudeBin to user PATH"
} else {
    Write-Skip "$claudeBin already on PATH"
}
if ($env:PATH -notlike "*$claudeBin*") {
    $env:PATH = "$env:PATH;$claudeBin"
}

# ------------------------------------------------------------------
#  Step 11 - Install Claude Code CLI (official standalone installer)
# ------------------------------------------------------------------
Write-Step "11" $totalSteps "Installing Claude Code CLI (official installer)..."

Refresh-Path

if (Test-CommandExists "claude") {
    $claudeVer = $null
    try { $claudeVer = (claude --version 2>$null) } catch {}
    Write-Skip "Claude Code CLI already installed ($claudeVer)"
} else {
    Write-Info "Downloading and running official installer from claude.ai..."
    Write-Info "This installs the native binary to $claudeBin"
    try {
        $installScript = Invoke-RestMethod -Uri "https://claude.ai/install.ps1" -UseBasicParsing
        & ([scriptblock]::Create($installScript))
        Refresh-Path
        if (Test-CommandExists "claude") {
            Write-Ok "Claude Code CLI installed"
        } else {
            if (Test-Path "$claudeBin\claude.exe") {
                Write-Ok "Claude Code CLI installed (restart terminal to use)"
            } else {
                Write-Warn "Installer ran but 'claude' not detected - try restarting your terminal"
                Write-Info "If it still doesn't work, run manually:  irm https://claude.ai/install.ps1 | iex"
            }
        }
    } catch {
        Write-Warn "Could not download the official installer."
        Write-Info "Run this manually in PowerShell after setup:"
        Write-Info "  irm https://claude.ai/install.ps1 | iex"
    }
}

# ------------------------------------------------------------------
#  Step 12 - Environment variables + .claude.json config
# ------------------------------------------------------------------
Write-Step "12" $totalSteps "Setting environment variables + config file..."

[System.Environment]::SetEnvironmentVariable("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS", "1", "User")
Write-Ok "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = 1"

$claudeConfig = @{
    env = @{
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
    }
    enabledPlugins = @{
        "rust-analyzer-lsp@claude-plugins-official" = $true
        "frontend-design@claude-plugins-official"   = $true
        "context7@claude-plugins-official"          = $true
        "code-review@claude-plugins-official"       = $true
        "code-simplifier@claude-plugins-official"   = $true
        "supabase@claude-plugins-official"          = $true
        "stripe@claude-plugins-official"            = $true
        "superpowers@claude-plugins-official"       = $true
    }
    autoUpdatesChannel                = "latest"
    skipDangerousModePermissionPrompt = $true
} | ConvertTo-Json -Depth 5

$configPath = "$env:USERPROFILE\.claude.json"
$claudeConfig | Set-Content -Path $configPath -Encoding UTF8
Write-Ok "$configPath written"

# ------------------------------------------------------------------
#  Step 13 - PowerShell profile shortcuts (cc / ccb)
# ------------------------------------------------------------------
Write-Step "13" $totalSteps "Setting up 'cc' and 'ccb' shortcuts..."

$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq "Restricted" -or $currentPolicy -eq "Undefined") {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Ok "Execution policy set to RemoteSigned (CurrentUser)"
} else {
    Write-Skip "Execution policy already allows scripts ($currentPolicy)"
}

$profilesToUpdate = @()
$profilesToUpdate += $PROFILE

if (Test-CommandExists "pwsh") {
    try {
        $ps7Profile = pwsh -NoProfile -Command '$PROFILE' 2>$null
        if ($ps7Profile) { $profilesToUpdate += $ps7Profile }
    } catch {}
}

# Use the real Documents folder (respects OneDrive folder redirection)
$realDocs = [Environment]::GetFolderPath('MyDocuments')
$ps7ProfileFallback = Join-Path $realDocs "PowerShell\Microsoft.PowerShell_profile.ps1"
$ps51Profile        = Join-Path $realDocs "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if ($profilesToUpdate -notcontains $ps7ProfileFallback) { $profilesToUpdate += $ps7ProfileFallback }
if ($profilesToUpdate -notcontains $ps51Profile)        { $profilesToUpdate += $ps51Profile }
$profilesToUpdate = $profilesToUpdate | Sort-Object -Unique

$claudeFunction = @"

# --- Claude CLI Shortcuts ------------------------------------
function cc {
    & claude @args
}
function ccb {
    & claude --dangerously-skip-permissions @args
}
# -------------------------------------------------------------
"@

foreach ($prof in $profilesToUpdate) {
    $profDir = Split-Path $prof -Parent
    if (-not (Test-Path $profDir)) {
        New-Item -ItemType Directory -Path $profDir -Force | Out-Null
    }
    if (-not (Test-Path $prof)) {
        New-Item -ItemType File -Path $prof -Force | Out-Null
    }
    $content = Get-Content $prof -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch "Claude CLI Shortcuts") {
        Add-Content -Path $prof -Value $claudeFunction
        Write-Ok "$prof updated"
    } else {
        Write-Skip "$prof already configured"
    }
}

# ==============================================================
#  Verify Installation (inline)
# ==============================================================
Refresh-Path

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "   Installation Complete - Verifying..." -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

$tools = @(
    @{ Name = "PowerShell 7"; Cmd = "pwsh";   Flag = "--version" },
    @{ Name = "Git";          Cmd = "git";     Flag = "--version" },
    @{ Name = "Node.js";      Cmd = "node";    Flag = "--version" },
    @{ Name = "npm";          Cmd = "npm";     Flag = "--version" },
    @{ Name = "Python";       Cmd = "python";  Flag = "--version" },
    @{ Name = "GitHub CLI";   Cmd = "gh";      Flag = "--version" },
    @{ Name = "uv";           Cmd = "uv";      Flag = "--version" },
    @{ Name = "VS Code";      Cmd = "code";    Flag = "--version" },
    @{ Name = "Claude CLI";   Cmd = "claude";  Flag = "--version" }
)

foreach ($tool in $tools) {
    $exists = $null -ne (Get-Command $tool.Cmd -ErrorAction SilentlyContinue)
    if ($exists) {
        $ver = $null
        try { $ver = (& $tool.Cmd $tool.Flag 2>$null) } catch {}
        Write-Host ("  [PASS]  {0,-16} {1}" -f $tool.Name, $ver) -ForegroundColor Green
    } else {
        Write-Host ("  [FAIL]  {0,-16} not found on PATH" -f $tool.Name) -ForegroundColor Red
        $allPassed = $false
    }
}

Write-Host ""
if (Test-Path "$env:USERPROFILE\.claude.json") {
    Write-Host "  [PASS]  Config file ~/.claude.json exists" -ForegroundColor Green
} else {
    Write-Host "  [FAIL]  Config file ~/.claude.json not found" -ForegroundColor Red
    $allPassed = $false
}

Write-Host ""
if ($allPassed) {
    Write-Host "  ====================================================" -ForegroundColor Green
    Write-Host "   ALL CHECKS PASSED - You're ready to go!" -ForegroundColor Green
    Write-Host "  ====================================================" -ForegroundColor Green
} else {
    Write-Host "  ====================================================" -ForegroundColor Yellow
    Write-Host "   Some checks failed - see above for details" -ForegroundColor Yellow
    Write-Host "  ====================================================" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Get started:" -ForegroundColor White
Write-Host "    1. Close this window and open a NEW terminal" -ForegroundColor Gray
Write-Host "    2. Type 'cc' and press Enter to launch Claude Code" -ForegroundColor Gray
Write-Host "    3. A browser will open for sign-in (first time only)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Quick reference:" -ForegroundColor White
Write-Host "    cc        Start Claude Code" -ForegroundColor Gray
Write-Host "    ccb       Start Claude Code (bypass mode)" -ForegroundColor Gray
Write-Host "    cc -h     Show Claude Code help" -ForegroundColor Gray
Write-Host ""
pause
