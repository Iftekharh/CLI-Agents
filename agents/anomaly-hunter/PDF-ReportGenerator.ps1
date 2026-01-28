# PDF Report Generator for Anomaly Hunter
# Generates professional PDF reports from anomaly data

function New-AnomalyPDFReport {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Anomalies,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,
        
        [string]$Title = "Anomaly Hunter Report",
        [string]$Organization = "Security Operations Center"
    )
    
    try {
        Import-Module PSWritePDF -ErrorAction Stop
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Create PDF document
        $pdf = New-PDF {
            # Cover Page
            New-PDFPage -PageSize A4 {
                New-PDFText -Text $Title -FontSize 24 -FontColor Blue -Alignment Center
                New-PDFText -Text "" -FontSize 12
                New-PDFText -Text "Generated: $timestamp" -FontSize 12 -Alignment Center
                New-PDFText -Text $Organization -FontSize 14 -Alignment Center
                New-PDFText -Text "" -FontSize 12
                New-PDFText -Text "" -FontSize 12
                
                # Executive Summary Box
                New-PDFText -Text "EXECUTIVE SUMMARY" -FontSize 16 -FontColor Red
                New-PDFText -Text "" -FontSize 8
                
                $criticalCount = ($Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count
                $highCount = ($Anomalies | Where-Object { $_.Severity -eq "High" }).Count
                $mediumCount = ($Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count
                $lowCount = ($Anomalies | Where-Object { $_.Severity -eq "Low" }).Count
                
                New-PDFText -Text "Total Anomalies Detected: $($Anomalies.Count)" -FontSize 14
                New-PDFText -Text "" -FontSize 8
                New-PDFText -Text "Critical: $criticalCount" -FontSize 12 -FontColor Red
                New-PDFText -Text "High: $highCount" -FontSize 12 -FontColor DarkOrange
                New-PDFText -Text "Medium: $mediumCount" -FontSize 12 -FontColor Orange
                New-PDFText -Text "Low: $lowCount" -FontSize 12 -FontColor Gray
            }
            
            # Summary Table
            New-PDFPage -PageSize A4 {
                New-PDFText -Text "SEVERITY BREAKDOWN" -FontSize 16 -FontColor Blue
                New-PDFText -Text "" -FontSize 10
                
                $summaryData = @(
                    [PSCustomObject]@{Severity="Critical"; Count=$criticalCount; Percentage="$([math]::Round(($criticalCount/$Anomalies.Count)*100,1))%"}
                    [PSCustomObject]@{Severity="High"; Count=$highCount; Percentage="$([math]::Round(($highCount/$Anomalies.Count)*100,1))%"}
                    [PSCustomObject]@{Severity="Medium"; Count=$mediumCount; Percentage="$([math]::Round(($mediumCount/$Anomalies.Count)*100,1))%"}
                    [PSCustomObject]@{Severity="Low"; Count=$lowCount; Percentage="$([math]::Round(($lowCount/$Anomalies.Count)*100,1))%"}
                )
                
                New-PDFTable -DataTable $summaryData -Verbose
                
                New-PDFText -Text "" -FontSize 10
                New-PDFText -Text "ANOMALY TYPES" -FontSize 16 -FontColor Blue
                New-PDFText -Text "" -FontSize 10
                
                $typeBreakdown = $Anomalies | Group-Object Type | Select-Object @{N="Type";E={$_.Name}}, Count | Sort-Object Count -Descending
                
                if ($typeBreakdown) {
                    New-PDFTable -DataTable $typeBreakdown
                }
            }
            
            # Detailed Findings
            New-PDFPage -PageSize A4 {
                New-PDFText -Text "DETAILED FINDINGS" -FontSize 16 -FontColor Blue
                New-PDFText -Text "" -FontSize 10
                
                $sortedAnomalies = $Anomalies | Sort-Object RiskScore -Descending | Select-Object -First 20
                
                foreach ($anomaly in $sortedAnomalies) {
                    $color = switch ($anomaly.Severity) {
                        "Critical" { "Red" }
                        "High" { "DarkOrange" }
                        "Medium" { "Orange" }
                        default { "Black" }
                    }
                    
                    New-PDFText -Text "[$($anomaly.Severity)] $($anomaly.Type)" -FontSize 12 -FontColor $color
                    New-PDFText -Text "Risk Score: $($anomaly.RiskScore)" -FontSize 10
                    New-PDFText -Text "User: $($anomaly.User)" -FontSize 10
                    New-PDFText -Text "Description: $($anomaly.Description)" -FontSize 10
                    New-PDFText -Text "" -FontSize 8
                }
            }
            
            # Recommendations
            New-PDFPage -PageSize A4 {
                New-PDFText -Text "RECOMMENDATIONS" -FontSize 16 -FontColor Blue
                New-PDFText -Text "" -FontSize 10
                
                New-PDFText -Text "Immediate Actions:" -FontSize 14 -FontColor Red
                New-PDFText -Text "• Investigate all Critical and High severity anomalies" -FontSize 11
                New-PDFText -Text "• Verify user account security for flagged users" -FontSize 11
                New-PDFText -Text "• Review access logs for suspicious patterns" -FontSize 11
                New-PDFText -Text "" -FontSize 10
                
                New-PDFText -Text "Short-term Actions:" -FontSize 14 -FontColor Orange
                New-PDFText -Text "• Implement MFA for high-risk accounts" -FontSize 11
                New-PDFText -Text "• Review and update baseline configurations" -FontSize 11
                New-PDFText -Text "• Enhance monitoring for identified anomaly patterns" -FontSize 11
                New-PDFText -Text "" -FontSize 10
                
                New-PDFText -Text "Long-term Actions:" -FontSize 14 -FontColor Blue
                New-PDFText -Text "• Conduct security awareness training" -FontSize 11
                New-PDFText -Text "• Review and enhance security policies" -FontSize 11
                New-PDFText -Text "• Implement automated response workflows" -FontSize 11
            }
        }
        
        # Save PDF
        $pdf | Export-PDF -FilePath $OutputPath
        
        return $true
    }
    catch {
        Write-Host "PDF generation error: $_" -ForegroundColor Red
        return $false
    }
}

# Simplified PDF generator (fallback if PSWritePDF not available)
function New-SimplePDFReport {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Anomalies,
        
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )
    
    # Generate HTML first
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Anomaly Hunter Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #0066cc; border-bottom: 3px solid #0066cc; }
        h2 { color: #0066cc; border-bottom: 1px solid #ccc; }
        .summary { background: #f0f0f0; padding: 20px; margin: 20px 0; border-left: 5px solid #0066cc; }
        .critical { color: #d9534f; font-weight: bold; }
        .high { color: #f0ad4e; font-weight: bold; }
        .medium { color: #5bc0de; }
        .low { color: #5cb85c; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #0066cc; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .anomaly-card { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>🔍 Anomaly Hunter Report</h1>
    <p><strong>Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    
    <div class="summary">
        <h2>Executive Summary</h2>
        <p><strong>Total Anomalies:</strong> $($Anomalies.Count)</p>
        <ul>
            <li class="critical">Critical: $(($Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count)</li>
            <li class="high">High: $(($Anomalies | Where-Object { $_.Severity -eq "High" }).Count)</li>
            <li class="medium">Medium: $(($Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count)</li>
            <li class="low">Low: $(($Anomalies | Where-Object { $_.Severity -eq "Low" }).Count)</li>
        </ul>
    </div>
    
    <h2>Severity Breakdown</h2>
    <table>
        <tr><th>Severity</th><th>Count</th><th>Percentage</th></tr>
        <tr><td class="critical">Critical</td><td>$(($Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count)</td><td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count/$Anomalies.Count)*100,1))%</td></tr>
        <tr><td class="high">High</td><td>$(($Anomalies | Where-Object { $_.Severity -eq "High" }).Count)</td><td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "High" }).Count/$Anomalies.Count)*100,1))%</td></tr>
        <tr><td class="medium">Medium</td><td>$(($Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count)</td><td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count/$Anomalies.Count)*100,1))%</td></tr>
        <tr><td class="low">Low</td><td>$(($Anomalies | Where-Object { $_.Severity -eq "Low" }).Count)</td><td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "Low" }).Count/$Anomalies.Count)*100,1))%</td></tr>
    </table>
    
    <h2>Top Anomalies (by Risk Score)</h2>
"@
    
    $sortedAnomalies = $Anomalies | Sort-Object RiskScore -Descending | Select-Object -First 20
    
    foreach ($anomaly in $sortedAnomalies) {
        $severityClass = $anomaly.Severity.ToLower()
        $html += @"
    <div class="anomaly-card">
        <h3 class="$severityClass">[$($anomaly.Severity)] $($anomaly.Type)</h3>
        <p><strong>Risk Score:</strong> $($anomaly.RiskScore)</p>
        <p><strong>User:</strong> $($anomaly.User)</p>
        <p><strong>Description:</strong> $($anomaly.Description)</p>
"@
        
        # Add additional fields
        foreach ($key in $anomaly.Keys) {
            if ($key -notin @("Type", "Severity", "User", "Description", "RiskScore")) {
                $html += "        <p><strong>$($key):</strong> $($anomaly[$key])</p>`n"
            }
        }
        
        $html += "    </div>`n"
    }
    
    $html += @"
    
    <h2>Recommendations</h2>
    <h3 class="critical">Immediate Actions</h3>
    <ul>
        <li>Investigate all Critical and High severity anomalies within 1 hour</li>
        <li>Verify user account security for all flagged users</li>
        <li>Review access logs for suspicious patterns</li>
    </ul>
    
    <h3 class="high">Short-term Actions</h3>
    <ul>
        <li>Implement Multi-Factor Authentication for high-risk accounts</li>
        <li>Review and update baseline configurations</li>
        <li>Enhance monitoring for identified anomaly patterns</li>
    </ul>
    
    <h3 class="medium">Long-term Actions</h3>
    <ul>
        <li>Conduct security awareness training for affected users</li>
        <li>Review and enhance organizational security policies</li>
        <li>Implement automated response workflows</li>
    </ul>
    
    <hr>
    <p><small>Generated by Anomaly Hunter Agent v1.0</small></p>
</body>
</html>
"@
    
    # Save HTML
    $htmlPath = $OutputPath -replace '\.pdf$', '.html'
    $html | Set-Content $htmlPath -Encoding UTF8
    
    Write-Host "✓ HTML report created: $htmlPath" -ForegroundColor Green
    Write-Host "ℹ️  To convert to PDF: Open in browser and use Print to PDF" -ForegroundColor Cyan
    
    return $htmlPath
}

# Export functions
Export-ModuleMember -Function New-AnomalyPDFReport, New-SimplePDFReport
