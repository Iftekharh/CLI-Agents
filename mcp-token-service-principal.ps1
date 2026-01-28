# Service Principal Token Automation Script
# Use this if you have a Service Principal (App Registration) configured

param(
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$Resource,  # The resource/scope you're accessing
    
    [string]$McpConfigPath = "C:\App\loop\mcp.json",
    [int]$RefreshIntervalMinutes = 45
)

$ErrorActionPreference = "Stop"

# Function to get token using Service Principal (Client Credentials Flow)
function Get-ServicePrincipalToken {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$Resource
    )
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Requesting token using Service Principal..." -ForegroundColor Cyan
    
    try {
        $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
        
        $body = @{
            client_id     = $ClientId
            scope         = "$Resource/.default"
            client_secret = $ClientSecret
            grant_type    = "client_credentials"
        }
        
        $response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Token obtained successfully" -ForegroundColor Green
        
        return $response.access_token
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $_" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $null
    }
}

# Function to update mcp.json
function Update-McpConfig {
    param(
        [string]$ConfigPath,
        [string]$NewToken
    )
    
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Updating $ConfigPath..." -ForegroundColor Cyan
    
    try {
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        $config.servers.'mcp-sentinel'.headers.Authorization = "Bearer $NewToken"
        $config | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ Config updated successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ERROR: $_" -ForegroundColor Red
        return $false
    }
}

# Main loop
Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  MCP Service Principal Token Manager" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Tenant: $TenantId" -ForegroundColor Gray
Write-Host "Client: $ClientId" -ForegroundColor Gray
Write-Host "Resource: $Resource" -ForegroundColor Gray
Write-Host ""

$iteration = 0
while ($true) {
    $iteration++
    Write-Host "`n[Iteration #$iteration] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Magenta
    
    # Get token
    $token = Get-ServicePrincipalToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -Resource $Resource
    
    if ($null -ne $token) {
        # Update config
        $success = Update-McpConfig -ConfigPath $McpConfigPath -NewToken $token
        
        if ($success) {
            $nextRefresh = (Get-Date).AddMinutes($RefreshIntervalMinutes)
            Write-Host "`nNext refresh: $($nextRefresh.ToString('HH:mm:ss'))" -ForegroundColor Yellow
            Write-Host "Sleeping for $RefreshIntervalMinutes minutes...`n" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "Token acquisition failed. Retrying in 5 minutes..." -ForegroundColor Red
        Start-Sleep -Seconds 300
        continue
    }
    
    # Sleep until next refresh
    Start-Sleep -Seconds ($RefreshIntervalMinutes * 60)
}
