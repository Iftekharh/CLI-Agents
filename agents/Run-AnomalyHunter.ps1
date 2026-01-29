<#
.SYNOPSIS
    Automated Anomaly Hunter Runner with Token Refresh
.DESCRIPTION
    Automated wrapper that handles token refresh and runs the Comprehensive Hunter
.EXAMPLE
    .\Run-AnomalyHunter.ps1
#>

param(
    [int]$BaselineDays = 180,
    [int]$DetectionDays = 7
)

$ErrorActionPreference = "Stop"

Write-Host "`n🚀 Automated Anomaly Hunter" -ForegroundColor Cyan
Write-Host "══════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Check prerequisites
if (!(Test-Path "mcp-env.ps1")) {
    Write-Host "❌ mcp-env.ps1 not found" -ForegroundColor Red
    exit 1
}

if (!(Test-Path "agents\Comprehensive-Hunter.ps1")) {
    Write-Host "❌ Comprehensive-Hunter.ps1 not found" -ForegroundColor Red
    exit 1
}

# Refresh token
Write-Host "🔄 Refreshing authentication token..." -ForegroundColor Yellow
& .\mcp-env.ps1 refresh

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Token refresh failed" -ForegroundColor Red
    exit 1
}

# Run comprehensive hunter
Write-Host "`n🔍 Running Comprehensive Anomaly Hunter..." -ForegroundColor Yellow
& .\agents\Comprehensive-Hunter.ps1 -BaselineDays $BaselineDays -DetectionDays $DetectionDays

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Anomaly hunt completed successfully!" -ForegroundColor Green
}
else {
    Write-Host "`n❌ Anomaly hunt failed" -ForegroundColor Red
    exit 1
}
