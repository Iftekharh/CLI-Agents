<#
.SYNOPSIS
    Cross-Tenant Correlation Engine for Microsoft Sentinel
.DESCRIPTION
    Analyzes security events across multiple tenants to detect coordinated attacks
.EXAMPLE
    .\Cross-Tenant-Correlation.ps1
#>

param(
    [int]$Days = 7
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         CROSS-TENANT CORRELATION ANALYSIS ENGINE             ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Load MCP configuration
if (!(Test-Path "mcp.json")) {
    Write-Host "❌ mcp.json not found. Run: .\mcp-multi-tenant.ps1" -ForegroundColor Red
    exit 1
}

$McpConfig = Get-Content "mcp.json" | ConvertFrom-Json
$Servers = $McpConfig.mcpServers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

if ($Servers.Count -lt 2) {
    Write-Host "⚠️  Only one tenant configured. Cross-tenant analysis requires 2+ tenants." -ForegroundColor Yellow
    Write-Host "   Current tenants: $($Servers -join ', ')" -ForegroundColor Gray
    exit 0
}

Write-Host "📊 Analyzing across tenants: $($Servers -join ', ')" -ForegroundColor Cyan
Write-Host "   Time window: Last $Days days`n" -ForegroundColor Gray

# MCP Query Function
function Invoke-TenantQuery {
    param([string]$TenantKey, [string]$Query, [string]$Description)
    
    $BearerToken = $McpConfig.mcpServers.$TenantKey.headers.Authorization -replace "^Bearer ", ""
    
    Write-Host "  🔍 [$TenantKey] $Description..." -NoNewline
    
    $body = @{ query = $Query } | ConvertTo-Json -Depth 10
    
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
        
        $content = $response.Content
        if ($content -match 'data: ({.*})') {
            $jsonData = $matches[1] | ConvertFrom-Json
            
            if ($jsonData.frames -and $jsonData.frames.Count -gt 0) {
                $primaryFrame = $jsonData.frames | Where-Object { $_.schema.name -eq "PrimaryResult" } | Select-Object -First 1
                
                if ($primaryFrame -and $primaryFrame.data.values) {
                    $columnNames = $primaryFrame.schema.columns.name
                    $rows = @()
                    
                    foreach ($rowData in $primaryFrame.data.values) {
                        $row = @{ Tenant = $TenantKey }
                        for ($i = 0; $i -lt $columnNames.Count; $i++) {
                            $row[$columnNames[$i]] = $rowData[$i]
                        }
                        $rows += [PSCustomObject]$row
                    }
                    
                    Write-Host " ✓ ($($rows.Count))" -ForegroundColor Green
                    return $rows
                }
            }
        }
        
        Write-Host " (0)" -ForegroundColor Gray
        return @()
    }
    catch {
        Write-Host " ❌" -ForegroundColor Red
        return @()
    }
}

$Findings = @()

# Correlation 1: Shared IP Addresses
Write-Host "`n📌 Correlation 1: Shared IP Addresses Across Tenants" -ForegroundColor Magenta
$ipQuery = @"
SigninLogs
| where TimeGenerated > ago(${Days}d)
| where ResultType == "0"
| summarize 
    UserCount = dcount(UserPrincipalName),
    Users = make_set(UserPrincipalName),
    FirstSeen = min(TimeGenerated),
    LastSeen = max(TimeGenerated)
    by IPAddress, Location
| where UserCount > 1
| order by UserCount desc
"@

$AllIPs = @()
foreach ($tenant in $Servers) {
    $result = Invoke-TenantQuery -TenantKey $tenant -Query $ipQuery -Description "Collecting IP data"
    $AllIPs += $result
}

$SharedIPs = $AllIPs | Group-Object IPAddress | Where-Object { $_.Count -gt 1 }
foreach ($ip in $SharedIPs) {
    $tenants = ($ip.Group | Select-Object -ExpandProperty Tenant -Unique) -join ', '
    $Findings += [PSCustomObject]@{
        Type = "Shared IP Address"
        Severity = "High"
        Description = "IP $($ip.Name) used across multiple tenants"
        Details = "Tenants: $tenants, Users: $($ip.Group[0].UserCount + $ip.Group[1].UserCount)"
        Timestamp = Get-Date
    }
}

# Correlation 2: Coordinated Failed Logins
Write-Host "`n📌 Correlation 2: Coordinated Failed Login Attempts" -ForegroundColor Magenta
$failQuery = @"
SigninLogs
| where TimeGenerated > ago(${Days}d)
| where ResultType != "0"
| summarize FailCount = count() by bin(TimeGenerated, 1h), IPAddress
| where FailCount > 10
| order by TimeGenerated desc
"@

$AllFailures = @()
foreach ($tenant in $Servers) {
    $result = Invoke-TenantQuery -TenantKey $tenant -Query $failQuery -Description "Analyzing failed logins"
    $AllFailures += $result
}

$CoordinatedFails = $AllFailures | Group-Object IPAddress | Where-Object { $_.Count -gt 1 }
foreach ($fail in $CoordinatedFails) {
    $tenants = ($fail.Group | Select-Object -ExpandProperty Tenant -Unique) -join ', '
    $Findings += [PSCustomObject]@{
        Type = "Coordinated Brute Force"
        Severity = "Critical"
        Description = "IP $($fail.Name) launched brute force across tenants"
        Details = "Tenants: $tenants, Total failures: $($fail.Group | Measure-Object -Property FailCount -Sum | Select-Object -ExpandProperty Sum)"
        Timestamp = Get-Date
    }
}

# Correlation 3: Cross-Tenant User Activity
Write-Host "`n📌 Correlation 3: Cross-Tenant User Activity" -ForegroundColor Magenta
$userQuery = @"
SigninLogs
| where TimeGenerated > ago(${Days}d)
| where ResultType == "0"
| summarize 
    LoginCount = count(),
    FirstSeen = min(TimeGenerated),
    LastSeen = max(TimeGenerated)
    by UserPrincipalName
| order by LoginCount desc
| take 100
"@

$AllUsers = @()
foreach ($tenant in $Servers) {
    $result = Invoke-TenantQuery -TenantKey $tenant -Query $userQuery -Description "Tracking user activity"
    $AllUsers += $result
}

$CrossTenantUsers = $AllUsers | Group-Object UserPrincipalName | Where-Object { $_.Count -gt 1 }
foreach ($user in $CrossTenantUsers) {
    $tenants = ($user.Group | Select-Object -ExpandProperty Tenant -Unique) -join ', '
    $Findings += [PSCustomObject]@{
        Type = "Cross-Tenant Access"
        Severity = "Medium"
        Description = "User $($user.Name) active in multiple tenants"
        Details = "Tenants: $tenants, Total logins: $($user.Group | Measure-Object -Property LoginCount -Sum | Select-Object -ExpandProperty Sum)"
        Timestamp = Get-Date
    }
}

# Correlation 4: Time-Based Pattern Correlation
Write-Host "`n📌 Correlation 4: Time Pattern Correlation" -ForegroundColor Magenta
$timeQuery = @"
SigninLogs
| where TimeGenerated > ago(${Days}d)
| extend Hour = datetime_part('hour', TimeGenerated)
| where Hour >= 0 and Hour < 6
| summarize OffHoursCount = count() by bin(TimeGenerated, 1h)
| where OffHoursCount > 50
| order by TimeGenerated desc
"@

$AllTimePatterns = @()
foreach ($tenant in $Servers) {
    $result = Invoke-TenantQuery -TenantKey $tenant -Query $timeQuery -Description "Analyzing time patterns"
    $AllTimePatterns += $result
}

$SimilarPatterns = $AllTimePatterns | Group-Object TimeGenerated | Where-Object { $_.Count -gt 1 }
foreach ($pattern in $SimilarPatterns) {
    $tenants = ($pattern.Group | Select-Object -ExpandProperty Tenant -Unique) -join ', '
    $Findings += [PSCustomObject]@{
        Type = "Synchronized Activity"
        Severity = "High"
        Description = "Off-hours activity spike at $($pattern.Name)"
        Details = "Tenants: $tenants, Total events: $($pattern.Group | Measure-Object -Property OffHoursCount -Sum | Select-Object -ExpandProperty Sum)"
        Timestamp = $pattern.Name
    }
}

# Summary
Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              CROSS-TENANT CORRELATION SUMMARY                ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "  Total Findings: $($Findings.Count)" -ForegroundColor Cyan

$FindingsByType = $Findings | Group-Object Type
foreach ($type in $FindingsByType) {
    Write-Host "    • $($type.Name): $($type.Count)" -ForegroundColor Yellow
}

# Generate Report
if ($Findings.Count -gt 0) {
    $ReportDir = ".\reports"
    if (!(Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null }
    
    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $jsonPath = Join-Path $ReportDir "cross-tenant-correlation-$Timestamp.json"
    
    @{
        Timestamp = Get-Date -Format "o"
        Tenants = $Servers
        Days = $Days
        TotalFindings = $Findings.Count
        Findings = $Findings
    } | ConvertTo-Json -Depth 10 | Out-File $jsonPath -Encoding UTF8
    
    Write-Host "`n  ✓ Report: $jsonPath" -ForegroundColor Green
}

Write-Host ""
