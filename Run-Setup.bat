@echo off
title Claude Code CLI - Setup
echo.
echo   Claude Code CLI - Environment Setup
echo   ====================================
echo.
echo   This will install: PowerShell 7, Git, Node.js, Python, Claude CLI
echo   You will see ONE administrator prompt - click Yes to continue.
echo.

:: Try pwsh (PowerShell 7+) first, fall back to powershell.exe (5.1)
where pwsh >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    pwsh.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Setup-ClaudeEnv.ps1"
) else (
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0Setup-ClaudeEnv.ps1"
)
