<#
.SYNOPSIS
    Comprehensive 12-Module Anomaly Detection Engine for Microsoft Sentinel
.DESCRIPTION
    Detects security anomalies across 12 detection modules with 180-day baseline analysis
    Generates JSON, CSV, and HTML reports with all findings
.PARAMETER BaselineDays
    Number of days to use for baseline analysis (default: 180)
.PARAMETER DetectionDays
    Number of days for detection window (default: 7)
.PARAMETER MaxUsers
    Maximum number of users to analyze for baseline (default: 1000)
.EXAMPLE
    .\Comprehensive-Hunter.ps1
    .\Comprehensive-Hunter.ps1 -BaselineDays 90 -DetectionDays 14
#>

param(
    [int]$BaselineDays = 180,
    [int]$DetectionDays = 7,
    [int]$MaxUsers = 1000
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   COMPREHENSIVE ANOMALY HUNTER - 12 Detection Modules       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Configuration
$ReportDir = ".\reports"
$BaselineDir = ".\baselines"
$AnomalyDir = ".\anomalies"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Create directories
@($ReportDir, $BaselineDir, $AnomalyDir) | ForEach-Object {
    if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
}

# Load MCP configuration
$McpConfig = Get-Content "mcp.json" | ConvertFrom-Json
$ServerName = ($McpConfig.mcpServers | Get-Member -MemberType NoteProperty | Select-Object -First 1).Name
$BearerToken = $McpConfig.mcpServers.$ServerName.headers.Authorization -replace "^Bearer ", ""

if (!$BearerToken) {
    Write-Host "❌ No bearer token found in mcp.json" -ForegroundColor Red
    Write-Host "   Run: .\mcp-env.ps1 refresh" -ForegroundColor Yellow
    exit 1
}

# MCP Query Function
function Invoke-McpQuery {
    param([string]$Query, [string]$Description)
    
    Write-Host "  🔍 $Description..." -NoNewline
    
    $body = @{
        query = $Query
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-WebRequest -Uri "https://sentinel.microsoft.com/mcp/data-exploration" `
            -Method POST `
            -Headers @{
                "Authorization" = "Bearer $BearerToken"
                "Content-Type" = "application/json"
                "Accept" = "application/json, text/event-stream"
            } `
            -Body $body `
            -UseBasicParsing
        
        # Parse SSE format
        $content = $response.Content
        if ($content -match 'data: ({.*})') {
            $jsonData = $matches[1] | ConvertFrom-Json
            
            if ($jsonData.frames -and $jsonData.frames.Count -gt 0) {
                $primaryFrame = $jsonData.frames | Where-Object { $_.schema.name -eq "PrimaryResult" } | Select-Object -First 1
                
                if ($primaryFrame -and $primaryFrame.data.values) {
                    $columnNames = $primaryFrame.schema.columns.name
                    $rows = @()
                    
                    foreach ($rowData in $primaryFrame.data.values) {
                        $row = @{}
                        for ($i = 0; $i -lt $columnNames.Count; $i++) {
                            $row[$columnNames[$i]] = $rowData[$i]
                        }
                        $rows += [PSCustomObject]$row
                    }
                    
                    Write-Host " ✓ ($($rows.Count) results)" -ForegroundColor Green
                    return $rows
                }
            }
        }
        
        Write-Host " ⚠️  No data" -ForegroundColor Yellow
        return @()
    }
    catch {
        Write-Host " ❌ Error" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor DarkRed
        return @()
    }
}

# Detection Results Storage
$AllAnomalies = @()
$ModuleStats = @{}

Write-Host "[PHASE 1] Building User Baseline ($BaselineDays days)..." -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

$baselineQuery = @"
SigninLogs
| where TimeGenerated between (ago(${BaselineDays}d) .. ago(${DetectionDays}d))
| where ResultType == "0"
| summarize 
    LoginCount = count(),
    UniqueLocations = dcount(Location),
    UniqueIPs = dcount(IPAddress),
    UniqueApps = dcount(AppDisplayName),
    UniqueDevices = dcount(DeviceDetail_deviceId)
    by UserPrincipalName
| where UserPrincipalName != ""
| top $MaxUsers by LoginCount desc
"@

$baseline = Invoke-McpQuery -Query $baselineQuery -Description "Analyzing top $MaxUsers users"

if ($baseline.Count -eq 0) {
    Write-Host "❌ Failed to build baseline. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "`n[PHASE 2] Running 12 Detection Modules..." -ForegroundColor Cyan
Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray

# Module 1: Failed Login Detection
Write-Host "`n📌 Module 1: Failed Login Detection" -ForegroundColor Magenta
$failedQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType != "0"
| summarize 
    FailedCount = count(),
    ErrorCodes = make_set(ResultType),
    LastFailure = max(TimeGenerated)
    by UserPrincipalName, IPAddress, Location
| where FailedCount > 10
| order by FailedCount desc
"@
$failedLogins = Invoke-McpQuery -Query $failedQuery -Description "Detecting excessive failed logins"
$failedLogins | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Failed Login Detection"
        Severity = if ($_.FailedCount -gt 100) { "Critical" } elseif ($_.FailedCount -gt 50) { "High" } else { "Medium" }
        User = $_.UserPrincipalName
        Description = "User had $($_.FailedCount) failed login attempts"
        Details = "IP: $($_.IPAddress), Location: $($_.Location), Last: $($_.LastFailure)"
        Timestamp = $_.LastFailure
    }
}
$ModuleStats["Failed Login Detection"] = $failedLogins.Count

# Module 2: Geographic Analysis - New Locations
Write-Host "`n📌 Module 2: Geographic Analysis (New Locations)" -ForegroundColor Magenta
$locationQuery = @"
let baseline_locations = SigninLogs
| where TimeGenerated between (ago(${BaselineDays}d) .. ago(${DetectionDays}d))
| where ResultType == "0"
| summarize by UserPrincipalName, Location;
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| distinct UserPrincipalName, Location, TimeGenerated
| join kind=leftanti baseline_locations on UserPrincipalName, Location
| summarize NewLocationCount = count(), Locations = make_set(Location), FirstSeen = min(TimeGenerated) by UserPrincipalName
| order by NewLocationCount desc
"@
$newLocations = Invoke-McpQuery -Query $locationQuery -Description "Identifying new geographic locations"
$newLocations | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Geographic Analysis"
        Severity = if ($_.NewLocationCount -gt 5) { "High" } else { "Medium" }
        User = $_.UserPrincipalName
        Description = "User logged in from $($_.NewLocationCount) new location(s)"
        Details = "Locations: $($_.Locations -join ', ')"
        Timestamp = $_.FirstSeen
    }
}
$ModuleStats["Geographic Analysis"] = $newLocations.Count

# Module 3: Activity Analysis - Excessive Activity
Write-Host "`n📌 Module 3: Activity Analysis (Excessive Logins)" -ForegroundColor Magenta
$activityQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| summarize CurrentLogins = count() by UserPrincipalName
| order by CurrentLogins desc
| where CurrentLogins > 500
"@
$excessiveActivity = Invoke-McpQuery -Query $activityQuery -Description "Finding excessive login activity"
$excessiveActivity | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Activity Analysis"
        Severity = if ($_.CurrentLogins -gt 2000) { "Critical" } elseif ($_.CurrentLogins -gt 1000) { "High" } else { "Medium" }
        User = $_.UserPrincipalName
        Description = "User had $($_.CurrentLogins) logins in $DetectionDays days"
        Details = "Average: $([math]::Round($_.CurrentLogins / $DetectionDays, 1)) logins/day"
        Timestamp = Get-Date
    }
}
$ModuleStats["Activity Analysis"] = $excessiveActivity.Count

# Module 4: Temporal Analysis - Off-Hours Activity
Write-Host "`n📌 Module 4: Temporal Analysis (Off-Hours)" -ForegroundColor Magenta
$offHoursQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| extend Hour = datetime_part('hour', TimeGenerated)
| where Hour >= 0 and Hour < 6
| summarize OffHoursCount = count(), Hours = make_set(Hour) by UserPrincipalName
| where OffHoursCount > 20
| order by OffHoursCount desc
"@
$offHours = Invoke-McpQuery -Query $offHoursQuery -Description "Detecting off-hours activity"
$offHours | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Temporal Analysis"
        Severity = if ($_.OffHoursCount -gt 100) { "High" } else { "Medium" }
        User = $_.UserPrincipalName
        Description = "User had $($_.OffHoursCount) logins during off-hours (midnight-6AM)"
        Details = "Hours: $($_.Hours -join ', ')"
        Timestamp = Get-Date
    }
}
$ModuleStats["Temporal Analysis"] = $offHours.Count

# Module 5: Network Analysis - Multiple IPs
Write-Host "`n📌 Module 5: Network Analysis (Multiple IPs)" -ForegroundColor Magenta
$ipQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| summarize IPCount = dcount(IPAddress), IPs = make_set(IPAddress) by UserPrincipalName
| where IPCount > 10
| order by IPCount desc
"@
$multipleIPs = Invoke-McpQuery -Query $ipQuery -Description "Finding users with many IP addresses"
$multipleIPs | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Network Analysis"
        Severity = if ($_.IPCount -gt 50) { "High" } else { "Medium" }
        User = $_.UserPrincipalName
        Description = "User accessed from $($_.IPCount) different IP addresses"
        Details = "Sample IPs: $($_.IPs[0..2] -join ', ')..."
        Timestamp = Get-Date
    }
}
$ModuleStats["Network Analysis"] = $multipleIPs.Count

# Module 6: Application Analysis - New Apps
Write-Host "`n📌 Module 6: Application Analysis (New Apps)" -ForegroundColor Magenta
$appQuery = @"
let baseline_apps = SigninLogs
| where TimeGenerated between (ago(${BaselineDays}d) .. ago(${DetectionDays}d))
| where ResultType == "0"
| summarize by UserPrincipalName, AppDisplayName;
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| distinct UserPrincipalName, AppDisplayName
| join kind=leftanti baseline_apps on UserPrincipalName, AppDisplayName
| summarize NewAppCount = count(), Apps = make_set(AppDisplayName) by UserPrincipalName
| order by NewAppCount desc
"@
$newApps = Invoke-McpQuery -Query $appQuery -Description "Detecting new application access"
$newApps | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Application Analysis"
        Severity = if ($_.NewAppCount -gt 10) { "High" } else { "Low" }
        User = $_.UserPrincipalName
        Description = "User accessed $($_.NewAppCount) new application(s)"
        Details = "Apps: $($_.Apps -join ', ')"
        Timestamp = Get-Date
    }
}
$ModuleStats["Application Analysis"] = $newApps.Count

# Module 7: Risk Analysis - Risky Sign-Ins
Write-Host "`n📌 Module 7: Risk Analysis (Risky Sign-Ins)" -ForegroundColor Magenta
$riskQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where RiskLevelDuringSignIn in ("high", "medium")
| summarize 
    RiskySignIns = count(),
    RiskLevels = make_set(RiskLevelDuringSignIn),
    LastRisky = max(TimeGenerated)
    by UserPrincipalName
| order by RiskySignIns desc
"@
$riskySignIns = Invoke-McpQuery -Query $riskQuery -Description "Finding risky sign-in events"
$riskySignIns | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Risk Analysis"
        Severity = "High"
        User = $_.UserPrincipalName
        Description = "User had $($_.RiskySignIns) risky sign-in(s)"
        Details = "Risk levels: $($_.RiskLevels -join ', '), Last: $($_.LastRisky)"
        Timestamp = $_.LastRisky
    }
}
$ModuleStats["Risk Analysis"] = $riskySignIns.Count

# Module 8: Authentication Policy - MFA Changes
Write-Host "`n📌 Module 8: Authentication Policy (MFA)" -ForegroundColor Magenta
$mfaQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| summarize 
    TotalSignIns = count(),
    MFARequired = countif(AuthenticationRequirement == "multiFactorAuthentication"),
    NoMFA = countif(AuthenticationRequirement != "multiFactorAuthentication")
    by UserPrincipalName
| where NoMFA > 0
| extend MFARatio = round(todouble(NoMFA) / TotalSignIns * 100, 2)
| where MFARatio > 20
| order by NoMFA desc
"@
$mfaIssues = Invoke-McpQuery -Query $mfaQuery -Description "Analyzing MFA compliance"
$mfaIssues | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Authentication Policy"
        Severity = "Medium"
        User = $_.UserPrincipalName
        Description = "$($_.MFARatio)% of sign-ins bypassed MFA ($($_.NoMFA) events)"
        Details = "Total sign-ins: $($_.TotalSignIns), MFA required: $($_.MFARequired)"
        Timestamp = Get-Date
    }
}
$ModuleStats["Authentication Policy"] = $mfaIssues.Count

# Module 9: Device Analysis - Multiple Devices
Write-Host "`n📌 Module 9: Device Analysis (Multiple Devices)" -ForegroundColor Magenta
$deviceQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| where DeviceDetail_deviceId != ""
| summarize DeviceCount = dcount(DeviceDetail_deviceId) by UserPrincipalName
| where DeviceCount > 5
| order by DeviceCount desc
"@
$multipleDevices = Invoke-McpQuery -Query $deviceQuery -Description "Finding users with many devices"
$multipleDevices | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Device Analysis"
        Severity = if ($_.DeviceCount -gt 10) { "High" } else { "Low" }
        User = $_.UserPrincipalName
        Description = "User accessed from $($_.DeviceCount) different device(s)"
        Details = "Device count: $($_.DeviceCount)"
        Timestamp = Get-Date
    }
}
$ModuleStats["Device Analysis"] = $multipleDevices.Count

# Module 10: Conditional Access Violations
Write-Host "`n📌 Module 10: Conditional Access Analysis" -ForegroundColor Magenta
$caQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| mv-expand ConditionalAccessPolicies
| where ConditionalAccessPolicies.result == "failure"
| summarize 
    Violations = count(),
    Policies = make_set(ConditionalAccessPolicies.displayName)
    by UserPrincipalName
| order by Violations desc
"@
$caViolations = Invoke-McpQuery -Query $caQuery -Description "Checking CA policy violations"
$caViolations | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Conditional Access"
        Severity = "High"
        User = $_.UserPrincipalName
        Description = "User violated conditional access policies $($_.Violations) time(s)"
        Details = "Policies: $($_.Policies -join ', ')"
        Timestamp = Get-Date
    }
}
$ModuleStats["Conditional Access"] = $caViolations.Count

# Module 11: Behavior Analysis - User Agents
Write-Host "`n📌 Module 11: Behavior Analysis (User Agents)" -ForegroundColor Magenta
$uaQuery = @"
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| extend IsAutomated = case(
    UserAgent contains "PowerShell" or UserAgent contains "python" or UserAgent contains "curl" or UserAgent contains "wget", true,
    false
)
| where IsAutomated == true
| summarize AutomatedSignIns = count(), Agents = make_set(UserAgent) by UserPrincipalName
| order by AutomatedSignIns desc
"@
$automatedAccess = Invoke-McpQuery -Query $uaQuery -Description "Detecting automated access patterns"
$automatedAccess | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Behavior Analysis"
        Severity = if ($_.AutomatedSignIns -gt 100) { "Medium" } else { "Low" }
        User = $_.UserPrincipalName
        Description = "User had $($_.AutomatedSignIns) automated/scripted access event(s)"
        Details = "Agents: $($_.Agents[0..1] -join ', ')"
        Timestamp = Get-Date
    }
}
$ModuleStats["Behavior Analysis"] = $automatedAccess.Count

# Module 12: Baseline Comparison - Statistical Anomalies
Write-Host "`n📌 Module 12: Baseline Comparison (Statistical Anomalies)" -ForegroundColor Magenta
$baselineCompareQuery = @"
let baseline = SigninLogs
| where TimeGenerated between (ago(${BaselineDays}d) .. ago(${DetectionDays}d))
| where ResultType == "0"
| summarize BaselineLogins = count() by UserPrincipalName;
SigninLogs
| where TimeGenerated > ago(${DetectionDays}d)
| where ResultType == "0"
| summarize CurrentLogins = count() by UserPrincipalName
| join kind=inner baseline on UserPrincipalName
| extend PercentChange = round((todouble(CurrentLogins) - BaselineLogins) / BaselineLogins * 100, 2)
| where PercentChange > 200
| order by PercentChange desc
"@
$baselineAnomalies = Invoke-McpQuery -Query $baselineCompareQuery -Description "Comparing against baseline"
$baselineAnomalies | ForEach-Object {
    $AllAnomalies += [PSCustomObject]@{
        Module = "Baseline Comparison"
        Severity = if ($_.PercentChange -gt 1000) { "Critical" } elseif ($_.PercentChange -gt 500) { "High" } else { "Medium" }
        User = $_.UserPrincipalName
        Description = "Activity increased by $($_.PercentChange)% vs baseline"
        Details = "Current: $($_.CurrentLogins) logins, Baseline: $($_.BaselineLogins)"
        Timestamp = Get-Date
    }
}
$ModuleStats["Baseline Comparison"] = $baselineAnomalies.Count

# Summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    DETECTION SUMMARY                         ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

$TotalAnomalies = $AllAnomalies.Count
Write-Host "  Total Anomalies Detected: $TotalAnomalies" -ForegroundColor Cyan

foreach ($module in $ModuleStats.Keys | Sort-Object) {
    $count = $ModuleStats[$module]
    if ($count -gt 0) {
        Write-Host "    • $module : $count" -ForegroundColor Yellow
    }
}

# Generate Reports
if ($TotalAnomalies -gt 0) {
    Write-Host "`n[PHASE 3] Generating Reports..." -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Gray
    
    # JSON Report
    $jsonPath = Join-Path $ReportDir "comprehensive-report-$Timestamp.json"
    @{
        Timestamp = Get-Date -Format "o"
        BaselineDays = $BaselineDays
        DetectionDays = $DetectionDays
        TotalAnomalies = $TotalAnomalies
        DetectionModules = $ModuleStats
        Anomalies = $AllAnomalies
    } | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
    Write-Host "  ✓ JSON: $jsonPath" -ForegroundColor Green
    
    # CSV Report
    $csvPath = Join-Path $ReportDir "comprehensive-report-$Timestamp.csv"
    $AllAnomalies | Export-Csv $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "  ✓ CSV: $csvPath" -ForegroundColor Green
    
    Write-Host "`n✅ Detection complete! Reports generated." -ForegroundColor Green
    Write-Host "   Run Generate-ComprehensiveReport.ps1 to create HTML report" -ForegroundColor Yellow
}
else {
    Write-Host "`n✅ No anomalies detected (clean scan)" -ForegroundColor Green
}

Write-Host ""
