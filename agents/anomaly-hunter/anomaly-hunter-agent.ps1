# Anomaly Hunter Agent
# Continuously hunt for anomalous patterns across Microsoft Sentinel data
# Version: 1.0

param(
    [string]$ConfigPath = "C:\App\loop\agents\anomaly-hunter-config.json",
    [string]$Mode = "scan",  # scan, baseline, report
    [switch]$Interactive,
    [string]$Environment = "woodgrove"
)

$ErrorActionPreference = "Continue"
$global:Anomalies = @()
$global:StartTime = Get-Date

#region Helper Functions

function Write-AgentLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "INFO" = "White"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "DEBUG" = "Gray"
    }
    
    $color = $colorMap[$Level]
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Load-Configuration {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-AgentLog "Configuration file not found: $Path" "ERROR"
        exit 1
    }
    
    try {
        $config = Get-Content $Path -Raw | ConvertFrom-Json
        Write-AgentLog "Configuration loaded successfully" "SUCCESS"
        return $config
    }
    catch {
        Write-AgentLog "Failed to load configuration: $_" "ERROR"
        exit 1
    }
}

function Connect-SentinelMCP {
    param([string]$EnvName)
    
    Write-AgentLog "Connecting to Sentinel MCP environment: $EnvName" "INFO"
    
    try {
        & "C:\App\loop\mcp-env.ps1" use $EnvName 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-AgentLog "Connected to $EnvName" "SUCCESS"
            return $true
        }
        else {
            Write-AgentLog "Failed to connect to $EnvName" "ERROR"
            return $false
        }
    }
    catch {
        Write-AgentLog "Connection error: $_" "ERROR"
        return $false
    }
}

function Invoke-SentinelQuery {
    param(
        [string]$Query,
        [string]$QueryName = "Unnamed Query"
    )
    
    Write-AgentLog "Executing query: $QueryName" "DEBUG"
    
    $headers = @{
        "Authorization" = "Bearer $(Get-MCPToken)"
        "Accept" = "application/json, text/event-stream"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        jsonrpc = "2.0"
        id = (Get-Random -Maximum 10000)
        method = "tools/call"
        params = @{
            name = "query_lake"
            arguments = @{
                query = $Query
            }
        }
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri "https://sentinel.microsoft.com/mcp/data-exploration" -Method Post -Headers $headers -Body $body -TimeoutSec 300
        
        # Parse SSE response
        $lines = $response -split "`n"
        foreach ($line in $lines) {
            if ($line.StartsWith("data: ")) {
                $jsonData = $line.Substring(6)
                $data = $jsonData | ConvertFrom-Json
                
                if ($data.result.content) {
                    foreach ($content in $data.result.content) {
                        if ($content.type -eq "text") {
                            $resultData = $content.text | ConvertFrom-Json
                            return $resultData
                        }
                    }
                }
            }
        }
    }
    catch {
        Write-AgentLog "Query failed: $_" "ERROR"
        return $null
    }
}

function Get-MCPToken {
    $config = Get-Content "C:\App\loop\mcp.json" -Raw | ConvertFrom-Json
    return $config.servers.'mcp-sentinel'.headers.Authorization -replace "^Bearer\s+", ""
}

#endregion

#region Baseline Functions

function Build-Baseline {
    param($Config)
    
    Write-AgentLog "=== BUILDING BASELINES ===" "INFO"
    Write-AgentLog "Baseline period: $($Config.baseline.baselinePeriodDays) days" "INFO"
    
    $baselineStart = (Get-Date).AddDays(-$Config.baseline.baselinePeriodDays)
    $baselines = @{}
    
    # Build authentication baseline
    if ($Config.detection.modules.authenticationAnomalies.enabled) {
        Write-AgentLog "Building authentication baseline..." "INFO"
        $baselines.authentication = Build-AuthenticationBaseline -StartDate $baselineStart
    }
    
    # Build user behavior baseline
    if ($Config.detection.modules.userBehaviorAnomalies.enabled) {
        Write-AgentLog "Building user behavior baseline..." "INFO"
        $baselines.userBehavior = Build-UserBehaviorBaseline -StartDate $baselineStart
    }
    
    # Save baselines
    $baselinePath = Join-Path $Config.baseline.storageLocation "baseline-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $baselines | ConvertTo-Json -Depth 10 | Set-Content $baselinePath -Encoding UTF8
    
    # Also save as current baseline
    $currentBaselinePath = Join-Path $Config.baseline.storageLocation "baseline-current.json"
    $baselines | ConvertTo-Json -Depth 10 | Set-Content $currentBaselinePath -Encoding UTF8
    
    Write-AgentLog "Baselines saved to: $baselinePath" "SUCCESS"
    
    return $baselines
}

function Build-AuthenticationBaseline {
    param($StartDate)
    
    $query = @"
SigninLogs
| where TimeGenerated > datetime('$($StartDate.ToString("yyyy-MM-ddTHH:mm:ssZ"))')
| where ResultType == "0"
| extend Hour = hourofday(TimeGenerated)
| extend DayOfWeek = dayofweek(TimeGenerated)
| summarize 
    AvgLoginsPerDay = count() / 30.0,
    CommonHours = make_set(Hour),
    CommonLocations = make_set(Location),
    CommonDevices = make_set(DeviceDetail.displayName)
    by UserPrincipalName
| project UserPrincipalName, AvgLoginsPerDay, CommonHours, CommonLocations, CommonDevices
"@
    
    $result = Invoke-SentinelQuery -Query $query -QueryName "Authentication Baseline"
    
    if ($result -and $result.rows) {
        Write-AgentLog "Built baseline for $($result.rows.Count) users" "SUCCESS"
        return $result.rows
    }
    
    return @()
}

function Build-UserBehaviorBaseline {
    param($StartDate)
    
    $query = @"
SigninLogs
| where TimeGenerated > datetime('$($StartDate.ToString("yyyy-MM-ddTHH:mm:ssZ"))')
| summarize 
    AvgDailyLogins = count() / 30.0,
    UniqueApps = dcount(AppDisplayName),
    UniqueLocations = dcount(Location)
    by UserPrincipalName
"@
    
    $result = Invoke-SentinelQuery -Query $query -QueryName "User Behavior Baseline"
    
    if ($result -and $result.rows) {
        return $result.rows
    }
    
    return @()
}

function Load-Baseline {
    param($Config)
    
    $currentBaselinePath = Join-Path $Config.baseline.storageLocation "baseline-current.json"
    
    if (Test-Path $currentBaselinePath) {
        $baseline = Get-Content $currentBaselinePath -Raw | ConvertFrom-Json
        Write-AgentLog "Loaded baseline from: $currentBaselinePath" "SUCCESS"
        return $baseline
    }
    
    Write-AgentLog "No baseline found. Building new baseline..." "WARNING"
    return Build-Baseline -Config $Config
}

#endregion

#region Detection Functions

function Detect-AuthenticationAnomalies {
    param($Config, $Baseline)
    
    Write-AgentLog "Detecting authentication anomalies..." "INFO"
    
    $anomalies = @()
    
    # Unusual login times
    if ($Config.detection.modules.authenticationAnomalies.checks -contains "unusual_login_times") {
        $anomalies += Detect-UnusualLoginTimes -Baseline $Baseline
    }
    
    # Impossible travel
    if ($Config.detection.modules.authenticationAnomalies.checks -contains "impossible_travel") {
        $anomalies += Detect-ImpossibleTravel
    }
    
    # Multiple failed logins
    if ($Config.detection.modules.authenticationAnomalies.checks -contains "multiple_failed_logins") {
        $anomalies += Detect-MultipleFailedLogins
    }
    
    Write-AgentLog "Found $($anomalies.Count) authentication anomalies" "INFO"
    
    return $anomalies
}

function Detect-UnusualLoginTimes {
    param($Baseline)
    
    $query = @"
SigninLogs
| where TimeGenerated > ago(24h)
| where ResultType == "0"
| extend Hour = hourofday(TimeGenerated)
| where Hour < 6 or Hour > 22
| project TimeGenerated, UserPrincipalName, Hour, Location, IPAddress, AppDisplayName
| order by TimeGenerated desc
"@
    
    $result = Invoke-SentinelQuery -Query $query -QueryName "Unusual Login Times"
    
    $findings = @()
    
    if ($result -and $result.rows) {
        foreach ($row in $result.rows) {
            $findings += @{
                Type = "UnusualLoginTime"
                Severity = "Medium"
                User = $row[1]
                Time = $row[0]
                Hour = $row[2]
                Location = $row[3]
                IPAddress = $row[4]
                Application = $row[5]
                Description = "Login at unusual hour: $($row[2]):00"
                RiskScore = 50
            }
        }
    }
    
    return $findings
}

function Detect-ImpossibleTravel {
    
    $query = @"
SigninLogs
| where TimeGenerated > ago(24h)
| where ResultType == "0"
| where isnotempty(Location)
| project TimeGenerated, UserPrincipalName, Location, IPAddress, LocationDetails.city, LocationDetails.countryOrRegion
| order by UserPrincipalName, TimeGenerated asc
| extend PrevLocation = prev(Location, 1), PrevTime = prev(TimeGenerated, 1), PrevUser = prev(UserPrincipalName, 1)
| where UserPrincipalName == PrevUser and Location != PrevLocation
| extend TimeDiffHours = datetime_diff('hour', TimeGenerated, PrevTime)
| where TimeDiffHours < 4 and TimeDiffHours > 0
| project TimeGenerated, UserPrincipalName, Location, PrevLocation, TimeDiffHours, IPAddress
"@
    
    $result = Invoke-SentinelQuery -Query $query -QueryName "Impossible Travel"
    
    $findings = @()
    
    if ($result -and $result.rows) {
        foreach ($row in $result.rows) {
            $findings += @{
                Type = "ImpossibleTravel"
                Severity = "High"
                User = $row[1]
                Time = $row[0]
                CurrentLocation = $row[2]
                PreviousLocation = $row[3]
                TimeDiffHours = $row[4]
                IPAddress = $row[5]
                Description = "Impossible travel: $($row[3]) to $($row[2]) in $($row[4]) hours"
                RiskScore = 80
            }
        }
    }
    
    return $findings
}

function Detect-MultipleFailedLogins {
    
    $query = @"
SigninLogs
| where TimeGenerated > ago(1h)
| where ResultType != "0"
| summarize FailedAttempts = count(), FailureReasons = make_set(ResultDescription) by UserPrincipalName, IPAddress
| where FailedAttempts >= 5
| order by FailedAttempts desc
"@
    
    $result = Invoke-SentinelQuery -Query $query -QueryName "Multiple Failed Logins"
    
    $findings = @()
    
    if ($result -and $result.rows) {
        foreach ($row in $result.rows) {
            $severity = if ($row[2] -gt 20) { "Critical" } elseif ($row[2] -gt 10) { "High" } else { "Medium" }
            $riskScore = [math]::Min(100, $row[2] * 5)
            
            $findings += @{
                Type = "MultipleFailedLogins"
                Severity = $severity
                User = $row[0]
                IPAddress = $row[1]
                FailedAttempts = $row[2]
                Description = "$($row[2]) failed login attempts in last hour"
                RiskScore = $riskScore
            }
        }
    }
    
    return $findings
}

function Detect-UserBehaviorAnomalies {
    param($Config, $Baseline)
    
    Write-AgentLog "Detecting user behavior anomalies..." "INFO"
    
    $anomalies = @()
    
    # Unusual application usage
    if ($Config.detection.modules.userBehaviorAnomalies.checks -contains "application_usage") {
        $anomalies += Detect-UnusualApplicationUsage -Baseline $Baseline
    }
    
    Write-AgentLog "Found $($anomalies.Count) user behavior anomalies" "INFO"
    
    return $anomalies
}

function Detect-UnusualApplicationUsage {
    param($Baseline)
    
    $query = @"
SigninLogs
| where TimeGenerated > ago(24h)
| where ResultType == "0"
| summarize AppCount = dcount(AppDisplayName), Apps = make_set(AppDisplayName) by UserPrincipalName
| where AppCount > 10
| order by AppCount desc
"@
    
    $result = Invoke-SentinelQuery -Query $query -QueryName "Unusual Application Usage"
    
    $findings = @()
    
    if ($result -and $result.rows) {
        foreach ($row in $result.rows) {
            $findings += @{
                Type = "UnusualApplicationUsage"
                Severity = "Low"
                User = $row[0]
                AppCount = $row[1]
                Description = "Accessed $($row[1]) different applications in 24 hours"
                RiskScore = 35
            }
        }
    }
    
    return $findings
}

#endregion

#region Scoring and Prioritization

function Calculate-RiskScore {
    param($Anomaly, $Config)
    
    # Base score from detection
    $score = $Anomaly.RiskScore
    
    # Apply weights from config
    $weights = $Config.scoring.weights
    
    # Adjust based on severity
    $severityMultiplier = switch ($Anomaly.Severity) {
        "Critical" { 1.5 }
        "High" { 1.2 }
        "Medium" { 1.0 }
        "Low" { 0.8 }
        default { 1.0 }
    }
    
    $finalScore = [math]::Min(100, $score * $severityMultiplier)
    
    # Determine severity based on thresholds
    $thresholds = $Config.scoring.thresholds
    $Anomaly.Severity = if ($finalScore -ge $thresholds.critical) { "Critical" }
                       elseif ($finalScore -ge $thresholds.high) { "High" }
                       elseif ($finalScore -ge $thresholds.medium) { "Medium" }
                       else { "Low" }
    
    $Anomaly.RiskScore = [math]::Round($finalScore, 2)
    
    return $Anomaly
}

#endregion

#region Reporting

function Generate-Report {
    param($Anomalies, $Config)
    
    Write-AgentLog "Generating reports..." "INFO"
    
    $reportTime = Get-Date -Format "yyyyMMdd-HHmmss"
    
    # JSON Report
    if ($Config.reporting.outputFormats -contains "json") {
        $jsonPath = Join-Path $Config.reporting.outputPath "anomaly-report-$reportTime.json"
        $Anomalies | ConvertTo-Json -Depth 10 | Set-Content $jsonPath -Encoding UTF8
        Write-AgentLog "JSON report: $jsonPath" "SUCCESS"
    }
    
    # Markdown Report
    if ($Config.reporting.outputFormats -contains "markdown") {
        $mdPath = Join-Path $Config.reporting.outputPath "anomaly-report-$reportTime.md"
        Generate-MarkdownReport -Anomalies $Anomalies -OutputPath $mdPath
        Write-AgentLog "Markdown report: $mdPath" "SUCCESS"
    }
    
    # CSV Report
    if ($Config.reporting.outputFormats -contains "csv") {
        $csvPath = Join-Path $Config.reporting.outputPath "anomaly-report-$reportTime.csv"
        $Anomalies | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
        Write-AgentLog "CSV report: $csvPath" "SUCCESS"
    }
    
    # HTML Report
    if ($Config.reporting.outputFormats -contains "html") {
        $htmlPath = Join-Path $Config.reporting.outputPath "anomaly-report-$reportTime.html"
        Generate-HTMLReport -Anomalies $Anomalies -OutputPath $htmlPath -Config $Config
        Write-AgentLog "HTML report: $htmlPath" "SUCCESS"
    }
    
    # PDF Report
    if ($Config.reporting.outputFormats -contains "pdf") {
        $pdfPath = Join-Path $Config.reporting.outputPath "anomaly-report-$reportTime.pdf"
        
        if ($Config.reporting.pdfOptions.enabled) {
            try {
                # Try using PSWritePDF
                Import-Module PSWritePDF -ErrorAction Stop
                Generate-PDFReport -Anomalies $Anomalies -OutputPath $pdfPath -Config $Config
                Write-AgentLog "PDF report: $pdfPath" "SUCCESS"
            }
            catch {
                # Fallback to HTML with instruction
                Write-AgentLog "PSWritePDF not available. Creating HTML for manual PDF conversion" "WARNING"
                $htmlPath = Join-Path $Config.reporting.outputPath "anomaly-report-$reportTime.html"
                Generate-HTMLReport -Anomalies $Anomalies -OutputPath $htmlPath -Config $Config
                Write-AgentLog "Open HTML in browser and use 'Print to PDF' to create PDF" "INFO"
            }
        }
    }
}

function Generate-MarkdownReport {
    param($Anomalies, $OutputPath)
    
    $report = @"
# Anomaly Hunter Report
**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Total Anomalies Found:** $($Anomalies.Count)

---

## Summary by Severity

| Severity | Count |
|----------|-------|
| Critical | $($Anomalies | Where-Object { $_.Severity -eq "Critical" } | Measure-Object | Select-Object -ExpandProperty Count) |
| High     | $($Anomalies | Where-Object { $_.Severity -eq "High" } | Measure-Object | Select-Object -ExpandProperty Count) |
| Medium   | $($Anomalies | Where-Object { $_.Severity -eq "Medium" } | Measure-Object | Select-Object -ExpandProperty Count) |
| Low      | $($Anomalies | Where-Object { $_.Severity -eq "Low" } | Measure-Object | Select-Object -ExpandProperty Count) |

---

## Summary by Type

$(
    $Anomalies | Group-Object Type | ForEach-Object {
        "| $($_.Name) | $($_.Count) |"
    } | Out-String
)

---

## Detailed Findings

"@
    
    foreach ($anomaly in $Anomalies | Sort-Object RiskScore -Descending) {
        $report += @"

### $($anomaly.Type) - Risk Score: $($anomaly.RiskScore)

**Severity:** $($anomaly.Severity)  
**User:** $($anomaly.User)  
**Description:** $($anomaly.Description)

"@
        
        # Add type-specific details
        foreach ($key in $anomaly.Keys) {
            if ($key -notin @("Type", "Severity", "User", "Description", "RiskScore")) {
                $report += "**$($key):** $($anomaly[$key])`n"
            }
        }
        
        $report += "`n---`n"
    }
    
    $report | Set-Content $OutputPath -Encoding UTF8
}

function Generate-HTMLReport {
    param($Anomalies, $OutputPath, $Config)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $organization = if ($Config.reporting.pdfOptions.organization) { $Config.reporting.pdfOptions.organization } else { "Security Operations Center" }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Anomaly Hunter Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 40px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #0066cc; border-bottom: 3px solid #0066cc; padding-bottom: 10px; }
        h2 { color: #0066cc; border-bottom: 2px solid #e0e0e0; padding-bottom: 5px; margin-top: 30px; }
        .header { text-align: center; margin-bottom: 30px; }
        .summary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin: 20px 0; }
        .summary h2 { color: white; border-bottom: 2px solid white; }
        .stats { display: flex; justify-content: space-around; margin: 20px 0; }
        .stat-box { text-align: center; padding: 20px; border-radius: 5px; flex: 1; margin: 0 10px; }
        .critical-box { background: #d9534f; color: white; }
        .high-box { background: #f0ad4e; color: white; }
        .medium-box { background: #5bc0de; color: white; }
        .low-box { background: #5cb85c; color: white; }
        .stat-number { font-size: 36px; font-weight: bold; }
        .stat-label { font-size: 14px; text-transform: uppercase; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #0066cc; color: white; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        tr:hover { background-color: #f0f0f0; }
        .anomaly-card { border-left: 5px solid #ddd; padding: 20px; margin: 15px 0; background: #fafafa; border-radius: 5px; }
        .anomaly-card.critical { border-left-color: #d9534f; }
        .anomaly-card.high { border-left-color: #f0ad4e; }
        .anomaly-card.medium { border-left-color: #5bc0de; }
        .anomaly-card.low { border-left-color: #5cb85c; }
        .badge { display: inline-block; padding: 5px 10px; border-radius: 3px; font-weight: bold; font-size: 12px; }
        .badge-critical { background: #d9534f; color: white; }
        .badge-high { background: #f0ad4e; color: white; }
        .badge-medium { background: #5bc0de; color: white; }
        .badge-low { background: #5cb85c; color: white; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 2px solid #e0e0e0; text-align: center; color: #666; }
        @media print { body { background: white; } .container { box-shadow: none; } }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Anomaly Hunter Report</h1>
            <p><strong>Organization:</strong> $organization</p>
            <p><strong>Generated:</strong> $timestamp</p>
        </div>
        
        <div class="summary">
            <h2>Executive Summary</h2>
            <p style="font-size: 18px;"><strong>Total Anomalies Detected:</strong> $($Anomalies.Count)</p>
            
            <div class="stats">
                <div class="stat-box critical-box">
                    <div class="stat-number">$(($Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count)</div>
                    <div class="stat-label">Critical</div>
                </div>
                <div class="stat-box high-box">
                    <div class="stat-number">$(($Anomalies | Where-Object { $_.Severity -eq "High" }).Count)</div>
                    <div class="stat-label">High</div>
                </div>
                <div class="stat-box medium-box">
                    <div class="stat-number">$(($Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count)</div>
                    <div class="stat-label">Medium</div>
                </div>
                <div class="stat-box low-box">
                    <div class="stat-number">$(($Anomalies | Where-Object { $_.Severity -eq "Low" }).Count)</div>
                    <div class="stat-label">Low</div>
                </div>
            </div>
        </div>
        
        <h2>Severity Distribution</h2>
        <table>
            <tr><th>Severity</th><th>Count</th><th>Percentage</th><th>Risk Level</th></tr>
            <tr>
                <td><span class="badge badge-critical">Critical</span></td>
                <td>$(($Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count)</td>
                <td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count/$Anomalies.Count)*100,1))%</td>
                <td>Immediate investigation required</td>
            </tr>
            <tr>
                <td><span class="badge badge-high">High</span></td>
                <td>$(($Anomalies | Where-Object { $_.Severity -eq "High" }).Count)</td>
                <td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "High" }).Count/$Anomalies.Count)*100,1))%</td>
                <td>Investigate within 1 hour</td>
            </tr>
            <tr>
                <td><span class="badge badge-medium">Medium</span></td>
                <td>$(($Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count)</td>
                <td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count/$Anomalies.Count)*100,1))%</td>
                <td>Investigate within 24 hours</td>
            </tr>
            <tr>
                <td><span class="badge badge-low">Low</span></td>
                <td>$(($Anomalies | Where-Object { $_.Severity -eq "Low" }).Count)</td>
                <td>$([math]::Round((($Anomalies | Where-Object { $_.Severity -eq "Low" }).Count/$Anomalies.Count)*100,1))%</td>
                <td>Monitor and review</td>
            </tr>
        </table>
        
        <h2>Anomaly Type Breakdown</h2>
        <table>
            <tr><th>Type</th><th>Count</th></tr>
"@
    
    $typeGroups = $Anomalies | Group-Object Type | Sort-Object Count -Descending
    foreach ($group in $typeGroups) {
        $html += "            <tr><td>$($group.Name)</td><td>$($group.Count)</td></tr>`n"
    }
    
    $html += @"
        </table>
        
        <h2>Top Anomalies (Ordered by Risk Score)</h2>
"@
    
    $sortedAnomalies = $Anomalies | Sort-Object RiskScore -Descending | Select-Object -First 20
    
    foreach ($anomaly in $sortedAnomalies) {
        $severityClass = $anomaly.Severity.ToLower()
        $badgeClass = "badge-" + $severityClass
        
        $html += @"
        <div class="anomaly-card $severityClass">
            <h3>
                <span class="badge $badgeClass">$($anomaly.Severity)</span>
                $($anomaly.Type)
                <span style="float: right; color: #666;">Risk Score: $($anomaly.RiskScore)</span>
            </h3>
            <p><strong>User:</strong> $($anomaly.User)</p>
            <p><strong>Description:</strong> $($anomaly.Description)</p>
"@
        
        foreach ($key in $anomaly.Keys) {
            if ($key -notin @("Type", "Severity", "User", "Description", "RiskScore")) {
                $html += "            <p><strong>$($key):</strong> $($anomaly[$key])</p>`n"
            }
        }
        
        $html += "        </div>`n"
    }
    
    $html += @"
        
        <h2>Recommendations</h2>
        
        <div class="anomaly-card critical">
            <h3>🔴 Immediate Actions (Within 1 Hour)</h3>
            <ul>
                <li>Investigate all Critical severity anomalies immediately</li>
                <li>Investigate all High severity anomalies within 1 hour</li>
                <li>Verify user account security for flagged users</li>
                <li>Review authentication logs for suspicious patterns</li>
                <li>Consider temporary account restrictions for highest risk users</li>
            </ul>
        </div>
        
        <div class="anomaly-card high">
            <h3>🟡 Short-term Actions (Within 24 Hours)</h3>
            <ul>
                <li>Implement Multi-Factor Authentication for high-risk accounts</li>
                <li>Review and update security baselines</li>
                <li>Enhance monitoring rules for detected patterns</li>
                <li>Conduct user interviews for Medium severity anomalies</li>
                <li>Update security awareness training based on findings</li>
            </ul>
        </div>
        
        <div class="anomaly-card medium">
            <h3>🔵 Long-term Actions (Within 1 Week)</h3>
            <ul>
                <li>Review and enhance organizational security policies</li>
                <li>Implement automated response workflows</li>
                <li>Schedule security training for affected departments</li>
                <li>Conduct access review for privileged accounts</li>
                <li>Update incident response playbooks</li>
            </ul>
        </div>
        
        <div class="footer">
            <p><strong>Report Classification:</strong> CONFIDENTIAL - Internal Use Only</p>
            <p>Generated by <strong>Anomaly Hunter Agent v1.0</strong></p>
            <p>For questions or issues, contact: Security Operations Center</p>
        </div>
    </div>
</body>
</html>
"@
    
    $html | Set-Content $OutputPath -Encoding UTF8
}

function Generate-PDFReport {
    param($Anomalies, $OutputPath, $Config)
    
    try {
        $organization = if ($Config.reporting.pdfOptions.organization) { $Config.reporting.pdfOptions.organization } else { "Security Operations Center" }
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # First generate HTML
        $htmlPath = $OutputPath -replace '\.pdf$', '.html'
        Generate-HTMLReport -Anomalies $Anomalies -OutputPath $htmlPath -Config $Config
        
        # Provide instructions for PDF conversion
        Write-AgentLog "HTML report created: $htmlPath" "SUCCESS"
        Write-AgentLog "To convert to PDF: Open in Chrome/Edge and use 'Print to PDF'" "INFO"
        Write-AgentLog "Or install wkhtmltopdf for automated conversion" "INFO"
        
    }
    catch {
        Write-AgentLog "PDF generation failed: $_" "ERROR"
    }
}

#endregion

#region Main Execution

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           🔍 ANOMALY HUNTER AGENT v1.0                           ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Load configuration
$config = Load-Configuration -Path $ConfigPath

# Connect to Sentinel
if (-not (Connect-SentinelMCP -EnvName $Environment)) {
    Write-AgentLog "Failed to connect to Sentinel. Exiting." "ERROR"
    exit 1
}

Write-Host ""

switch ($Mode.ToLower()) {
    "baseline" {
        Write-AgentLog "Mode: Building Baseline" "INFO"
        $baseline = Build-Baseline -Config $config
        Write-AgentLog "Baseline build complete" "SUCCESS"
    }
    
    "scan" {
        Write-AgentLog "Mode: Anomaly Scan" "INFO"
        
        # Load or build baseline
        $baseline = Load-Baseline -Config $config
        
        # Run detections
        Write-Host ""
        Write-AgentLog "=== RUNNING ANOMALY DETECTION ===" "INFO"
        
        $allAnomalies = @()
        
        if ($config.detection.modules.authenticationAnomalies.enabled) {
            $authAnomalies = Detect-AuthenticationAnomalies -Config $config -Baseline $baseline
            $allAnomalies += $authAnomalies
        }
        
        if ($config.detection.modules.userBehaviorAnomalies.enabled) {
            $behaviorAnomalies = Detect-UserBehaviorAnomalies -Config $config -Baseline $baseline
            $allAnomalies += $behaviorAnomalies
        }
        
        # Score anomalies
        Write-Host ""
        Write-AgentLog "=== SCORING ANOMALIES ===" "INFO"
        
        $scoredAnomalies = @()
        foreach ($anomaly in $allAnomalies) {
            $scored = Calculate-RiskScore -Anomaly $anomaly -Config $config
            $scoredAnomalies += $scored
        }
        
        # Generate reports
        Write-Host ""
        if ($scoredAnomalies.Count -gt 0) {
            Generate-Report -Anomalies $scoredAnomalies -Config $config
            
            # Display summary
            Write-Host ""
            Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
            Write-Host "║                    SCAN COMPLETE                                  ║" -ForegroundColor Green
            Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
            Write-Host ""
            Write-Host "Total Anomalies Found: " -NoNewline
            Write-Host $scoredAnomalies.Count -ForegroundColor Yellow
            Write-Host ""
            
            Write-Host "By Severity:" -ForegroundColor Cyan
            Write-Host "  Critical: " -NoNewline -ForegroundColor Red
            Write-Host ($scoredAnomalies | Where-Object { $_.Severity -eq "Critical" }).Count
            Write-Host "  High:     " -NoNewline -ForegroundColor Yellow
            Write-Host ($scoredAnomalies | Where-Object { $_.Severity -eq "High" }).Count
            Write-Host "  Medium:   " -NoNewline -ForegroundColor White
            Write-Host ($scoredAnomalies | Where-Object { $_.Severity -eq "Medium" }).Count
            Write-Host "  Low:      " -NoNewline -ForegroundColor Gray
            Write-Host ($scoredAnomalies | Where-Object { $_.Severity -eq "Low" }).Count
            
            Write-Host ""
            Write-Host "Top 5 Anomalies:" -ForegroundColor Cyan
            $scoredAnomalies | Sort-Object RiskScore -Descending | Select-Object -First 5 | ForEach-Object {
                $color = switch ($_.Severity) {
                    "Critical" { "Red" }
                    "High" { "Yellow" }
                    "Medium" { "White" }
                    default { "Gray" }
                }
                Write-Host "  [$($_.Severity)] $($_.Type) - $($_.User): $($_.Description)" -ForegroundColor $color
            }
        }
        else {
            Write-Host ""
            Write-Host "✓ No anomalies detected" -ForegroundColor Green
        }
    }
    
    "report" {
        Write-AgentLog "Mode: Report Only" "INFO"
        # Find latest anomaly data and generate report
    }
    
    default {
        Write-AgentLog "Unknown mode: $Mode" "ERROR"
        Write-Host "Valid modes: baseline, scan, report"
    }
}

$duration = ((Get-Date) - $global:StartTime).TotalSeconds
Write-Host ""
Write-AgentLog "Agent execution completed in $([math]::Round($duration, 2)) seconds" "SUCCESS"
Write-Host ""

#endregion

