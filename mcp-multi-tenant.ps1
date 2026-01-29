<#
.SYNOPSIS
    Multi-Tenant MCP Connection Manager
.DESCRIPTION
    Manages connections to multiple Sentinel MCP servers simultaneously
.PARAMETER Status
    Check status of all configured tenants
.PARAMETER Refresh
    Refresh all tenant tokens
.EXAMPLE
    .\mcp-multi-tenant.ps1
    .\mcp-multi-tenant.ps1 -Status
    .\mcp-multi-tenant.ps1 -Refresh
#>

param(
    [switch]$Status,
    [switch]$Refresh
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        MULTI-TENANT MCP CONNECTION MANAGER                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Load environment configuration
if (!(Test-Path "mcp-environments.json")) {
    Write-Host "❌ mcp-environments.json not found" -ForegroundColor Red
    Write-Host "   Run: .\mcp-env.ps1 add" -ForegroundColor Yellow
    exit 1
}

$environments = Get-Content "mcp-environments.json" | ConvertFrom-Json

if ($environments.environments.Count -eq 0) {
    Write-Host "⚠️  No environments configured" -ForegroundColor Yellow
    Write-Host "   Run: .\mcp-env.ps1 add" -ForegroundColor Yellow
    exit 0
}

# Status check
if ($Status) {
    Write-Host "📊 Configured Tenants:" -ForegroundColor Cyan
    foreach ($env in $environments.environments) {
        Write-Host "`n  • $($env.name)" -ForegroundColor Yellow
        Write-Host "    Tenant ID: $($env.tenantId)" -ForegroundColor Gray
        Write-Host "    Workspace: $($env.workspaceId)" -ForegroundColor Gray
        Write-Host "    Account: $($env.account)" -ForegroundColor Gray
    }
    
    if (Test-Path "mcp.json") {
        $mcpConfig = Get-Content "mcp.json" | ConvertFrom-Json
        $servers = $mcpConfig.mcpServers | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        Write-Host "`n✓ Active MCP Servers: $($servers -join ', ')" -ForegroundColor Green
    }
    
    Write-Host ""
    exit 0
}

# Refresh all tokens
if ($Refresh) {
    Write-Host "🔄 Refreshing all tenant tokens..." -ForegroundColor Yellow
    
    foreach ($env in $environments.environments) {
        Write-Host "`n  Refreshing $($env.name)..." -NoNewline
        & .\mcp-env.ps1 use $env.name -ErrorAction SilentlyContinue
        if ($?) {
            Write-Host " ✓" -ForegroundColor Green
        }
        else {
            Write-Host " ❌" -ForegroundColor Red
        }
    }
    
    Write-Host "`n✅ Token refresh complete`n" -ForegroundColor Green
    exit 0
}

# Activate multi-tenant mode
Write-Host "🔗 Activating multi-tenant connections..." -ForegroundColor Yellow

$mcpServers = @{}

foreach ($env in $environments.environments) {
    Write-Host "`n  Connecting to $($env.name)..." -NoNewline
    
    # Login to tenant
    $null = az login --tenant $env.tenantId --allow-no-subscriptions 2>&1
    
    # Get access token
    $tokenResult = az account get-access-token --resource "4500ebfb-89b6-4b14-a480-7f749797bfcd" --query accessToken -o tsv 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $serverKey = "mcp-$($env.name.ToLower() -replace '[^a-z0-9]', '')"
        
        $mcpServers[$serverKey] = @{
            url = "https://sentinel.microsoft.com/mcp"
            headers = @{
                "Authorization" = "Bearer $tokenResult"
                "X-Workspace-Id" = $env.workspaceId
                "X-Tenant-Id" = $env.tenantId
            }
            description = "$($env.name) - $($env.account)"
        }
        
        Write-Host " ✓" -ForegroundColor Green
    }
    else {
        Write-Host " ❌" -ForegroundColor Red
    }
}

# Save to mcp.json
$mcpConfig = @{
    mcpServers = $mcpServers
}

$mcpConfig | ConvertTo-Json -Depth 10 | Out-File "mcp.json" -Encoding UTF8

Write-Host "`n✅ Multi-tenant MCP configuration active!" -ForegroundColor Green
Write-Host "   Servers: $($mcpServers.Keys -join ', ')" -ForegroundColor Cyan
Write-Host "   Configuration: mcp.json`n" -ForegroundColor Gray
