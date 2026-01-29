# Multi-Tenant Sentinel MCP Setup Guide

## Overview

This guide shows you how to configure and use multiple Microsoft Sentinel workspaces with the MCP (Model Context Protocol) framework.

## Prerequisites

- Azure CLI installed and configured
- Access to 2+ Microsoft Sentinel workspaces
- Appropriate permissions (Security Reader or higher) in each tenant
- PowerShell 5.1 or later

## Quick Start

### 1. Configure Your First Tenant

```powershell
# Add first environment
.\mcp-env.ps1 add
```

Follow the prompts to enter:
- **Environment Name**: e.g., "woodgrove", "production", "customer-a"
- **Tenant ID**: Your Azure AD tenant ID
- **Workspace ID**: Sentinel workspace ID
- **Account**: User account with access (e.g., user@domain.com)

### 2. Add Additional Tenants

```powershell
# Add second, third, etc.
.\mcp-env.ps1 add
.\mcp-env.ps1 add
```

Repeat for each tenant you want to manage.

### 3. List All Configured Tenants

```powershell
.\mcp-env.ps1 list
```

### 4. Switch Between Tenants

```powershell
# Switch to a specific tenant
.\mcp-env.ps1 use woodgrove
.\mcp-env.ps1 use production
```

### 5. Activate Multi-Tenant Mode

```powershell
# Connect to ALL tenants simultaneously
.\mcp-multi-tenant.ps1
```

This creates a single `mcp.json` with multiple server configurations.

## Use Cases

### MSP (Managed Service Provider)

```powershell
# Configure all customer tenants
.\mcp-env.ps1 add  # Customer A
.\mcp-env.ps1 add  # Customer B
.\mcp-env.ps1 add  # Customer C

# Daily scan across all customers
foreach ($customer in @("customer-a", "customer-b", "customer-c")) {
    .\mcp-env.ps1 use $customer
    .\agents\Comprehensive-Hunter.ps1
}
```

### Dev/Test/Prod Pipeline

```powershell
# Test in dev first
.\mcp-env.ps1 use dev
.\agents\Comprehensive-Hunter.ps1

# Then production
.\mcp-env.ps1 use production
.\agents\Comprehensive-Hunter.ps1
```

### Cross-Tenant Threat Hunting

```powershell
# Activate all tenants
.\mcp-multi-tenant.ps1

# Run cross-tenant correlation
.\agents\Cross-Tenant-Correlation.ps1
```

## Authentication

Each tenant requires separate authentication:

1. **Login to tenant**: `az login --tenant <TENANT_ID>`
2. **Get access token**: `az account get-access-token --resource 4500ebfb-89b6-4b14-a480-7f749797bfcd`
3. **Token is stored** in `mcp.json` (auto-managed by scripts)

Tokens expire after ~60 minutes. Refresh with:

```powershell
.\mcp-env.ps1 refresh
```

## Configuration Files

- **mcp-environments.json**: Stores tenant configurations (tenant IDs, workspace IDs, accounts)
- **mcp.json**: Active MCP server connections with bearer tokens (git-ignored)
- **.gitignore**: Ensures tokens never get committed

## Security Best Practices

1. **Never commit** `mcp.json` (contains bearer tokens)
2. **Use separate accounts** for each tenant when possible
3. **Refresh tokens regularly** - they expire after 60 minutes
4. **Review .gitignore** before committing to ensure token files are excluded

## Troubleshooting

### "Token expired" error
```powershell
.\mcp-env.ps1 refresh
```

### "Cannot switch tenant"
```powershell
# Login to the specific tenant first
az login --tenant <TENANT_ID>
```

### "No data returned from MCP"
- Verify workspace ID is correct
- Check that your account has permissions
- Ensure token hasn't expired

## Commands Reference

| Command | Description |
|---------|-------------|
| `.\mcp-env.ps1 list` | List all configured tenants |
| `.\mcp-env.ps1 use <name>` | Switch to specific tenant |
| `.\mcp-env.ps1 add` | Add new tenant |
| `.\mcp-env.ps1 current` | Show current tenant |
| `.\mcp-env.ps1 refresh` | Refresh current token |
| `.\mcp-multi-tenant.ps1` | Activate all tenants |
| `.\mcp-multi-tenant.ps1 -Status` | Check all tenants status |
| `.\mcp-multi-tenant.ps1 -Refresh` | Refresh all tokens |

## Next Steps

- [Multi-Tenant Access Requirements](MULTI-TENANT-ACCESS-REQUIREMENTS.md)
- [Cross-Tenant Correlation Analysis](../agents/Cross-Tenant-Correlation.ps1)
- [Consolidated Detection](../agents/Consolidated-Multi-Tenant-Detection.ps1)
