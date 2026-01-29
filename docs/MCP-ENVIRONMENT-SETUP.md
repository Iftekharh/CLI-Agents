# Quick MCP Environment Setup Guide

## Overview

Never manually provide tokens again! This guide shows you how to set up environment profiles so you can simply say "use woodgrove" or "connect to production" in any GitHub Copilot CLI session.

---

## Quick Start

### 1. Your Current Environment is Already Configured!

Your "woodgrove" environment is pre-configured with:
- Tenant ID: 536279f6-15cc-45f2-be2d-61e352b51eef
- Resource ID: 4500ebfb-89b6-4b14-a480-7f749797bfcd
- MCP Server: https://sentinel.microsoft.com/mcp/data-exploration

### 2. View Available Environments

```powershell
.\mcp-env.ps1 list
```

### 3. Switch to an Environment

```powershell
# In any new Copilot CLI session, just run:
.\mcp-env.ps1 use woodgrove

# Token is automatically fetched and configured!
```

### 4. Check Current Environment

```powershell
.\mcp-env.ps1 current
```

---

## For Future Copilot CLI Sessions

When you start a new GitHub Copilot CLI window, you can:

### Option A: Tell Copilot in Natural Language

Just say:
- *"Connect to woodgrove MCP environment"*
- *"Switch to woodgrove environment"*
- *"Use the woodgrove MCP server"*

I (Copilot) will run `.\mcp-env.ps1 use woodgrove` for you!

### Option B: Run the Command Yourself

```powershell
cd C:\App\loop
.\mcp-env.ps1 use woodgrove
```

---

## Adding More Environments

### Add a New Environment (e.g., Production)

```powershell
.\mcp-env.ps1 add
```

You'll be prompted for:
- Environment name (e.g., "production", "staging", "dev")
- Display name (e.g., "Production Sentinel")
- Tenant ID
- Resource ID
- MCP Server URL
- Workspace ID (optional)
- Description (optional)

### Quick Add via Editing Config

Edit `mcp-environments.json` directly:

```json
{
  "currentEnvironment": "woodgrove",
  "environments": {
    "woodgrove": { ... },
    "production": {
      "displayName": "Production Sentinel",
      "tenantId": "YOUR_PROD_TENANT_ID",
      "resourceId": "YOUR_PROD_RESOURCE_ID",
      "mcpServerUrl": "https://sentinel-prod.microsoft.com/mcp/data-exploration",
      "workspaceId": "YOUR_PROD_WORKSPACE_ID",
      "description": "Production environment",
      "autoRefresh": true,
      "refreshIntervalMinutes": 45
    }
  }
}
```

---

## Common Commands

```powershell
# List all environments
.\mcp-env.ps1 list

# Switch to an environment
.\mcp-env.ps1 use woodgrove
.\mcp-env.ps1 use production

# Show current environment details
.\mcp-env.ps1 current

# Show specific environment info
.\mcp-env.ps1 info production

# Refresh token for current environment
.\mcp-env.ps1 refresh

# Refresh token for specific environment
.\mcp-env.ps1 refresh production

# Add new environment interactively
.\mcp-env.ps1 add
```

---

## How It Works

### What Happens When You Switch Environments?

1. **Token Acquisition:** Automatically gets fresh token using Azure CLI
   ```powershell
   az account get-access-token --resource <resource-id> --tenant <tenant-id>
   ```

2. **MCP Config Update:** Updates `mcp.json` with new token and server URL

3. **Environment Tracking:** Saves current environment so you know which one you're using

### File Structure

```
C:\App\loop\
├── mcp-environments.json    # Environment profiles storage
├── mcp-env.ps1              # Environment manager script
├── mcp.json                 # Active MCP configuration (auto-updated)
├── mcp-token-refresh.ps1    # Auto-refresh script
└── decode-token.ps1         # Token inspection tool
```

---

## Usage in GitHub Copilot CLI

### Scenario 1: New CLI Session

You open a new Copilot CLI window:

**You:** *"Connect to woodgrove MCP environment"*

**Copilot:** Runs `.\mcp-env.ps1 use woodgrove` and confirms connection with token expiry time.

### Scenario 2: Switching Environments

**You:** *"Switch to production environment"*

**Copilot:** Runs `.\mcp-env.ps1 use production` and updates configuration.

### Scenario 3: Check Current Setup

**You:** *"What MCP environment am I connected to?"*

**Copilot:** Runs `.\mcp-env.ps1 current` and shows details.

### Scenario 4: Add New Environment

**You:** *"Add a new MCP environment called staging"*

**Copilot:** Runs `.\mcp-env.ps1 add` and prompts for configuration.

---

## Automation Tips

### Auto-Refresh on Environment Switch

When you switch environments, the token is automatically refreshed. To keep it refreshed continuously:

```powershell
# Start auto-refresh for current environment
Start-Job -FilePath "C:\App\loop\mcp-token-refresh.ps1"
```

### Start Environment on Windows Login

Create a shortcut in your Startup folder:

```powershell
# Target:
PowerShell.exe -WindowStyle Hidden -File "C:\App\loop\mcp-env.ps1" use woodgrove

# This ensures woodgrove is active whenever you log in
```

### PowerShell Profile Integration

Add to your PowerShell profile (`$PROFILE`):

```powershell
# Quick aliases
function mcp-list { .\mcp-env.ps1 list }
function mcp-use { param($env) .\mcp-env.ps1 use $env }
function mcp-current { .\mcp-env.ps1 current }
function mcp-refresh { .\mcp-env.ps1 refresh }

# Auto-connect on startup (optional)
# .\mcp-env.ps1 use woodgrove -ErrorAction SilentlyContinue
```

Then you can just type:
```powershell
mcp-use woodgrove
mcp-current
```

---

## Finding Information for New Environments

### If Connecting to Different Tenant

Ask the tenant administrator for:
1. **Tenant ID** - Find in Azure Portal → Azure Active Directory → Properties
2. **Resource ID** - Either:
   - Decode an existing token: `.\decode-token.ps1 -Token "their-token"`
   - Get from App Registration in Azure Portal
3. **MCP Server URL** - The MCP endpoint (e.g., https://sentinel.microsoft.com/mcp/...)
4. **Workspace ID** - From Log Analytics workspace (optional but helpful)

### Using Token Decoder

If someone gives you a working token from the target environment:

```powershell
.\decode-token.ps1 -Token "eyJ0eXAi..."
```

This will show:
- Resource ID (aud)
- Tenant ID (tid)
- Other useful metadata

Then add that info to a new environment profile!

---

## Troubleshooting

### "Please run az login"

You need to authenticate with Azure CLI first:

```powershell
az login --tenant <tenant-id>
```

### "Environment not found"

List available environments:

```powershell
.\mcp-env.ps1 list
```

### Token Expired

Refresh manually:

```powershell
.\mcp-env.ps1 refresh
```

### Wrong Environment Active

Check which is active:

```powershell
.\mcp-env.ps1 current
```

Switch to correct one:

```powershell
.\mcp-env.ps1 use <correct-name>
```

---

## Example Workflow

### Day 1: Initial Setup (Already Done!)

```powershell
# Your woodgrove environment is pre-configured!
.\mcp-env.ps1 use woodgrove
```

### Day 2: New Copilot CLI Session

```powershell
cd C:\App\loop
.\mcp-env.ps1 use woodgrove
# Ready to query Sentinel!
```

### Adding Production Environment

```powershell
.\mcp-env.ps1 add
# Follow prompts...
# Name: production
# Display: Production Sentinel
# Tenant: xxx-xxx-xxx
# Resource: xxx-xxx-xxx
# URL: https://sentinel-prod.microsoft.com/mcp/...

# Now you can switch:
.\mcp-env.ps1 use production
```

### Switching Between Environments

```powershell
# Work on woodgrove
.\mcp-env.ps1 use woodgrove
# Query data...

# Switch to production
.\mcp-env.ps1 use production
# Query production data...

# Check where you are
.\mcp-env.ps1 current
```

---

## Advanced: Integration with Copilot CLI

Create a "connection reminder" script that Copilot can reference:

```powershell
# connect-mcp.ps1
param([string]$Environment = "woodgrove")

Write-Host "Connecting to MCP environment: $Environment" -ForegroundColor Cyan
.\mcp-env.ps1 use $Environment

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Connected! You can now query Sentinel data." -ForegroundColor Green
    
    # Show quick help
    Write-Host "`nQuick Examples:" -ForegroundColor Yellow
    Write-Host "  - 'Show me failed logins in the last 24 hours'" -ForegroundColor Gray
    Write-Host "  - 'List top 10 users with most sign-in activity'" -ForegroundColor Gray
    Write-Host "  - 'Create anomaly detection report'" -ForegroundColor Gray
}
```

Then in Copilot CLI:
**You:** *"Run connect-mcp.ps1"* or *"Connect to woodgrove"*

---

## Summary

### What You Can Say to Copilot

Instead of providing tokens, just say:
- ✅ *"Connect to woodgrove environment"*
- ✅ *"Switch to production MCP"*
- ✅ *"Use the staging environment"*
- ✅ *"What environment am I in?"*
- ✅ *"Refresh my MCP token"*

### Benefits

- 🚀 **No manual token pasting** - Automated token acquisition
- 🔄 **Easy switching** - Change environments with one command
- 💾 **Persistent config** - Settings survive across sessions
- 🔐 **Secure** - Uses Azure CLI authentication
- 📋 **Multiple environments** - Manage dev, staging, prod, etc.

---

**Your woodgrove environment is ready!** Just run `.\mcp-env.ps1 use woodgrove` in any new session.
