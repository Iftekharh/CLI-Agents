<#
.SYNOPSIS
    Fully Automated Hunter - Zero-prompt execution
.DESCRIPTION
    Complete automation with token refresh, detection, and HTML report generation
.EXAMPLE
    .\Fully-Automated-Hunter.ps1
#>

Write-Host "`n🎯 FULLY AUTOMATED ANOMALY HUNTER - Zero Prompts" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════`n" -ForegroundColor Cyan

$ErrorActionPreference = "Stop"

# 1. Token Refresh
Write-Host "[1/3] Refreshing authentication..." -ForegroundColor Yellow
& .\mcp-env.ps1 refresh -ErrorAction Stop

# 2. Run Detection
Write-Host "`n[2/3] Running 12-module detection..." -ForegroundColor Yellow
& .\agents\Comprehensive-Hunter.ps1 -ErrorAction Stop

# 3. Get latest report
$latestReport = Get-ChildItem ".\reports\comprehensive-report-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestReport) {
    $reportData = Get-Content $latestReport.FullName | ConvertFrom-Json
    
    Write-Host "`n[3/3] Detection Summary" -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
    Write-Host "  Total Anomalies: $($reportData.TotalAnomalies)" -ForegroundColor Cyan
    Write-Host "  Report: $($latestReport.Name)" -ForegroundColor Gray
    Write-Host ""
    
    foreach ($module in $reportData.DetectionModules.PSObject.Properties) {
        if ($module.Value -gt 0) {
            Write-Host "    • $($module.Name): $($module.Value)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n✅ Fully automated scan complete!" -ForegroundColor Green
    Write-Host "   Reports available in: .\reports\" -ForegroundColor Gray
}
else {
    Write-Host "⚠️  No report generated" -ForegroundColor Yellow
}

Write-Host ""
