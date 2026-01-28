# MCP Environment Profile Manager

> Seamlessly connect to Microsoft Sentinel MCP servers across multiple tenants and workspaces without manual token management.

## 🎯 Overview

This environment profile system allows you to:
- **Manage multiple MCP environments** with friendly names (like kubectl contexts)
- **Automatically acquire and refresh tokens** - no more manual copy/paste
- **Switch environments with one command** - `.\mcp-env.ps1 use woodgrove`
- **Use natural language in GitHub Copilot CLI** - just say "connect to woodgrove"

## 🚀 Quick Start

Your **"woodgrove"** environment is already configured and ready to use!

### First Time Setup (Already Done!)
```powershell
# Your woodgrove environment is pre-configured with:
# - Tenant ID: 536279f6-15cc-45f2-be2d-61e352b51eef
# - Resource ID: 4500ebfb-89b6-4b14-a480-7f749797bfcd
# - MCP Server: https://sentinel.microsoft.com/mcp/data-exploration
```

### Connect to Woodgrove
```powershell
# Switch to woodgrove environment
.\mcp-env.ps1 use woodgrove

# Token is automatically fetched and mcp.json is updated!
```

## 📖 Usage in Future Copilot CLI Sessions

### Method 1: Natural Language (Recommended) 🗣️

Open a new GitHub Copilot CLI window and simply say:

```
"Connect to woodgrove environment"
```

or

```
"Use the woodgrove MCP server"
```

Copilot will automatically run the connection command for you!

### Method 2: Direct Command ⌨️

```powershell
cd C:\App\loop
.\mcp-env.ps1 use woodgrove
```

That's it! You're connected and ready to query Sentinel data.

## 📋 Common Commands

| Command | Description | Example |
|---------|-------------|---------|
| `.\mcp-env.ps1 list` | Show all available environments | Lists woodgrove, production, etc. |
| `.\mcp-env.ps1 use <name>` | Switch to an environment | `.\mcp-env.ps1 use woodgrove` |
| `.\mcp-env.ps1 current` | Show current active environment | Displays current config |
| `.\mcp-env.ps1 info [name]` | Show environment details | `.\mcp-env.ps1 info woodgrove` |
| `.\mcp-env.ps1 refresh [name]` | Refresh token for environment | `.\mcp-env.ps1 refresh` |
| `.\mcp-env.ps1 add` | Add new environment interactively | Prompts for details |

### Examples

```powershell
# List all environments
.\mcp-env.ps1 list

# Switch to woodgrove
.\mcp-env.ps1 use woodgrove

# Check current environment
.\mcp-env.ps1 current

# Refresh token
.\mcp-env.ps1 refresh

# Add new environment
.\mcp-env.ps1 add
```

## ➕ Adding More Environments

### Interactive Method

```powershell
.\mcp-env.ps1 add
```

You'll be prompted for:
- **Environment name** (e.g., "production", "staging", "dev")
- **Display name** (e.g., "Production Sentinel")
- **Tenant ID** - Get from Azure Portal or decode existing token
- **Resource ID** - Decode from token or get from App Registration
- **MCP Server URL** - The Sentinel MCP endpoint
- **Workspace ID** (optional) - Log Analytics workspace ID
- **Description** (optional) - Notes about the environment

### Manual Configuration

Edit `mcp-environments.json` directly:

```json
{
  "currentEnvironment": "woodgrove",
  "environments": {
    "woodgrove": {
      "displayName": "Woodgrove (Current Workspace)",
      "tenantId": "536279f6-15cc-45f2-be2d-61e352b51eef",
      "resourceId": "4500ebfb-89b6-4b14-a480-7f749797bfcd",
      "mcpServerUrl": "https://sentinel.microsoft.com/mcp/data-exploration",
      "workspaceId": "029c55c8-a7ec-418e-b741-de9d24add5fa",
      "description": "Primary Sentinel workspace",
      "autoRefresh": true,
      "refreshIntervalMinutes": 45
    },
    "production": {
      "displayName": "Production Sentinel",
      "tenantId": "your-prod-tenant-id",
      "resourceId": "your-prod-resource-id",
      "mcpServerUrl": "https://sentinel-prod.microsoft.com/mcp/data-exploration",
      "workspaceId": "your-prod-workspace-id",
      "description": "Production environment",
      "autoRefresh": true,
      "refreshIntervalMinutes": 45
    }
  }
}
```

## 🔍 Finding Resource IDs for New Environments

### Method 1: Decode Existing Token

If you have a working token from the target environment:

```powershell
.\decode-token.ps1 -Token "eyJ0eXAi..."
```

This will show:
- Resource ID (aud claim)
- Tenant ID (tid claim)
- Expiry time and other metadata

### Method 2: From mcp.json

If you already have a working `mcp.json` from that environment:

```powershell
.\decode-token.ps1 -McpConfigPath "path\to\their\mcp.json"
```

### Method 3: Azure Portal

1. Go to **Azure Portal** → **Azure Active Directory** → **App Registrations**
2. Find the MCP application
3. Copy the **Application (client) ID** - this is your Resource ID

### Method 4: Ask the Admin

Request from the tenant administrator:
- Tenant ID
- Resource ID (Application ID)
- MCP Server URL
- Workspace ID (optional)

## 🔧 Troubleshooting

### "Please run az login"

You need to authenticate with Azure CLI:

```powershell
az login --tenant 536279f6-15cc-45f2-be2d-61e352b51eef
```

### Token Has Expired

Refresh the token manually:

```powershell
.\mcp-env.ps1 refresh
```

Or for a specific environment:

```powershell
.\mcp-env.ps1 refresh production
```

### Check Token Status

See current token expiry:

```powershell
.\decode-token.ps1
```

### Environment Not Found

List available environments:

```powershell
.\mcp-env.ps1 list
```

### Wrong Environment Active

Check which environment is active:

```powershell
.\mcp-env.ps1 current
```

Switch to the correct one:

```powershell
.\mcp-env.ps1 use <correct-name>
```

## 🗂️ File Structure

```
C:\App\loop\
├── README.md                        # This file
├── mcp-environments.json            # Environment profiles storage
├── mcp-env.ps1                      # Environment manager script
├── mcp.json                         # Active MCP configuration (auto-updated)
├── mcp-token-refresh.ps1            # Auto token refresh script
├── mcp-token-service-principal.ps1  # Service principal auth script
├── decode-token.ps1                 # JWT token decoder
├── MCP-ENVIRONMENT-SETUP.md         # Detailed setup guide
├── TOKEN-AUTOMATION-GUIDE.md        # Token automation documentation
├── find-resource-id-guide.md        # Resource ID discovery guide
├── QUICK-REFERENCE.md               # Quick command reference
└── failed-login-anomaly-report.md   # Example report
```

## 🔐 Token Management

### Automatic Token Refresh (Background)

Start continuous token refresh for current environment:

```powershell
Start-Job -FilePath "C:\App\loop\mcp-token-refresh.ps1"
```

Check status:

```powershell
Get-Job
Receive-Job -Id 1 -Keep
```

### Service Principal (Recommended for Production)

For unattended automation, use a service principal:

```powershell
.\mcp-token-service-principal.ps1 `
    -TenantId "your-tenant-id" `
    -ClientId "your-client-id" `
    -ClientSecret "your-secret" `
    -Resource "your-resource-id"
```

See `TOKEN-AUTOMATION-GUIDE.md` for full details.

## 💡 Example Workflows

### Daily Workflow

```powershell
# Morning: Open Copilot CLI
cd C:\App\loop
.\mcp-env.ps1 use woodgrove

# Query Sentinel data
# "Show me failed logins in the last 24 hours"
# "Create anomaly detection report"
# etc.

# Switch to production for comparison
.\mcp-env.ps1 use production

# Continue working...
```

### Multi-Tenant Management

```powershell
# Add multiple tenant environments
.\mcp-env.ps1 add  # Add "customer-a"
.\mcp-env.ps1 add  # Add "customer-b"
.\mcp-env.ps1 add  # Add "customer-c"

# Switch between them easily
.\mcp-env.ps1 use customer-a
# Work on customer A...

.\mcp-env.ps1 use customer-b
# Work on customer B...

# Check where you are
.\mcp-env.ps1 current
```

### First Time in New Tenant

```powershell
# Step 1: Get a working token from the new tenant admin
# Step 2: Decode it to find resource ID
.\decode-token.ps1 -Token "their-token-here"

# Step 3: Add the environment
.\mcp-env.ps1 add
# Enter the details from decoded token

# Step 4: Use it
.\mcp-env.ps1 use newtenant
```

## 📚 Additional Documentation

- **MCP-ENVIRONMENT-SETUP.md** - Comprehensive setup guide with examples
- **TOKEN-AUTOMATION-GUIDE.md** - Full token automation documentation
- **find-resource-id-guide.md** - How to find resource IDs for different services
- **QUICK-REFERENCE.md** - Command cheat sheet

## 🎓 How It Works

### Behind the Scenes

When you run `.\mcp-env.ps1 use woodgrove`:

1. **Loads** the environment profile from `mcp-environments.json`
2. **Acquires** a fresh token using Azure CLI:
   ```powershell
   az account get-access-token --resource <resource-id> --tenant <tenant-id>
   ```
3. **Updates** `mcp.json` with the new token and server URL
4. **Saves** the current environment name
5. **Verifies** token validity and shows expiry time

### Environment Profile Structure

```json
{
  "displayName": "Woodgrove (Current Workspace)",
  "tenantId": "536279f6-15cc-45f2-be2d-61e352b51eef",
  "resourceId": "4500ebfb-89b6-4b14-a480-7f749797bfcd",
  "mcpServerUrl": "https://sentinel.microsoft.com/mcp/data-exploration",
  "workspaceId": "029c55c8-a7ec-418e-b741-de9d24add5fa",
  "description": "Primary Sentinel workspace",
  "autoRefresh": true,
  "refreshIntervalMinutes": 45
}
```

## ⚙️ Advanced Configuration

### PowerShell Profile Integration

Add to your PowerShell profile (`$PROFILE`):

```powershell
# Quick aliases for MCP management
Set-Alias mcp-list "$env:USERPROFILE\C:\App\loop\mcp-env.ps1 list"
Set-Alias mcp-current "$env:USERPROFILE\C:\App\loop\mcp-env.ps1 current"

function Use-MCP {
    param([string]$Environment)
    & "C:\App\loop\mcp-env.ps1" use $Environment
}

# Auto-connect to woodgrove on startup (optional)
# Use-MCP woodgrove
```

Then you can use:
```powershell
mcp-list
Use-MCP woodgrove
```

### Startup Script

Create a shortcut in your Windows Startup folder:

**Target:**
```
PowerShell.exe -WindowStyle Hidden -File "C:\App\loop\mcp-env.ps1" use woodgrove
```

This ensures woodgrove is active whenever you log in.

## 🛡️ Security Best Practices

1. **Never commit tokens to git**
   - `mcp.json` contains active tokens - add to `.gitignore`
   - Environment config with credentials should not be shared

2. **Use Azure CLI authentication**
   - Tokens are generated on-demand
   - Azure CLI manages refresh tokens securely

3. **Service Principal for automation**
   - Create dedicated service principals
   - Use least privilege permissions
   - Rotate secrets regularly

4. **Monitor token expiry**
   - Use `.\decode-token.ps1` to check expiry
   - Enable auto-refresh for long-running sessions

## 🤝 Support & Contributions

### Getting Help

- Check `MCP-ENVIRONMENT-SETUP.md` for detailed guides
- Review `QUICK-REFERENCE.md` for command syntax
- Use `.\mcp-env.ps1` without arguments to see help

### Known Limitations

- Requires Azure CLI installed and configured
- Tokens expire after ~1 hour (use auto-refresh)
- Service principal requires App Registration setup

## 📝 Version History

**v1.0** - Initial release
- Environment profile management
- Automatic token acquisition
- Multi-tenant support
- Natural language integration with Copilot CLI

---

## 🎉 You're Ready!

Your **woodgrove** environment is configured and ready to use.

In any new GitHub Copilot CLI session, just say:

> **"Connect to woodgrove environment"**

Or run:

```powershell
.\mcp-env.ps1 use woodgrove
```

Happy querying! 🚀

---

**Quick Links:**
- 📖 [Detailed Setup Guide](MCP-ENVIRONMENT-SETUP.md)
- 🔑 [Token Automation](TOKEN-AUTOMATION-GUIDE.md)
- 🔍 [Finding Resource IDs](find-resource-id-guide.md)
- ⚡ [Quick Reference](QUICK-REFERENCE.md)
