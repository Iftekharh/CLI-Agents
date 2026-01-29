<#
.SYNOPSIS
    Simple Anomaly Hunter - Streamlined Version
.DESCRIPTION
    Simplified anomaly detection with essential modules only
.EXAMPLE
    .\Simple-AnomalyHunter.ps1
#>

param([int]$Days = 7)

Write-Host "`n🔍 Simple Anomaly Hunter" -ForegroundColor Cyan
Write-Host "════════════════════════════`n" -ForegroundColor Cyan

$McpConfig = Get-Content "mcp.json" | ConvertFrom-Json
$ServerName = ($McpConfig.mcpServers | Get-Member -MemberType NoteProperty | Select-Object -First 1).Name
$BearerToken = $McpConfig.mcpServers.$ServerName.headers.Authorization -replace "^Bearer ", ""

function Invoke-McpQuery {
    param([string]$Query)
    
    $body = @{ query = $Query } | ConvertTo-Json
    $response = Invoke-WebRequest -Uri "https://sentinel.microsoft.com/mcp/data-exploration" `
        -Method POST `
        -Headers @{
            "Authorization" = "Bearer $BearerToken"
            "Content-Type" = "application/json"
            "Accept" = "application/json, text/event-stream"
        } `
        -Body $body `
        -UseBasicParsing
    
    if ($response.Content -match 'data: ({.*})') {
        $jsonData = $matches[1] | ConvertFrom-Json
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
            return $rows
        }
    }
    return @()
}

# Failed Logins
Write-Host "🔎 Checking failed logins..." -ForegroundColor Yellow
$failedQuery = "SigninLogs | where TimeGenerated > ago(${Days}d) | where ResultType != '0' | summarize FailCount = count() by UserPrincipalName | where FailCount > 10 | order by FailCount desc"
$failed = Invoke-McpQuery -Query $failedQuery
Write-Host "  Found: $($failed.Count) users with excessive failures" -ForegroundColor $(if ($failed.Count -gt 0) { "Red" } else { "Green" })

# Off-Hours Activity
Write-Host "🔎 Checking off-hours activity..." -ForegroundColor Yellow
$offHoursQuery = "SigninLogs | where TimeGenerated > ago(${Days}d) | extend Hour = datetime_part('hour', TimeGenerated) | where Hour >= 0 and Hour < 6 | summarize Count = count() by UserPrincipalName | where Count > 20 | order by Count desc"
$offHours = Invoke-McpQuery -Query $offHoursQuery
Write-Host "  Found: $($offHours.Count) users with off-hours patterns" -ForegroundColor $(if ($offHours.Count -gt 0) { "Yellow" } else { "Green" })

# New Locations
Write-Host "🔎 Checking new locations..." -ForegroundColor Yellow
$locationQuery = "SigninLogs | where TimeGenerated > ago(${Days}d) | summarize Locations = dcount(Location) by UserPrincipalName | where Locations > 3 | order by Locations desc"
$locations = Invoke-McpQuery -Query $locationQuery
Write-Host "  Found: $($locations.Count) users accessing from multiple locations" -ForegroundColor $(if ($locations.Count -gt 0) { "Yellow" } else { "Green" })

Write-Host "`n✅ Simple scan complete!" -ForegroundColor Green
Write-Host "   Total issues: $(($failed.Count + $offHours.Count + $locations.Count))`n" -ForegroundColor Cyan
