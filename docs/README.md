# Documentation Index

Welcome to the Sentinel MCP Security Agent documentation!

## Quick Start

- **[MCP Environment Setup](MCP-ENVIRONMENT-SETUP.md)** - Initial setup and configuration
- **[Quick Reference](QUICK-REFERENCE.md)** - Common commands
- **[Multi-Tenant Setup](MULTI-TENANT-SETUP.md)** - Multi-tenant guide  
- **[Step-by-Step Email Setup](STEP-BY-STEP-EMAIL-SETUP.md)** - Email configuration

## Detection Agents

| Agent | Description |
|-------|-------------|
| **Comprehensive-Hunter.ps1** | 12-module anomaly detection engine |
| **Cross-Tenant-Correlation.ps1** | Multi-tenant correlation analysis |
| **Send-EmailReport.ps1** | Email reporting with Graph API |
| **Fully-Automated-Hunter.ps1** | Zero-prompt automated runner |

## Documentation

### Setup & Configuration
- [MCP Environment Setup](MCP-ENVIRONMENT-SETUP.md)
- [Multi-Tenant Setup](MULTI-TENANT-SETUP.md)
- [Multi-Tenant Access Requirements](MULTI-TENANT-ACCESS-REQUIREMENTS.md)
- [Token Automation Guide](TOKEN-AUTOMATION-GUIDE.md)

### Email Reporting
- [Step-by-Step Email Setup](STEP-BY-STEP-EMAIL-SETUP.md)
- [Email Setup Guide](EMAIL-SETUP-GUIDE.md)
- [Email Setup TODO](EMAIL-SETUP-TODO.md)

### Automation
- [Automated Runner Guide](AUTOMATED-RUNNER-GUIDE.md)
- [Security Agent Use Cases](security-agent-use-cases.md)

### Reference
- [Quick Reference](QUICK-REFERENCE.md)
- [Find Resource ID Guide](find-resource-id-guide.md)
- [Failed Login Anomaly Report](failed-login-anomaly-report.md)

## Common Workflows

**Single Tenant Detection:**
```powershell
.\mcp-env.ps1 use woodgrove
.\agents\Comprehensive-Hunter.ps1
```

**Multi-Tenant Scan:**
```powershell
.\mcp-multi-tenant.ps1
.\agents\Cross-Tenant-Correlation.ps1
```

**Automated with Email:**
```powershell
.\agents\Fully-Automated-Hunter.ps1
.\agents\Send-EmailReport.ps1
```

## Quick Links

- 🚀 [Get Started](MCP-ENVIRONMENT-SETUP.md)
- 📊 [Multi-Tenant](MULTI-TENANT-SETUP.md)
- 📧 [Email Setup](STEP-BY-STEP-EMAIL-SETUP.md)
- 🤖 [Automation](AUTOMATED-RUNNER-GUIDE.md)

---

**Last Updated**: January 28, 2026  
**Status**: ✅ Production Ready
