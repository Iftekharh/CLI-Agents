# Finding Azure Resource IDs for Token Generation

## Quick Answer

The resource ID `4500ebfb-89b6-4b14-a480-7f74979bfcd` came from decoding your existing JWT token's `aud` (audience) claim. Here's how to find resource IDs for any service:

---

## Method 1: Decode Your Existing Token (Easiest)

If you already have a working token, decode it to find the resource ID.

### PowerShell Script

```powershell
function Get-ResourceIdFromToken {
    param([string]$Token)
    
    # Remove "Bearer " prefix if present
    $Token = $Token -replace "^Bearer\s+", ""
    
    # Split token into parts
    $parts = $Token.Split('.')
    if ($parts.Count -lt 2) {
        Write-Host "Invalid token format" -ForegroundColor Red
        return
    }
    
    # Decode the payload (second part)
    $payload = $parts[1]
    
    # Add padding if needed for base64
    while ($payload.Length % 4 -ne 0) {
        $payload += "="
    }
    
    # Decode base64
    $bytes = [Convert]::FromBase64String($payload)
    $json = [System.Text.Encoding]::UTF8.GetString($bytes)
    $data = $json | ConvertFrom-Json
    
    # Display key information
    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           TOKEN DECODED INFORMATION                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Resource ID (aud):  " -NoNewline -ForegroundColor Yellow
    Write-Host $data.aud -ForegroundColor White
    Write-Host "Tenant ID (tid):    " -NoNewline -ForegroundColor Yellow
    Write-Host $data.tid -ForegroundColor White
    Write-Host "Issuer:             " -NoNewline -ForegroundColor Yellow
    Write-Host $data.iss -ForegroundColor White
    Write-Host "App ID (azp):       " -NoNewline -ForegroundColor Yellow
    Write-Host $data.azp -ForegroundColor White
    Write-Host ""
    Write-Host "Issued At:          " -NoNewline -ForegroundColor Yellow
    Write-Host ([DateTimeOffset]::FromUnixTimeSeconds($data.iat).LocalDateTime) -ForegroundColor White
    Write-Host "Expires At:         " -NoNewline -ForegroundColor Yellow
    Write-Host ([DateTimeOffset]::FromUnixTimeSeconds($data.exp).LocalDateTime) -ForegroundColor White
    Write-Host ""
    
    return $data.aud
}

# Usage: Read token from mcp.json
$mcpConfig = Get-Content "C:\App\loop\mcp.json" | ConvertFrom-Json
$token = $mcpConfig.servers.'mcp-sentinel'.headers.Authorization -replace "^Bearer\s+", ""
$resourceId = Get-ResourceIdFromToken -Token $token

Write-Host "Use this Resource ID for token generation:" -ForegroundColor Green
Write-Host $resourceId -ForegroundColor Cyan
```

---

## Method 2: Use Azure CLI to Discover Resource IDs

Azure CLI can show you the resource ID when you request a token.

### Get Token and See Resource Info

```powershell
# Request token with verbose output
az account get-access-token --resource "https://sentinel.microsoft.com" --query "{accessToken:accessToken, expiresOn:expiresOn}" -o json

# The token will contain the resource ID in the 'aud' claim
```

### Common Microsoft Service Resource IDs

```powershell
# Microsoft Graph
az account get-access-token --resource "https://graph.microsoft.com"
# Resource ID: 00000003-0000-0000-c000-000000000000

# Azure Management
az account get-access-token --resource "https://management.azure.com"
# Resource ID: https://management.azure.com/

# Azure Key Vault
az account get-access-token --resource "https://vault.azure.net"
# Resource ID: https://vault.azure.net

# Azure Storage
az account get-access-token --resource "https://storage.azure.com"
# Resource ID: https://storage.azure.com/

# Power BI
az account get-access-token --resource "https://analysis.windows.net/powerbi/api"
# Resource ID: https://analysis.windows.net/powerbi/api

# Azure DevOps
az account get-access-token --resource "499b84ac-1321-427f-aa17-267ca6975798"
# Resource ID: 499b84ac-1321-427f-aa17-267ca6975798

# Microsoft Purview (Data Catalog)
az account get-access-token --resource "https://purview.azure.net"
# Resource ID: 73c2949e-da2d-457a-9607-fcc665198967
```

---

## Method 3: Find Resource ID via Azure Portal

For custom APIs or apps in your tenant:

### Steps:

1. **Azure Portal** → **Azure Active Directory** → **Enterprise Applications**

2. **Search for the application/service** you want to access

3. Click on the application

4. Go to **Properties**

5. Copy the **Application ID** (this is your Resource ID)

### Alternative for App Registrations:

1. **Azure Portal** → **Azure Active Directory** → **App Registrations**

2. **All applications** → Search for your app

3. Copy the **Application (client) ID**

---

## Method 4: Query Azure AD for Service Principals

Use Azure CLI or PowerShell to find service principals:

### Azure CLI

```powershell
# List all enterprise apps in your tenant
az ad sp list --all --query "[].{Name:displayName, AppId:appId}" -o table

# Search for specific app (e.g., Sentinel, Purview)
az ad sp list --all --query "[?contains(displayName, 'Sentinel')].{Name:displayName, AppId:appId}" -o table

# Get details of specific app
az ad sp show --id "4500ebfb-89b6-4b14-a480-7f74979bfcd"
```

### PowerShell (Azure AD Module)

```powershell
# Install module if needed
Install-Module AzureAD

# Connect
Connect-AzureAD

# Find service principals
Get-AzureADServicePrincipal -Filter "DisplayName eq 'Microsoft Sentinel'"

# Search by name
Get-AzureADServicePrincipal -All $true | Where-Object { $_.DisplayName -like "*Sentinel*" }
```

---

## Method 5: Check the API Documentation

Most Microsoft APIs document their resource IDs:

| Service | Resource ID / URI | Documentation |
|---------|------------------|---------------|
| **Microsoft Sentinel** | Custom per tenant | Check your MCP server docs |
| **Microsoft Graph** | `https://graph.microsoft.com` | [docs.microsoft.com/graph](https://docs.microsoft.com/graph) |
| **Azure Management** | `https://management.azure.com` | [docs.microsoft.com/azure](https://docs.microsoft.com/azure) |
| **Microsoft Purview** | `https://purview.azure.net` | [docs.microsoft.com/purview](https://docs.microsoft.com/purview) |

---

## For Multi-Tenant Sentinel Connections

If you need to connect to Sentinel MCP servers in **different tenants**, you need:

### 1. Resource ID (Application ID)

This is usually the **same across tenants** if it's a standard Microsoft service, but **custom MCP servers may have different app registrations per tenant**.

### 2. Tenant ID

Each tenant has a unique ID:

```powershell
# Get current tenant
az account show --query tenantId -o tsv

# List all tenants you have access to
az account list --query "[].{Name:name, TenantId:tenantId}" -o table
```

### 3. Generate Token for Specific Tenant

```powershell
# Method A: Using Azure CLI
az login --tenant "TENANT_ID"
az account get-access-token --resource "RESOURCE_ID"

# Method B: Using Service Principal
$tokenEndpoint = "https://login.microsoftonline.com/TENANT_ID/oauth2/v2.0/token"

$body = @{
    client_id     = "CLIENT_ID"
    scope         = "RESOURCE_ID/.default"
    client_secret = "CLIENT_SECRET"
    grant_type    = "client_credentials"
}

$response = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body
$token = $response.access_token
```

---

## Practical Example: Finding Sentinel MCP Resource ID

### Scenario: You have a working Sentinel MCP connection

**Step 1: Decode your existing token**

```powershell
# Load your current config
$config = Get-Content "C:\App\loop\mcp.json" | ConvertFrom-Json
$token = $config.servers.'mcp-sentinel'.headers.Authorization -replace "^Bearer\s+", ""

# Decode
$parts = $token.Split('.')[1]
while ($parts.Length % 4 -ne 0) { $parts += "=" }
$payload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($parts))
$data = $payload | ConvertFrom-Json

# Your resource ID:
Write-Host "Resource ID: $($data.aud)"
Write-Host "Tenant ID: $($data.tid)"
```

**Step 2: Use this for token generation**

```powershell
# Generate new token using discovered resource ID
az account get-access-token --resource $data.aud --tenant $data.tid
```

---

## For Your Specific Case

Based on your MCP configuration:

```json
{
  "servers": {
    "mcp-sentinel": {
      "url": "https://sentinel.microsoft.com/mcp/data-exploration",
      "type": "http",
      "headers": {
        "Authorization": "Bearer <TOKEN>"
      }
    }
  }
}
```

**Your Resource ID is:** `4500ebfb-89b6-4b14-a480-7f74979bfcd`  
**Your Tenant ID is:** `536279f6-15cc-45f2-be2d-61e352b51eef`

### To generate tokens:

```powershell
# Using Azure CLI
az login --tenant "536279f6-15cc-45f2-be2d-61e352b51eef"
az account get-access-token --resource "4500ebfb-89b6-4b14-a480-7f74979bfcd"
```

---

## Quick Reference Script

Save this script to easily find resource IDs:

```powershell
# find-resource-id.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$TokenOrConfigPath,
    
    [Parameter(Mandatory=$false)]
    [string]$ServiceName
)

function Decode-JwtToken {
    param([string]$Token)
    $Token = $Token -replace "^Bearer\s+", ""
    $parts = $Token.Split('.')[1]
    while ($parts.Length % 4 -ne 0) { $parts += "=" }
    $payload = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($parts))
    return $payload | ConvertFrom-Json
}

if ($TokenOrConfigPath) {
    if (Test-Path $TokenOrConfigPath) {
        # It's a config file
        $config = Get-Content $TokenOrConfigPath | ConvertFrom-Json
        $token = $config.servers.'mcp-sentinel'.headers.Authorization -replace "^Bearer\s+", ""
    } else {
        # It's a token
        $token = $TokenOrConfigPath
    }
    
    $data = Decode-JwtToken -Token $token
    Write-Host "Resource ID: $($data.aud)" -ForegroundColor Green
    Write-Host "Tenant ID: $($data.tid)" -ForegroundColor Yellow
}
elseif ($ServiceName) {
    # Search for service
    Write-Host "Searching for '$ServiceName' in Azure AD..." -ForegroundColor Cyan
    az ad sp list --all --query "[?contains(displayName, '$ServiceName')].{Name:displayName, AppId:appId}" -o table
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\find-resource-id.ps1 -TokenOrConfigPath 'C:\path\to\mcp.json'"
    Write-Host "  .\find-resource-id.ps1 -TokenOrConfigPath 'eyJ0eXAi...'"
    Write-Host "  .\find-resource-id.ps1 -ServiceName 'Sentinel'"
}
```

---

## Summary

**To find the Resource ID for token generation:**

1. ✅ **Easiest:** Decode your existing working token (use the script above)
2. ✅ **For new services:** Check the service's API documentation
3. ✅ **For custom apps:** Find it in Azure Portal → App Registrations
4. ✅ **For Microsoft services:** Use well-known resource IDs (see table above)

**For multi-tenant scenarios:**
- Resource ID may be the same across tenants (standard services)
- Tenant ID is always different per tenant
- You need credentials/permissions in each tenant

---

**Need help finding a specific resource ID?** Let me know the service name and I can help you locate it!
