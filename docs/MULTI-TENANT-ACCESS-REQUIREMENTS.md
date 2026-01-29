# Multi-Tenant Access Requirements

## Overview

This document outlines the permissions and requirements needed to access Microsoft Sentinel across multiple tenants using the MCP (Model Context Protocol) framework.

## Azure AD Permissions Required

### Per-Tenant Requirements

Each tenant you want to access requires:

1. **Azure AD User Account**
   - Active user account in the tenant
   - Can be:
     - Native account (user@tenant.onmicrosoft.com)
     - Guest account (external user invited)
     - Service account (dedicated for automation)

2. **Sentinel Role Assignments**
   - **Minimum**: Microsoft Sentinel Reader
   - **Recommended**: Microsoft Sentinel Responder (for full capabilities)
   - **Alternatives**: Security Reader (read-only across all security services)

3. **Resource Access**
   - Access to Log Analytics workspace where Sentinel is enabled
   - Workspace must be in accessible subscription

## Role Details

### Microsoft Sentinel Reader
- ✅ View Sentinel data, incidents, workbooks
- ✅ Run KQL queries via MCP
- ✅ Generate reports
- ❌ Cannot create or modify incidents
- ❌ Cannot run playbooks

**Sufficient for**: Anomaly detection, reporting, threat hunting

### Microsoft Sentinel Responder
- ✅ All Reader permissions
- ✅ Create and update incidents
- ✅ Run playbooks
- ✅ Full investigation capabilities

**Recommended for**: Active security operations

### Security Reader (Azure AD Role)
- ✅ Read-only access to all security services
- ✅ View Sentinel data
- ✅ View Azure AD sign-in logs
- ❌ Cannot modify anything

**Good for**: Compliance and audit scenarios

## Multi-Tenant Authentication

### Option 1: Separate Accounts Per Tenant

**Use Case**: MSP managing customer tenants

```
Tenant A: user@customera.com
Tenant B: user@customerb.com  
Tenant C: user@customerc.com
```

**Pros:**
- ✅ Clean separation
- ✅ Each customer controls their own accounts
- ✅ Easy to revoke access

**Cons:**
- ❌ Multiple logins required
- ❌ More credentials to manage

### Option 2: Guest Access

**Use Case**: Single organization with multiple Azure AD tenants

```
Primary: analyst@company.com
Tenant A: analyst@company.com (as guest)
Tenant B: analyst@company.com (as guest)
```

**Pros:**
- ✅ Single identity
- ✅ Easier credential management

**Cons:**
- ❌ Requires guest invitations
- ❌ May have MFA challenges
- ❌ Dependent on external org's policies

### Option 3: Service Principal (Advanced)

**Use Case**: Fully automated workflows

Requires:
- Application registration in each tenant
- Assigned permissions to Sentinel/Log Analytics
- Certificate or secret-based auth

**Note**: Not covered in current implementation (uses user accounts)

## Access Workflow

### Initial Setup (Per Tenant)

1. **Get invited** to tenant (if guest access)
   ```
   Admin sends invitation → Accept email link → Complete registration
   ```

2. **Verify role assignment**
   ```
   Azure Portal → Sentinel → Settings → Workspace settings
   → Access control (IAM) → Check your roles
   ```

3. **Get workspace details**
   - Tenant ID: Azure AD → Overview
   - Workspace ID: Sentinel → Settings → Workspace settings

4. **Configure in MCP**
   ```powershell
   .\mcp-env.ps1 add
   ```

### Daily Usage

1. **Login to tenant** (handled automatically by scripts)
   ```powershell
   az login --tenant <TENANT_ID>
   ```

2. **Get access token** (handled by mcp-env.ps1)
   ```powershell
   az account get-access-token --resource 4500ebfb-89b6-4b14-a480-7f749797bfcd
   ```

3. **Token valid for ~60 minutes**
   - Auto-refresh: `.\mcp-env.ps1 refresh`

## Network Requirements

### Endpoints to Allow

- **Azure AD**: login.microsoftonline.com
- **Azure CLI**: management.azure.com
- **Sentinel MCP**: sentinel.microsoft.com

### No VPN Required
- All access via Azure public endpoints
- MCP uses HTTPS (port 443)
- No private network access needed

## Conditional Access Considerations

If tenants have Conditional Access policies:

1. **MFA Enforcement**
   - May be required for each tenant
   - Device compliance checks may apply
   - Use `az login` with browser auth when prompted

2. **Trusted Locations**
   - Script may need to run from approved IPs
   - Named locations in CA policies

3. **Device Compliance**
   - Managed device may be required
   - Intune enrollment might be needed

## Security Best Practices

### 1. Use Dedicated Accounts

Create service accounts specifically for automation:
```
sentinel-automation@yourdomain.com
```

**Benefits:**
- Easier to audit
- Can restrict permissions
- No impact if personal account changes

### 2. Principle of Least Privilege

Only request the minimum role needed:
- Anomaly detection → Sentinel Reader
- Incident management → Sentinel Responder
- Read-only reporting → Security Reader

### 3. Regular Access Reviews

- Review guest accounts quarterly
- Remove unused tenant configurations
- Rotate credentials periodically

### 4. Token Security

- Never commit tokens to git (check .gitignore)
- Tokens auto-expire after 60 minutes
- mcp.json contains active tokens (git-ignored)

## Troubleshooting Access Issues

### "Insufficient permissions" error

**Check:**
1. User has Sentinel Reader or higher role
2. Role assigned at workspace level (not subscription)
3. Account is not disabled/blocked

**Fix:**
```
Azure Portal → Sentinel → Settings → Access control (IAM)
→ Add role assignment → Select Microsoft Sentinel Reader
```

### "Tenant not found"

**Check:**
1. Tenant ID is correct
2. Account has access to tenant
3. Logged in with correct account

**Fix:**
```powershell
az login --tenant <TENANT_ID>
az account show
```

### "Token expired"

**Fix:**
```powershell
.\mcp-env.ps1 refresh
```

### "Cannot query workspace"

**Check:**
1. Workspace ID is correct
2. Sentinel is enabled on workspace
3. User has Log Analytics Reader role

## Requesting Access

### For Customer Tenants (MSP Scenario)

**Email Template:**

```
Subject: Sentinel MCP Access Request

Hi [Customer Admin],

I need access to your Microsoft Sentinel workspace for security monitoring.

Required:
- Role: Microsoft Sentinel Reader
- Workspace: [Workspace Name/ID]
- Account: [your@email.com]

This will enable automated threat detection and reporting.

Thank you!
```

### For Internal Tenants

Submit request via:
- IT Service Portal
- Azure AD access reviews
- Direct request to Azure/Security admin

## Compliance Considerations

### Data Residency
- MCP queries execute in Azure region of workspace
- No data crosses regional boundaries
- Tokens stored locally (not transmitted to third parties)

### Audit Logging
- All queries logged in Azure AD sign-in logs
- MCP operations logged in Sentinel workspace
- Review logs: Azure Portal → Sentinel → Logs

### PII/Sensitive Data
- Queries may return user data (emails, IPs, locations)
- Handle reports according to data protection policies
- Consider encrypting report storage

---

## Summary Checklist

- [ ] Have user account in each tenant
- [ ] Assigned Microsoft Sentinel Reader role (minimum)
- [ ] Know Tenant ID and Workspace ID
- [ ] Can login via Azure CLI: `az login --tenant <ID>`
- [ ] Configured in mcp-environments.json
- [ ] Tested connection: `.\mcp-env.ps1 use <tenant>`
- [ ] Token refreshes successfully

---

## See Also

- [Multi-Tenant Setup Guide](MULTI-TENANT-SETUP.md)
- [Quick Reference](QUICK-REFERENCE.md)
- [MCP Environment Setup](MCP-ENVIRONMENT-SETUP.md)
