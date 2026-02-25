# ============================================================
#  Claude Code CLI - Remote Bootstrap Installer
#  Usage:  irm https://raw.githubusercontent.com/<ORG>/<REPO>/main/Install-Remote.ps1 | iex
#
#  Downloads the full installer to a temp folder and runs it.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  Claude Code CLI - Team Setup" -ForegroundColor Cyan
Write-Host "  Downloading installer..." -ForegroundColor Gray
Write-Host ""

# ---- UPDATE THIS to your actual repo raw URL ----
$repoBase = "https://raw.githubusercontent.com/<ORG>/<REPO>/main"

$tempDir = Join-Path $env:TEMP "claude-setup-$(Get-Random)"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    $files = @("Setup-ClaudeEnv.ps1", "Verify-Install.ps1")

    foreach ($file in $files) {
        Write-Host "  Downloading $file..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri "$repoBase/$file" -OutFile (Join-Path $tempDir $file) -UseBasicParsing
    }

    Write-Host "  Starting installer..." -ForegroundColor Green
    Write-Host ""

    # Launch the main installer (it will self-elevate if needed)
    $installer = Join-Path $tempDir "Setup-ClaudeEnv.ps1"
    & powershell.exe -ExecutionPolicy Bypass -NoProfile -File $installer
} catch {
    Write-Host ""
    Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
    Write-Host "  Check your internet connection and try again." -ForegroundColor Yellow
    Write-Host ""
} finally {
    Start-Sleep -Seconds 2
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
}
