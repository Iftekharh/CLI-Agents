# MCP Environment Manager
# Easily switch between different MCP server environments

param(
    [Parameter(Position=0)]
    [string]$Command,
    
    [Parameter(Position=1)]
    [string]$EnvironmentName,
    
    [string]$ConfigPath = "C:\App\loop\mcp-environments.json",
    [string]$McpConfigPath = "C:\App\loop\mcp.json"
)

$ErrorActionPreference = "Stop"

# Load environment configuration
function Get-EnvironmentConfig {
    if (Test-Path $ConfigPath) {
        return Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } else {
        Write-Host "ERROR: Configuration file not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }
}

# Save environment configuration
function Save-EnvironmentConfig {
    param($Config)
    $Config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
}

# Get token for environment
function Get-EnvironmentToken {
    param($Environment)
    
    Write-Host "Getting token for $($Environment.displayName)..." -ForegroundColor Cyan
    
    try {
        $token = az account get-access-token `
            --resource $Environment.resourceId `
            --tenant $Environment.tenantId `
            --query accessToken -o tsv
        
        if ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrEmpty($token)) {
            return $token
        } else {
            Write-Host "WARNING: Failed to get token automatically" -ForegroundColor Yellow
            Write-Host "You may need to run: az login --tenant $($Environment.tenantId)" -ForegroundColor Gray
            return $null
        }
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        return $null
    }
}

# Update mcp.json with environment
function Update-McpConfig {
    param($Environment, $Token)
    
    $mcpConfig = @{
        servers = @{
            "mcp-sentinel" = @{
                url = $Environment.mcpServerUrl
                type = "http"
                headers = @{
                    Authorization = "Bearer $Token"
                }
            }
        }
        inputs = @()
    }
    
    $mcpConfig | ConvertTo-Json -Depth 10 | Set-Content $McpConfigPath -Encoding UTF8
    Write-Host "✓ mcp.json updated for $($Environment.displayName)" -ForegroundColor Green
}

# Display environment info
function Show-EnvironmentInfo {
    param($Config, $EnvName)
    
    $env = $Config.environments.$EnvName
    
    Write-Host ""
    Write-Host "┌─────────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
    Write-Host "│ ENVIRONMENT: " -NoNewline -ForegroundColor Cyan
    Write-Host $env.displayName.PadRight(48) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────────────────────────────────┤" -ForegroundColor Cyan
    Write-Host "│ Tenant ID:       " -NoNewline -ForegroundColor Gray
    Write-Host $env.tenantId.PadRight(44) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│ Resource ID:     " -NoNewline -ForegroundColor Gray
    Write-Host $env.resourceId.PadRight(44) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor Cyan
    Write-Host "│ MCP Server:      " -NoNewline -ForegroundColor Gray
    $url = $env.mcpServerUrl
    if ($url.Length -gt 44) { $url = $url.Substring(0, 41) + "..." }
    Write-Host $url.PadRight(44) -NoNewline -ForegroundColor White
    Write-Host "│" -ForegroundColor Cyan
    if ($env.workspaceId) {
        Write-Host "│ Workspace ID:    " -NoNewline -ForegroundColor Gray
        Write-Host $env.workspaceId.PadRight(44) -NoNewline -ForegroundColor White
        Write-Host "│" -ForegroundColor Cyan
    }
    if ($env.description) {
        Write-Host "│ Description:     " -NoNewline -ForegroundColor Gray
        Write-Host $env.description.PadRight(44) -NoNewline -ForegroundColor White
        Write-Host "│" -ForegroundColor Cyan
    }
    Write-Host "└─────────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
}

# Main script logic
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           MCP ENVIRONMENT MANAGER                                 ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$config = Get-EnvironmentConfig

switch ($Command.ToLower()) {
    "list" {
        Write-Host "Available Environments:" -ForegroundColor Yellow
        Write-Host ""
        
        foreach ($envName in $config.environments.PSObject.Properties.Name) {
            $env = $config.environments.$envName
            $marker = if ($envName -eq $config.currentEnvironment) { "* " } else { "  " }
            $color = if ($envName -eq $config.currentEnvironment) { "Green" } else { "White" }
            
            Write-Host "$marker$envName" -NoNewline -ForegroundColor $color
            Write-Host " - $($env.displayName)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "Current: " -NoNewline -ForegroundColor Yellow
        Write-Host $config.currentEnvironment -ForegroundColor Green
    }
    
    "use" {
        if ([string]::IsNullOrEmpty($EnvironmentName)) {
            Write-Host "ERROR: Please specify environment name" -ForegroundColor Red
            Write-Host "Usage: .\mcp-env.ps1 use <environment-name>" -ForegroundColor Yellow
            exit 1
        }
        
        if (-not $config.environments.PSObject.Properties.Name.Contains($EnvironmentName)) {
            Write-Host "ERROR: Environment '$EnvironmentName' not found" -ForegroundColor Red
            Write-Host ""
            Write-Host "Available environments:" -ForegroundColor Yellow
            $config.environments.PSObject.Properties.Name | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
            exit 1
        }
        
        $env = $config.environments.$EnvironmentName
        
        Write-Host "Switching to environment: " -NoNewline -ForegroundColor Cyan
        Write-Host $env.displayName -ForegroundColor Green
        Write-Host ""
        
        # Get token
        $token = Get-EnvironmentToken -Environment $env
        
        if ($null -eq $token) {
            Write-Host ""
            Write-Host "Could not automatically obtain token." -ForegroundColor Yellow
            Write-Host "Please run: az login --tenant $($env.tenantId)" -ForegroundColor Gray
            exit 1
        }
        
        # Update mcp.json
        Update-McpConfig -Environment $env -Token $token
        
        # Update current environment
        $config.currentEnvironment = $EnvironmentName
        Save-EnvironmentConfig -Config $config
        
        Write-Host ""
        Write-Host "✓ Switched to $EnvironmentName" -ForegroundColor Green
        
        # Show info
        Show-EnvironmentInfo -Config $config -EnvName $EnvironmentName
        
        # Verify token
        Write-Host "Token Status:" -ForegroundColor Yellow
        .\decode-token.ps1 -McpConfigPath $McpConfigPath
    }
    
    "current" {
        $currentEnv = $config.currentEnvironment
        Write-Host "Current Environment: " -NoNewline -ForegroundColor Yellow
        Write-Host $currentEnv -ForegroundColor Green
        Write-Host ""
        
        Show-EnvironmentInfo -Config $config -EnvName $currentEnv
    }
    
    "add" {
        Write-Host "Adding new environment..." -ForegroundColor Cyan
        Write-Host ""
        
        $envName = Read-Host "Environment name (e.g., 'production', 'dev')"
        $displayName = Read-Host "Display name"
        $tenantId = Read-Host "Tenant ID"
        $resourceId = Read-Host "Resource ID"
        $mcpServerUrl = Read-Host "MCP Server URL"
        $workspaceId = Read-Host "Workspace ID (optional, press Enter to skip)"
        $description = Read-Host "Description (optional, press Enter to skip)"
        
        $newEnv = @{
            displayName = $displayName
            tenantId = $tenantId
            resourceId = $resourceId
            mcpServerUrl = $mcpServerUrl
            autoRefresh = $true
            refreshIntervalMinutes = 45
        }
        
        if (![string]::IsNullOrEmpty($workspaceId)) {
            $newEnv.workspaceId = $workspaceId
        }
        
        if (![string]::IsNullOrEmpty($description)) {
            $newEnv.description = $description
        }
        
        # Add to config
        $config.environments | Add-Member -NotePropertyName $envName -NotePropertyValue $newEnv -Force
        Save-EnvironmentConfig -Config $config
        
        Write-Host ""
        Write-Host "✓ Environment '$envName' added successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "To use this environment, run:" -ForegroundColor Yellow
        Write-Host "  .\mcp-env.ps1 use $envName" -ForegroundColor Gray
    }
    
    "info" {
        if ([string]::IsNullOrEmpty($EnvironmentName)) {
            $EnvironmentName = $config.currentEnvironment
        }
        
        if ($config.environments.PSObject.Properties.Name.Contains($EnvironmentName)) {
            Show-EnvironmentInfo -Config $config -EnvName $EnvironmentName
        } else {
            Write-Host "ERROR: Environment '$EnvironmentName' not found" -ForegroundColor Red
        }
    }
    
    "refresh" {
        $envName = if ([string]::IsNullOrEmpty($EnvironmentName)) { $config.currentEnvironment } else { $EnvironmentName }
        $env = $config.environments.$envName
        
        Write-Host "Refreshing token for: " -NoNewline -ForegroundColor Cyan
        Write-Host $env.displayName -ForegroundColor Green
        Write-Host ""
        
        $token = Get-EnvironmentToken -Environment $env
        
        if ($null -ne $token) {
            Update-McpConfig -Environment $env -Token $token
            Write-Host ""
            Write-Host "✓ Token refreshed successfully" -ForegroundColor Green
            Write-Host ""
            .\decode-token.ps1 -McpConfigPath $McpConfigPath
        }
    }
    
    default {
        Write-Host "MCP Environment Manager" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\mcp-env.ps1 list                    - List all environments" -ForegroundColor White
        Write-Host "  .\mcp-env.ps1 use <name>              - Switch to environment" -ForegroundColor White
        Write-Host "  .\mcp-env.ps1 current                 - Show current environment" -ForegroundColor White
        Write-Host "  .\mcp-env.ps1 info [name]             - Show environment details" -ForegroundColor White
        Write-Host "  .\mcp-env.ps1 add                     - Add new environment" -ForegroundColor White
        Write-Host "  .\mcp-env.ps1 refresh [name]          - Refresh token for environment" -ForegroundColor White
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\mcp-env.ps1 list" -ForegroundColor Gray
        Write-Host "  .\mcp-env.ps1 use woodgrove" -ForegroundColor Gray
        Write-Host "  .\mcp-env.ps1 current" -ForegroundColor Gray
        Write-Host ""
        
        if ($null -ne $config.currentEnvironment) {
            Write-Host "Current environment: " -NoNewline -ForegroundColor Yellow
            Write-Host $config.currentEnvironment -ForegroundColor Green
        }
    }
}

Write-Host ""
