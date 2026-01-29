<#
.SYNOPSIS
    Analyst-Focused Report Generator
.DESCRIPTION
    Generates analyst-friendly HTML reports with aggregated findings
.PARAMETER ReportPath
    Path to JSON report file
.EXAMPLE
    .\Generate-AnalystReport.ps1 -ReportPath ".\reports\comprehensive-report-20260128-202824.json"
#>

param([string]$ReportPath)

if (!$ReportPath) {
    $ReportPath = Get-ChildItem ".\reports\comprehensive-report-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}

if (!(Test-Path $ReportPath)) {
    Write-Host "❌ Report not found: $ReportPath" -ForegroundColor Red
    exit 1
}

Write-Host "📊 Generating analyst report..." -ForegroundColor Cyan

$report = Get-Content $ReportPath | ConvertFrom-Json

# Group by severity and module
$bySeverity = $report.Anomalies | Group-Object Severity
$byModule = $report.Anomalies | Group-Object Module

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Analyst Report</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; max-width: 1200px; margin: 40px auto; padding: 20px; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        .summary { background: #ecf0f1; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px; text-align: center; }
        .metric-value { font-size: 32px; font-weight: bold; color: #e74c3c; }
        .finding { background: white; border-left: 4px solid #3498db; padding: 15px; margin: 10px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .critical { border-left-color: #e74c3c; }
        .high { border-left-color: #e67e22; }
        .medium { border-left-color: #f39c12; }
    </style>
</head>
<body>
    <h1>🔒 Security Analyst Report</h1>
    <div class="summary">
        <h2>Executive Summary</h2>
        <p><strong>Detection Period:</strong> Last $($report.DetectionDays) days</p>
        <p><strong>Baseline Period:</strong> $($report.BaselineDays) days</p>
        <div class="metric"><div class="metric-value">$($report.TotalAnomalies)</div><div>Total Findings</div></div>
    </div>
    
    <h2>Findings by Module</h2>
"@

foreach ($module in $byModule) {
    $html += "<div class='finding'><strong>$($module.Name)</strong> - $($module.Count) finding(s)</div>"
}

$html += @"
    
    <h2>Detailed Findings</h2>
"@

foreach ($anomaly in $report.Anomalies | Select-Object -First 20) {
    $severityClass = $anomaly.Severity.ToLower()
    $html += @"
    <div class='finding $severityClass'>
        <strong>[$($anomaly.Severity)] $($anomaly.Module)</strong><br>
        User: $($anomaly.User)<br>
        $($anomaly.Description)<br>
        <small>$($anomaly.Details)</small>
    </div>
"@
}

$html += "</body></html>"

$outputPath = $ReportPath -replace '\.json$', '-analyst.html'
$html | Out-File $outputPath -Encoding UTF8

Write-Host "✅ Analyst report generated: $outputPath" -ForegroundColor Green
Start-Process $outputPath
