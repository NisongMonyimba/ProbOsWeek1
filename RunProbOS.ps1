# =============================================================================
# RunProbOS.ps1 — ProbOS Week 1 Windows PowerShell Launcher
# =============================================================================
# HOW TO RUN:
#   1. Right-click this file in File Explorer
#   2. Click "Run with PowerShell"
#   OR open PowerShell and type:
#      .\RunProbOS.ps1
#
# WHAT IT DOES:
#   Launches Ubuntu (WSL) and runs either RunAll.sh or RunTests.sh
#   You get a menu to choose which one.
# =============================================================================

# Allow script to run (in case execution policy blocks it)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Clear screen and show banner
Clear-Host
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       ProbOS Week 1 — Windows PowerShell Launcher        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Project: /home/nison/ProbOsWeek1" -ForegroundColor White
Write-Host "  Date:    $(Get-Date)" -ForegroundColor White
Write-Host ""

# Check WSL is available
Write-Host "  Checking WSL..." -ForegroundColor Blue
$wslCheck = wsl --status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: WSL is not available on this machine." -ForegroundColor Red
    Write-Host "  Install WSL: open PowerShell as Admin and run:" -ForegroundColor Yellow
    Write-Host "    wsl --install" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "  WSL is available." -ForegroundColor Green
Write-Host ""

# Show menu
Write-Host "  What do you want to run?" -ForegroundColor White
Write-Host ""
Write-Host "  [1]  RunAll.sh    — Full pipeline: install + build + test + demos" -ForegroundColor Green
Write-Host "       Use on first run or after adding new code. (~3-5 min first time)" -ForegroundColor Gray
Write-Host ""
Write-Host "  [2]  RunTests.sh  — Tests only: pytest + mypy + ruff + ctest" -ForegroundColor Cyan
Write-Host "       Use when iterating on code. (~30 seconds)" -ForegroundColor Gray
Write-Host ""
Write-Host "  [3]  Both         — RunTests.sh first, then RunAll.sh" -ForegroundColor Yellow
Write-Host ""
Write-Host "  [q]  Quit" -ForegroundColor Red
Write-Host ""

$choice = Read-Host "  Enter your choice [1/2/3/q]"

Write-Host ""

switch ($choice.ToLower()) {

    "1" {
        Write-Host "  Running RunAll.sh..." -ForegroundColor Green
        Write-Host "  (A new Ubuntu terminal window will open)" -ForegroundColor Gray
        Write-Host ""
        wsl -d Ubuntu-22.04 bash -c "cd /home/nison/ProbOsWeek1 && source .venv/bin/activate 2>/dev/null; chmod +x scripts/RunAll.sh; bash scripts/RunAll.sh"
    }

    "2" {
        Write-Host "  Running RunTests.sh..." -ForegroundColor Cyan
        Write-Host ""
        wsl -d Ubuntu-22.04 bash -c "cd /home/nison/ProbOsWeek1 && source .venv/bin/activate 2>/dev/null; chmod +x scripts/RunTests.sh; bash scripts/RunTests.sh"
    }

    "3" {
        Write-Host "  Running RunTests.sh then RunAll.sh..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "--- RunTests.sh ---" -ForegroundColor Cyan
        wsl -d Ubuntu-22.04 bash -c "cd /home/nison/ProbOsWeek1 && source .venv/bin/activate 2>/dev/null; chmod +x scripts/RunTests.sh; bash scripts/RunTests.sh"
        Write-Host ""
        Write-Host "--- RunAll.sh ---" -ForegroundColor Green
        wsl -d Ubuntu-22.04 bash -c "cd /home/nison/ProbOsWeek1 && source .venv/bin/activate 2>/dev/null; chmod +x scripts/RunAll.sh; bash scripts/RunAll.sh"
    }

    { $_ -eq "q" -or $_ -eq "quit" } {
        Write-Host "  Exiting." -ForegroundColor Yellow
        exit 0
    }

    default {
        Write-Host "  Unknown choice '$choice' — running RunAll.sh by default." -ForegroundColor Yellow
        Write-Host ""
        wsl -d Ubuntu-22.04 bash -c "cd /home/nison/ProbOsWeek1 && source .venv/bin/activate 2>/dev/null; chmod +x scripts/RunAll.sh; bash scripts/RunAll.sh"
    }
}

# Show result
Write-Host ""
if ($LASTEXITCODE -eq 0) {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  SUCCESS — all steps completed                           ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
} else {
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  FAILED — check the output above for errors              ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to close"
