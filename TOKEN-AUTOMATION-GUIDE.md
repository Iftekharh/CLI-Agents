# MCP Token Automation - Setup Guide

## Overview

This guide provides multiple solutions for automating Azure AD token refresh for MCP server connections, eliminating the need for manual token updates.

---

## Solution 1: Azure CLI Auto-Refresh (Easiest)

### Prerequisites
- Azure CLI installed (`az --version`)
- Logged in to Azure CLI (`az login`)

### Setup

1. **Save the script**
   - File: `mcp-token-refresh.ps1`
   - Location: Same directory as `mcp.json`

2. **Run the script**
   ```powershell
   # One-time refresh
   .\mcp-token-refresh.ps1 -RunOnce
   
   # Continuous mode (recommended)
   .\mcp-token-refresh.ps1
   ```

3. **Run in background**
   ```powershell
   # Start as background job
   Start-Job -FilePath "C:\App\loop\mcp-token-refresh.ps1"
   
   # Check status
   Get-Job
   
   # View output
   Receive-Job -Id 1
   ```

4. **Run as Windows Scheduled Task**
   ```powershell
   $action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
       -Argument "-File C:\App\loop\mcp-token-refresh.ps1"
   
   $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
       -RepetitionInterval (New-TimeSpan -Minutes 45)
   
   Register-ScheduledTask -TaskName "MCP-TokenRefresh" `
       -Action $action -Trigger $trigger -RunLevel Highest
   ```

### Configuration

Edit the script parameters:
```powershell
[string]$McpConfigPath = "C:\App\loop\mcp.json"
[int]$RefreshIntervalMinutes = 45  # Refresh every 45 min
```

---

## Solution 2: Service Principal (Most Secure) ⭐ RECOMMENDED

### Why Use Service Principal?
- ✅ No manual login required
- ✅ Tokens last longer (configurable)
- ✅ Proper separation of concerns
- ✅ Auditable and manageable
- ✅ Industry best practice for automation

### Setup Steps

#### Step 1: Create App Registration

1. **Azure Portal** → **Azure Active Directory** → **App registrations** → **New registration**

2. **Register application**
   - Name: `MCP-Sentinel-Automation`
   - Supported account types: `Single tenant`
   - Redirect URI: Leave blank
   - Click **Register**

3. **Note the values:**
   - Application (client) ID: `<CLIENT_ID>`
   - Directory (tenant) ID: `<TENANT_ID>`

#### Step 2: Create Client Secret

1. Go to **Certificates & secrets** → **New client secret**
2. Description: `MCP Token Automation`
3. Expires: `24 months` (or your preference)
4. Click **Add**
5. **Copy the secret value immediately** (you won't see it again)

#### Step 3: Grant API Permissions

1. Go to **API permissions** → **Add a permission**
2. Select the API your MCP server uses (e.g., Microsoft Graph, custom API)
3. Choose **Application permissions** (not Delegated)
4. Select required permissions (e.g., `Sentinel.Read`)
5. Click **Grant admin consent**

#### Step 4: Configure the Script

```powershell
# Run the service principal script
.\mcp-token-service-principal.ps1 `
    -TenantId "<YOUR_TENANT_ID>" `
    -ClientId "<YOUR_CLIENT_ID>" `
    -ClientSecret "<YOUR_CLIENT_SECRET>" `
    -Resource "https://sentinel.microsoft.com"
```

#### Step 5: Secure the Credentials

**Option A: Windows Credential Manager**
```powershell
# Store secret securely
$secret = ConvertTo-SecureString "<YOUR_SECRET>" -AsPlainText -Force
$secret | Export-Clixml "C:\secure\mcp-secret.xml"

# Retrieve in script
$secret = Import-Clixml "C:\secure\mcp-secret.xml"
$plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret))
```

**Option B: Azure Key Vault** (Most Secure)
```powershell
# Store in Key Vault
az keyvault secret set --vault-name "my-keyvault" `
    --name "mcp-client-secret" --value "<YOUR_SECRET>"

# Retrieve in script
$secret = az keyvault secret show --vault-name "my-keyvault" `
    --name "mcp-client-secret" --query value -o tsv
```

---

## Solution 3: Modify mcp.json to Support Dynamic Tokens

Instead of hardcoding the token, use a token endpoint:

```json
{
  "servers": {
    "mcp-sentinel": {
      "url": "https://sentinel.microsoft.com/mcp/data-exploration",
      "type": "http",
      "auth": {
        "type": "oauth2",
        "tokenEndpoint": "https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token",
        "clientId": "{client-id}",
        "clientSecret": "{client-secret}",
        "scope": "https://sentinel.microsoft.com/.default"
      }
    }
  }
}
```

**Note:** This requires MCP client support for OAuth2 flows. Check your MCP client documentation.

---

## Solution 4: Wrapper Script with Token Injection

Create a wrapper that injects fresh tokens at runtime:

```powershell
# mcp-wrapper.ps1
param([string]$MCPCommand)

# Get fresh token
$token = az account get-access-token --resource "4500ebfb-89b6-4b14-a480-7f74979bfcd" --query accessToken -o tsv

# Set as environment variable
$env:MCP_AUTH_TOKEN = "Bearer $token"

# Run MCP command with token
& $MCPCommand
```

---

## Comparison Matrix

| Solution | Complexity | Security | Maintenance | User Interaction |
|----------|-----------|----------|-------------|------------------|
| Azure CLI Auto-Refresh | Low | Medium | Low | Initial login only |
| Service Principal | Medium | **High** | Low | None ✅ |
| MCP Config Modification | Low | Medium | Low | Depends on client |
| Runtime Wrapper | Low | Medium | Medium | Initial login |

---

## Recommended Setup

### For Development/Personal Use:
Use **Solution 1** (Azure CLI Auto-Refresh)
- Quick to set up
- Uses your existing Azure login
- Good for testing

### For Production/Team Use:
Use **Solution 2** (Service Principal) ⭐
- Most secure
- No user interaction
- Auditable
- Scales well

---

## Troubleshooting

### Token Refresh Fails
```powershell
# Check Azure CLI login
az account show

# Re-login if needed
az login

# Test token acquisition
az account get-access-token --resource "4500ebfb-89b6-4b14-a480-7f74979bfcd"
```

### Permission Issues
```powershell
# Check API permissions for Service Principal
az ad app permission list --id <CLIENT_ID>

# Grant admin consent
az ad app permission admin-consent --id <CLIENT_ID>
```

### Script Not Running
```powershell
# Check execution policy
Get-ExecutionPolicy

# Set if needed (run as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Security Best Practices

1. **Never commit secrets to git**
   - Add `mcp-secret.xml` to `.gitignore`
   - Use environment variables or Key Vault

2. **Use least privilege**
   - Grant only required API permissions
   - Use Application permissions, not admin roles

3. **Rotate secrets regularly**
   - Set expiration on client secrets
   - Rotate every 6-12 months

4. **Monitor access**
   - Review sign-in logs for service principal
   - Set up alerts for unusual activity

5. **Secure the script**
   - Store scripts in protected directory
   - Use Windows ACLs to restrict access

---

## Example: Complete Automation Setup

```powershell
# 1. Create service principal (one-time setup)
$sp = az ad sp create-for-rbac --name "MCP-Automation" `
    --role Reader --scopes /subscriptions/{subscription-id}

# 2. Store credentials securely
$clientSecret = ConvertTo-SecureString $sp.password -AsPlainText -Force
$clientSecret | Export-Clixml "$env:USERPROFILE\.mcp\secret.xml"

# 3. Create startup script
$startupScript = @"
`$secret = Import-Clixml "$env:USERPROFILE\.mcp\secret.xml"
`$plainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR(`$secret))

.\mcp-token-service-principal.ps1 ``
    -TenantId "$($sp.tenant)" ``
    -ClientId "$($sp.appId)" ``
    -ClientSecret `$plainSecret ``
    -Resource "https://sentinel.microsoft.com"
"@

$startupScript | Out-File "C:\App\loop\start-mcp-refresh.ps1"

# 4. Create scheduled task to run at startup
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\App\loop\start-mcp-refresh.ps1"

$trigger = New-ScheduledTaskTrigger -AtStartup

Register-ScheduledTask -TaskName "MCP-TokenRefresh-Startup" `
    -Action $action -Trigger $trigger -RunLevel Highest
```

---

## Support

For issues or questions:
- Check Azure AD sign-in logs
- Review script output/logs
- Verify API permissions in Azure Portal
- Test token acquisition manually first

---

**Last Updated:** 2026-01-28  
**Version:** 1.0
