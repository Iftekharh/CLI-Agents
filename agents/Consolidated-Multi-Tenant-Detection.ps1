<#
.SYNOPSIS
    Consolidated Multi-Tenant Detection Framework
.DESCRIPTION
    Unified detection engine that runs across all configured tenants
.EXAMPLE
    .\Consolidated-Multi-Tenant-Detection.ps1
#>

Write-Host "`n🌐 CONSOLIDATED MULTI-TENANT DETECTION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Ensure multi-tenant setup
& .\mcp-multi-tenant.ps1 -ErrorAction Stop

# Load MCP config
$mcpConfig = Get-Content "mcp.json" | ConvertFrom-Json
$servers = $mcpConfig.mcpServers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

Write-Host "📊 Running detection across $($servers.Count) tenants..." -ForegroundColor Yellow
Write-Host "   Tenants: $($servers -join ', ')`n" -ForegroundColor Gray

$allFindings = @()

foreach ($server in $servers) {
    Write-Host "  🔍 Scanning $server..." -ForegroundColor Cyan
    
    # Switch to this tenant
    $tenantName = $server -replace '^mcp-', ''
    & .\mcp-env.ps1 use $tenantName -ErrorAction SilentlyContinue
    
    # Run detection
    & .\agents\Comprehensive-Hunter.ps1
    
    # Collect results
    $latestReport = Get-ChildItem ".\reports\comprehensive-report-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($latestReport) {
        $report = Get-Content $latestReport.FullName | ConvertFrom-Json
        $report.Anomalies | ForEach-Object {
            $_ | Add-Member -NotePropertyName "Tenant" -NotePropertyValue $tenantName -Force
            $allFindings += $_
        }
    }
}

# Consolidated report
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$consolidatedPath = ".\reports\consolidated-multi-tenant-$timestamp.json"

@{
    Timestamp = Get-Date -Format "o"
    Tenants = $servers
    TotalFindings = $allFindings.Count
    Findings = $allFindings
} | ConvertTo-Json -Depth 10 | Out-File $consolidatedPath -Encoding UTF8

Write-Host "`n✅ Consolidated scan complete!" -ForegroundColor Green
Write-Host "   Total findings: $($allFindings.Count)" -ForegroundColor Cyan
Write-Host "   Report: $consolidatedPath`n" -ForegroundColor Gray
