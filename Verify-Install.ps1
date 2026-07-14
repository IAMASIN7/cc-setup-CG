# ============================================================
#  Claude Code CLI - Post-Install Verification
#  Runs automatically after the installer, or manually anytime.
# ============================================================

Write-Host ""
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host "   Claude Code CLI - Verifying Installation" -ForegroundColor Cyan
Write-Host "  ====================================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# Check each tool
$tools = @(
    @{ Name = "PowerShell 7"; Cmd = "pwsh";   Flag = "--version" },
    @{ Name = "Git";          Cmd = "git";     Flag = "--version" },
    @{ Name = "Node.js";      Cmd = "node";    Flag = "--version" },
    @{ Name = "npm";          Cmd = "npm";     Flag = "--version" },
    @{ Name = "Python";       Cmd = "python";  Flag = "--version" },
    @{ Name = "GitHub CLI";   Cmd = "gh";      Flag = "--version" },
    @{ Name = "uv";           Cmd = "uv";      Flag = "--version" },
    @{ Name = "jq";           Cmd = "jq";      Flag = "--version" },
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

# Check shortcuts
Write-Host ""
$ccExists  = $null -ne (Get-Command cc  -ErrorAction SilentlyContinue)
$ccbExists = $null -ne (Get-Command ccb -ErrorAction SilentlyContinue)
if ($ccExists -and $ccbExists) {
    Write-Host "  [PASS]  Shortcuts 'cc' and 'ccb' are available" -ForegroundColor Green
} else {
    Write-Host "  [FAIL]  Shortcuts 'cc' / 'ccb' not found" -ForegroundColor Red
    Write-Host "          Close this terminal and open a new one, then try again." -ForegroundColor Yellow
    $allPassed = $false
}

# Check config file
if (Test-Path "$env:USERPROFILE\.claude.json") {
    Write-Host "  [PASS]  Config file ~/.claude.json exists" -ForegroundColor Green
} else {
    Write-Host "  [FAIL]  Config file ~/.claude.json not found" -ForegroundColor Red
    $allPassed = $false
}

# Check cc/ccb command shims (the version that works in every shell)
$ccShimPath = "$env:USERPROFILE\.local\bin\cc.cmd"
if (Test-Path $ccShimPath) {
    Write-Host "  [PASS]  cc / ccb command shims installed (work in any shell)" -ForegroundColor Green
} else {
    Write-Host "  [FAIL]  cc.cmd shim not found at $ccShimPath" -ForegroundColor Red
    $allPassed = $false
}

# Check settings.json (auto mode + xhigh reasoning)
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $autoOn = $false
    try {
        $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($s.permissions.defaultMode -eq "auto") { $autoOn = $true }
    } catch {}
    if ($autoOn) {
        Write-Host "  [PASS]  Auto mode is ON by default (settings.json)" -ForegroundColor Green
    } else {
        Write-Host "  [WARN]  settings.json exists but auto mode not set" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [FAIL]  ~/.claude/settings.json not found" -ForegroundColor Red
    $allPassed = $false
}

# Check the status line: the script exists, settings point at it, and it
# actually renders. A broken status line never blocks Claude Code, so a
# failure here is a warning rather than a hard fail.
$statusLineScript = "$env:USERPROFILE\.claude\statusline.mjs"
if (Test-Path $statusLineScript) {
    $wired = $false
    try {
        $s = Get-Content $settingsPath -Raw | ConvertFrom-Json
        if ($s.statusLine.command) { $wired = $true }
    } catch {}

    if (-not $wired) {
        Write-Host "  [WARN]  statusline.mjs exists but settings.json doesn't use it" -ForegroundColor Yellow
    } elseif (Get-Command node -ErrorAction SilentlyContinue) {
        # Feed it a sample payload and confirm it prints something.
        $sample = '{"model":{"display_name":"Opus"},"workspace":{"current_dir":"' +
                  ($env:USERPROFILE -replace '\\', '/') +
                  '"},"context_window":{"used_percentage":10,"context_window_size":200000},"cost":{}}'
        $rendered = $sample | & node $statusLineScript 2>$null
        if ($rendered) {
            Write-Host "  [PASS]  Status line renders:" -ForegroundColor Green
            Write-Host "            $rendered"
        } else {
            Write-Host "  [WARN]  Status line script produced no output" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [WARN]  Status line installed but Node.js is not on PATH yet" -ForegroundColor Yellow
    }
} else {
    Write-Host "  [WARN]  Status line not installed (~/.claude/statusline.mjs)" -ForegroundColor Yellow
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
Write-Host "    Type 'cc' and press Enter to launch Claude Code" -ForegroundColor Gray
Write-Host "    A browser will open for sign-in (first time only)" -ForegroundColor Gray
Write-Host ""
Write-Host "  Quick reference:" -ForegroundColor White
Write-Host "    cc        Start Claude Code" -ForegroundColor Gray
Write-Host "    ccb       Start Claude Code (bypass mode)" -ForegroundColor Gray
Write-Host "    cc -h     Show Claude Code help" -ForegroundColor Gray
Write-Host ""
