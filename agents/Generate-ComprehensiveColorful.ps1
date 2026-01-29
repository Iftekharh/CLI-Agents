<#
.SYNOPSIS
    Comprehensive Colorful Report Generator
.DESCRIPTION
    Generates visually enhanced HTML reports with gradients and colors
.PARAMETER ReportPath
    Path to JSON report file
.EXAMPLE
    .\Generate-ComprehensiveColorful.ps1
#>

param([string]$ReportPath)

if (!$ReportPath) {
    $ReportPath = Get-ChildItem ".\reports\comprehensive-report-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}

if (!(Test-Path $ReportPath)) {
    Write-Host "❌ Report not found: $ReportPath" -ForegroundColor Red
    exit 1
}

Write-Host "🎨 Generating comprehensive colorful report..." -ForegroundColor Cyan

$report = Get-Content $ReportPath | ConvertFrom-Json

$criticalCount = ($report.Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count
$highCount = ($report.Anomalies | Where-Object { $_.Severity -eq "High" }).Count
$mediumCount = ($report.Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count
$lowCount = ($report.Anomalies | Where-Object { $_.Severity -eq "Low" }).Count

$html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Comprehensive Security Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .container { max-width: 1400px; margin: 0 auto; background: white; border-radius: 12px; box-shadow: 0 10px 40px rgba(0,0,0,0.3); }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 40px; border-radius: 12px 12px 0 0; }
        h1 { margin: 0; font-size: 36px; }
        .stats { display: flex; justify-content: space-around; padding: 30px; background: #f8f9fa; }
        .stat-card { text-align: center; padding: 20px; border-radius: 8px; min-width: 150px; background: white; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        .stat-value { font-size: 48px; font-weight: bold; margin: 10px 0; }
        .critical .stat-value { color: #dc3545; }
        .high .stat-value { color: #fd7e14; }
        .medium .stat-value { color: #ffc107; }
        .low .stat-value { color: #28a745; }
        .content { padding: 40px; }
        .anomaly-card { background: white; border-left: 5px solid #667eea; padding: 20px; margin: 15px 0; border-radius: 6px; box-shadow: 0 2px 6px rgba(0,0,0,0.08); transition: transform 0.2s; }
        .anomaly-card:hover { transform: translateX(5px); }
        .anomaly-card.critical { border-left-color: #dc3545; }
        .anomaly-card.high { border-left-color: #fd7e14; }
        .anomaly-card.medium { border-left-color: #ffc107; }
        .severity-badge { display: inline-block; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; color: white; }
        .severity-badge.critical { background: linear-gradient(135deg, #dc3545, #c82333); }
        .severity-badge.high { background: linear-gradient(135deg, #fd7e14, #e8590c); }
        .severity-badge.medium { background: linear-gradient(135deg, #ffc107, #e0a800); }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Comprehensive Security Anomaly Report</h1>
            <p style="margin: 10px 0 0 0; opacity: 0.9;">Microsoft Sentinel MCP - Full Spectrum Analysis</p>
        </div>
        
        <div class="stats">
            <div class="stat-card critical">
                <div>Critical</div>
                <div class="stat-value">$criticalCount</div>
            </div>
            <div class="stat-card high">
                <div>High</div>
                <div class="stat-value">$highCount</div>
            </div>
            <div class="stat-card medium">
                <div>Medium</div>
                <div class="stat-value">$mediumCount</div>
            </div>
            <div class="stat-card low">
                <div>Low</div>
                <div class="stat-value">$lowCount</div>
            </div>
        </div>
        
        <div class="content">
            <h2>Detected Anomalies</h2>
"@

foreach ($anomaly in $report.Anomalies) {
    $severityClass = $anomaly.Severity.ToLower()
    $html += @"
            <div class="anomaly-card $severityClass">
                <span class="severity-badge $severityClass">$($anomaly.Severity.ToUpper())</span>
                <strong> $($anomaly.Module)</strong><br>
                <strong>User:</strong> $($anomaly.User)<br>
                <strong>Finding:</strong> $($anomaly.Description)<br>
                <small style="color: #6c757d;">$($anomaly.Details)</small>
            </div>
"@
}

$html += @"
        </div>
    </div>
</body>
</html>
"@

$outputPath = $ReportPath -replace '\.json$', '-colorful.html'
$html | Out-File $outputPath -Encoding UTF8

Write-Host "✅ Colorful report generated: $outputPath" -ForegroundColor Green
Start-Process $outputPath
