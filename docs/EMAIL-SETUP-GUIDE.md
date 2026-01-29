# Email Setup Guide

## Quick Setup for Microsoft Graph API Email Reporting

This guide helps you configure automated email reporting for Sentinel anomaly detection.

## Overview

The email system uses **Microsoft Graph API** to send security reports with:
- ✅ Executive summary in email body
- ✅ HTML report attachment
- ✅ Top threats highlighted
- ✅ Automated delivery after each scan

## Requirements

1. **Azure AD Application** with Mail.Send permission
2. **Client Secret** for authentication
3. **Sender Mailbox** (licensed Exchange Online mailbox)
4. **Application Administrator** role (for setup)

## Quick Setup Steps

### 1. Create Azure App

```
Azure Portal → Azure AD → App Registrations → New Registration
Name: "Sentinel Anomaly Reporter"
```

### 2. Grant Permission

```
API Permissions → Add Permission → Microsoft Graph → Application Permissions
Select: Mail.Send
Click: Grant admin consent
```

### 3. Create Secret

```
Certificates & secrets → New client secret
Expiration: 24 months
COPY THE VALUE IMMEDIATELY
```

### 4. Configure

```powershell
Copy-Item email-config.json.template email-config.json
notepad email-config.json
```

Fill in:
- `tenantId` - Your Azure AD tenant ID
- `clientId` - App (client) ID
- `clientSecret` - The secret value you copied
- `senderEmail` - Your service mailbox (e.g., sentinel-alerts@domain.com)
- `recipientEmail` - Who receives the reports (pre-set to ihussain@microsoft.com)

### 5. Test

```powershell
.\agents\Send-EmailReport.ps1 -TestMode
```

### 6. Send

```powershell
.\agents\Send-EmailReport.ps1
```

## Configuration File

**email-config.json** (in repository root):

```json
{
  "tenantId": "YOUR_TENANT_ID",
  "clientId": "YOUR_CLIENT_ID",
  "clientSecret": "YOUR_CLIENT_SECRET",
  "senderEmail": "sentinel-alerts@yourdomain.com",
  "recipientEmail": "ihussain@microsoft.com"
}
```

**Security Notes:**
- ✅ File is in .gitignore (won't be committed)
- ✅ Keep client secret secure
- ✅ Rotate secrets before 24-month expiration

## Email Content

Each email includes:

**Subject:** `🔒 Security Anomaly Report - X anomalies detected`

**Body:**
- Executive summary
- Detection statistics (Critical/High/Medium counts)
- Top 5 priority threats
- Next steps for analysts

**Attachments:**
- HTML report with all anomalies
- (Optional) PDF version

## Usage Examples

### Basic

```powershell
# Run detection
.\agents\Comprehensive-Hunter.ps1

# Send email
.\agents\Send-EmailReport.ps1
```

### Automated

```powershell
# Full automation with email
.\agents\Fully-Automated-Hunter.ps1

# Then send email
.\agents\Send-EmailReport.ps1
```

### Specific Report

```powershell
.\agents\Send-EmailReport.ps1 -ReportPath ".\reports\comprehensive-report-20260128-202824.json"
```

## Troubleshooting

### "Configuration incomplete"
→ Edit email-config.json and fill in all values

### "Authentication failed"
→ Verify client ID, client secret, and tenant ID are correct

### "Mail.Send permission not granted"
→ Grant admin consent in Azure Portal → App Registration → API permissions

### "Mailbox not found"
→ Ensure sender email exists and has Exchange Online license

### "Report file not found"
→ Run `.\agents\Comprehensive-Hunter.ps1` first to generate a report

## Advanced: Scheduled Delivery

Set up Windows Task Scheduler to run daily:

```powershell
$trigger = New-ScheduledTaskTrigger -Daily -At 8am
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\App\loop\agents\Fully-Automated-Hunter.ps1"

Register-ScheduledTask -TaskName "Sentinel Daily Scan" `
    -Trigger $trigger -Action $action
```

Then add email sending to Fully-Automated-Hunter.ps1.

## See Also

- [Step-by-Step Email Setup](STEP-BY-STEP-EMAIL-SETUP.md) - Detailed walkthrough
- [Email Setup TODO](EMAIL-SETUP-TODO.md) - Checklist
- [Automated Runner Guide](AUTOMATED-RUNNER-GUIDE.md) - Automation docs

---

**For detailed setup instructions, see: [STEP-BY-STEP-EMAIL-SETUP.md](STEP-BY-STEP-EMAIL-SETUP.md)**
