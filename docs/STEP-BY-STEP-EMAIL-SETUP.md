# Step-by-Step Email Setup Guide

## Complete Azure App Registration Walkthrough

This guide walks you through setting up email reporting for the Sentinel MCP Anomaly Hunter using Microsoft Graph API.

## Prerequisites

- **Azure AD Role Required**: Application Administrator or Global Administrator
- **Access Required**: Azure Portal (portal.azure.com)
- **Time Estimate**: 10-15 minutes

---

## Step 1: Create Azure App Registration

1. Go to **Azure Portal** → **Azure Active Directory**
2. Click **App registrations** → **New registration**
3. Fill in details:
   - **Name**: `SecOps Email Notification` or `Sentinel Anomaly Reporter`
   - **Supported account types**: Accounts in this organizational directory only
   - **Redirect URI**: Leave blank
4. Click **Register**
5. **Copy the Application (client) ID** - you'll need this later
6. **Copy the Directory (tenant) ID** - you'll need this later

---

## Step 2: Grant API Permissions

1. In your app registration, go to **API permissions**
2. Click **Add a permission**
3. Select **Microsoft Graph** → **Application permissions**
4. Search for and select: **Mail.Send**
5. Click **Add permissions**
6. **CRITICAL**: Click **Grant admin consent for [Your Organization]**
   - This requires admin privileges
   - Status should show green checkmark "Granted for [Your Organization]"

---

## Step 3: Create Client Secret

1. Go to **Certificates & secrets**
2. Click **New client secret**
3. Add description: `Sentinel Email Secret`
4. Select expiration: **24 months** (recommended)
5. Click **Add**
6. **IMMEDIATELY COPY THE SECRET VALUE** - you can't see it again!
   - The "Value" column shows the secret (starts with a long string)
   - Do NOT copy the "Secret ID" - that's different

---

## Step 4: Configure email-config.json

1. Open `email-config.json.template` in the repository root
2. Copy it to `email-config.json`:
   ```powershell
   Copy-Item email-config.json.template email-config.json
   ```
3. Edit `email-config.json` with your values:

```json
{
  "tenantId": "YOUR_TENANT_ID",          # From Step 1
  "clientId": "YOUR_CLIENT_ID",          # From Step 1  
  "clientSecret": "YOUR_CLIENT_SECRET",  # From Step 3
  "senderEmail": "sentinel-alerts@yourdomain.com",
  "recipientEmail": "ihussain@microsoft.com"
}
```

**Important Notes:**
- `senderEmail`: Must be a valid licensed mailbox in your tenant
- `recipientEmail`: Pre-configured to `ihussain@microsoft.com` (can be changed)
- `email-config.json` is in .gitignore - it will NOT be committed

---

## Step 5: Test Email Sending

### Test Mode (Validates Configuration)
```powershell
.\agents\Send-EmailReport.ps1 -TestMode
```

Should show:
```
✅ TEST MODE - Email validation successful
   Email body generated (XXXX characters)
   Would send to: ihussain@microsoft.com
   From: sentinel-alerts@yourdomain.com
```

### Send Real Email
```powershell
# Make sure you have a report first
.\agents\Comprehensive-Hunter.ps1

# Send the email
.\agents\Send-EmailReport.ps1
```

Should show:
```
🔐 Authenticating with Microsoft Graph... ✓
📧 Preparing email message... ✓
📤 Sending email... ✓

✅ Email sent successfully!
   To: ihussain@microsoft.com
   Subject: 🔒 Security Anomaly Report - XX anomalies detected
   Attachments: 1
```

---

## Common Issues and Solutions

### ❌ "Configuration incomplete: clientSecret not set"

**Cause**: You didn't fill in the values in `email-config.json`

**Solution**: Edit `email-config.json` and replace all `YOUR_*` placeholders with actual values

---

### ❌ "Authentication failed"

**Cause**: Invalid tenant ID, client ID, or client secret

**Solution**:
1. Verify tenant ID and client ID in Azure Portal → App Registration
2. If secret expired, create a new one (Step 3)
3. Make sure you copied the SECRET VALUE, not the Secret ID

---

### ❌ "Mail.Send permission not granted"

**Cause**: Admin consent not granted for Mail.Send permission

**Solution**:
1. Go to Azure Portal → App Registration → API permissions
2. Click "Grant admin consent for [Your Organization]"
3. Ensure green checkmark appears next to Mail.Send

---

### ❌ "Mailbox not found"

**Cause**: The sender email address doesn't exist or isn't licensed

**Solution**:
1. Verify the mailbox exists in your tenant
2. Ensure it has an Exchange Online license
3. Try using your own email as sender for testing

---

### ❌ "Report file not found"

**Cause**: No detection reports have been generated yet

**Solution**:
```powershell
# Run detection first
.\agents\Comprehensive-Hunter.ps1

# Then send email
.\agents\Send-EmailReport.ps1
```

---

## Security Best Practices

### 1. Use Certificate Authentication (Advanced)

For production, consider using certificate-based authentication instead of client secrets:

```powershell
# Create self-signed cert (for testing)
$cert = New-SelfSignedCertificate -Subject "CN=SentinelEmailCert" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable

# Upload .cer file to Azure App Registration → Certificates & secrets
```

### 2. Rotate Client Secrets Regularly

- Set calendar reminder before 24-month expiration
- Create new secret before old one expires
- Update `email-config.json` with new secret

### 3. Principle of Least Privilege

- Only grant **Mail.Send** permission (not Mail.ReadWrite)
- Use Application permissions, not Delegated
- Don't share client secret with anyone

### 4. Monitor Usage

- Review Azure AD sign-in logs for the app
- Set up alerts for suspicious authentication patterns

---

## Integration with Automated Workflows

### Option 1: Email After Every Scan

Edit `Comprehensive-Hunter.ps1` to add at the end:

```powershell
# Send email after detection
if ($TotalAnomalies -gt 0) {
    & .\agents\Send-EmailReport.ps1
}
```

### Option 2: Scheduled Task with Email

```powershell
# Windows Task Scheduler
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\App\loop\agents\Fully-Automated-Hunter.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 8am
Register-ScheduledTask -TaskName "Sentinel Anomaly Scan" -Action $action -Trigger $trigger
```

---

## Testing Checklist

- [ ] App registration created
- [ ] Mail.Send permission granted with admin consent
- [ ] Client secret created and copied
- [ ] email-config.json configured with all values
- [ ] Test mode passes: `.\agents\Send-EmailReport.ps1 -TestMode`
- [ ] Real email sent successfully
- [ ] Email received at recipient inbox
- [ ] HTML attachment opens correctly
- [ ] No sensitive data (tokens, secrets) committed to git

---

## Next Steps

- [Email Setup TODO Checklist](EMAIL-SETUP-TODO.md)
- [Automated Runner Guide](AUTOMATED-RUNNER-GUIDE.md)
- [Multi-Tenant Setup](MULTI-TENANT-SETUP.md)

---

**Last Updated**: January 28, 2026  
**Status**: ✅ Complete and tested
