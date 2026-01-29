# Email Setup TODO Checklist

## Prerequisites Check

- [ ] **Azure AD Access**: You have Application Administrator or Global Administrator role
- [ ] **Azure Portal Access**: Can access portal.azure.com
- [ ] **PowerShell**: PowerShell 5.1 or later installed
- [ ] **Repository**: Cloned and ready at C:\App\loop

---

## Step 1: Azure App Registration

- [ ] Open Azure Portal (portal.azure.com)
- [ ] Navigate to Azure Active Directory
- [ ] Go to App Registrations
- [ ] Click "New registration"
- [ ] Enter Name: "SecOps Email Notification" or "Sentinel Anomaly Reporter"
- [ ] Select: "Accounts in this organizational directory only"
- [ ] Leave Redirect URI blank
- [ ] Click "Register"
- [ ] ✏️ **Copy Application (client) ID**: `_______________________________`
- [ ] ✏️ **Copy Directory (tenant) ID**: `_______________________________`

---

## Step 2: API Permissions

- [ ] In your app, go to "API permissions"
- [ ] Click "Add a permission"
- [ ] Select "Microsoft Graph"
- [ ] Choose "Application permissions" (NOT Delegated)
- [ ] Search for "Mail.Send"
- [ ] Check the box next to "Mail.Send"
- [ ] Click "Add permissions"
- [ ] Click "Grant admin consent for [Your Organization]"
- [ ] Verify green checkmark appears: "Granted for [Your Organization]"

---

## Step 3: Client Secret

- [ ] Go to "Certificates & secrets"
- [ ] Click "New client secret"
- [ ] Description: "Sentinel Email Secret"
- [ ] Expires: 24 months
- [ ] Click "Add"
- [ ] ✏️ **IMMEDIATELY copy the Value (not Secret ID)**: `_______________________________`
- [ ] ⚠️ **Warning**: You cannot see this value again after leaving the page!

---

## Step 4: Sender Mailbox

- [ ] Identify or create a service mailbox for sending emails
- [ ] Verify mailbox exists in your tenant
- [ ] Verify mailbox has Exchange Online license
- [ ] ✏️ **Sender email address**: `_______________________________`

Examples:
- sentinel-alerts@yourdomain.com
- security-reports@yourdomain.com
- anomaly-hunter@yourdomain.com

---

## Step 5: Configure email-config.json

- [ ] Open PowerShell in `C:\App\loop`
- [ ] Run: `Copy-Item email-config.json.template email-config.json`
- [ ] Edit `email-config.json` with your values:

```json
{
  "tenantId": "[Paste Tenant ID from Step 1]",
  "clientId": "[Paste Client ID from Step 1]",
  "clientSecret": "[Paste Secret Value from Step 3]",
  "senderEmail": "[Your sender mailbox from Step 4]",
  "recipientEmail": "ihussain@microsoft.com"
}
```

- [ ] Save the file
- [ ] Verify .gitignore includes `email-config.json` (it should already)

---

## Step 6: Test Configuration

- [ ] Run test mode:
  ```powershell
  .\agents\Send-EmailReport.ps1 -TestMode
  ```
- [ ] Verify success message appears
- [ ] Should see: "✅ TEST MODE - Email validation successful"

If test fails, check:
- [ ] All values in email-config.json are filled (no "YOUR_*" placeholders)
- [ ] Client secret copied correctly (not the Secret ID)
- [ ] Tenant ID and Client ID are correct

---

## Step 7: Generate Test Report

- [ ] Run detection to create a report:
  ```powershell
  .\agents\Comprehensive-Hunter.ps1
  ```
- [ ] Verify report created in `.\reports\` folder
- [ ] Should see JSON and CSV files

---

## Step 8: Send Real Email

- [ ] Send email with report:
  ```powershell
  .\agents\Send-EmailReport.ps1
  ```
- [ ] Verify success message: "✅ Email sent successfully!"
- [ ] Check recipient inbox (ihussain@microsoft.com)
- [ ] Verify email received with:
  - [ ] Subject: "🔒 Security Anomaly Report..."
  - [ ] HTML body with executive summary
  - [ ] HTML attachment (anomaly-report.html)

---

## Step 9: Security Verification

- [ ] Verify `email-config.json` is NOT tracked by git:
  ```powershell
  git status
  ```
- [ ] Should NOT see `email-config.json` in the output
- [ ] Verify .gitignore contains `email-config.json`

---

## Step 10: Optional Automation

If you want automated daily emails:

- [ ] Edit `Fully-Automated-Hunter.ps1` to add email sending
- [ ] OR set up Windows Task Scheduler to run both scripts
- [ ] Test scheduled task works correctly

---

## Troubleshooting Reference

If you encounter issues, see:
- [STEP-BY-STEP-EMAIL-SETUP.md](STEP-BY-STEP-EMAIL-SETUP.md) - Detailed walkthrough
- [EMAIL-SETUP-GUIDE.md](EMAIL-SETUP-GUIDE.md) - Quick reference

### Common Issues

**"Configuration incomplete"**
→ Fill in all values in email-config.json

**"Authentication failed"**
→ Verify tenant ID, client ID, client secret are correct

**"Mail.Send permission not granted"**
→ Grant admin consent in Azure Portal

**"Mailbox not found"**
→ Ensure sender email exists with Exchange license

**"Report file not found"**
→ Run Comprehensive-Hunter.ps1 first

---

## Completion

- [ ] All steps completed successfully
- [ ] Test email sent and received
- [ ] email-config.json configured and not in git
- [ ] Ready for production use

---

**Status**: Ready to use!  
**Setup Time**: ~10-15 minutes  
**Next**: [AUTOMATED-RUNNER-GUIDE.md](AUTOMATED-RUNNER-GUIDE.md)
