# MCP Token Auto-Refresh Script
# This script automatically refreshes the Azure AD token and updates mcp.json

param(
    [string]$McpConfigPath = "C:\App\loop\mcp.json",
    [string]$TenantId = "536279f6-15cc-45f2-be2d-61e352b51eef",
    [string]$ClientId = "4500ebfb-89b6-4b14-a480-7f74979bfcd",  # Your app/resource ID
    [int]$RefreshIntervalMinutes = 45,  # Refresh 15 min before 1-hour expiry
    [switch]$RunOnce,
    [switch]$RunAsService
)

$ErrorActionPreference = "Stop"

# Function to get token using Azure CLI
function Get-AzureToken {
    param([string]$Resource)
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Getting new token..." -ForegroundColor Cyan
    
    try {
        # Use Azure CLI to get token
        $tokenJson = az account get-access-token --resource $Resource --query accessToken -o tsv
        
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($tokenJson)) {
            throw "Failed to get token from Azure CLI"
        }
        
        return $tokenJson.Trim()
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $_" -ForegroundColor Red
        return $null
    }
}

# Function to decode JWT and check expiry
function Get-TokenExpiry {
    param([string]$Token)
    
    try {
        $parts = $Token.Split('.')
        if ($parts.Count -lt 2) { return $null }
        
        # Decode base64 payload
        $payload = $parts[1]
        # Add padding if needed
        while ($payload.Length % 4 -ne 0) { $payload += "=" }
        
        $bytes = [Convert]::FromBase64String($payload)
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        $data = $json | ConvertFrom-Json
        
        # Convert Unix timestamp to DateTime
        $expiry = [DateTimeOffset]::FromUnixTimeSeconds($data.exp).LocalDateTime
        return $expiry
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] WARNING: Could not parse token expiry" -ForegroundColor Yellow
        return $null
    }
}

# Function to update mcp.json with new token
function Update-McpConfig {
    param(
        [string]$ConfigPath,
        [string]$NewToken
    )
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Updating $ConfigPath..." -ForegroundColor Cyan
    
    try {
        # Read existing config
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        
        # Update the token
        $config.servers.'mcp-sentinel'.headers.Authorization = "Bearer $NewToken"
        
        # Write back to file
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Token updated successfully" -ForegroundColor Green
        
        # Show expiry time
        $expiry = Get-TokenExpiry -Token $NewToken
        if ($expiry) {
            $timeUntilExpiry = $expiry - (Get-Date)
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Token expires at: $($expiry.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Time until expiry: $([math]::Floor($timeUntilExpiry.TotalMinutes)) minutes" -ForegroundColor Gray
        }
        
        return $true
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR updating config: $_" -ForegroundColor Red
        return $false
    }
}

# Main refresh logic
function Invoke-TokenRefresh {
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  MCP Token Auto-Refresh" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    
    # Get new token
    $token = Get-AzureToken -Resource $ClientId
    
    if ($null -eq $token) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✗ Failed to obtain token" -ForegroundColor Red
        return $false
    }
    
    # Update config file
    $success = Update-McpConfig -ConfigPath $McpConfigPath -NewToken $token
    
    return $success
}

# Main execution
Write-Host "Starting MCP Token Auto-Refresh Service..." -ForegroundColor Green
Write-Host "Config: $McpConfigPath" -ForegroundColor Gray
Write-Host "Refresh Interval: $RefreshIntervalMinutes minutes" -ForegroundColor Gray
Write-Host ""

if ($RunOnce) {
    # Single refresh and exit
    Invoke-TokenRefresh
}
else {
    # Continuous monitoring mode
    Write-Host "Running in continuous mode. Press Ctrl+C to stop." -ForegroundColor Yellow
    Write-Host ""
    
    $iteration = 0
    while ($true) {
        $iteration++
        Write-Host "`n[Iteration #$iteration]" -ForegroundColor Magenta
        
        $success = Invoke-TokenRefresh
        
        if ($success) {
            $nextRefresh = (Get-Date).AddMinutes($RefreshIntervalMinutes)
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Next refresh at: $($nextRefresh.ToString('HH:mm:ss'))" -ForegroundColor Yellow
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Sleeping for $RefreshIntervalMinutes minutes..." -ForegroundColor Gray
        }
        else {
            Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Refresh failed, retrying in 5 minutes..." -ForegroundColor Red
            Start-Sleep -Seconds 300
            continue
        }
        
        # Sleep until next refresh
        Start-Sleep -Seconds ($RefreshIntervalMinutes * 60)
    }
}
