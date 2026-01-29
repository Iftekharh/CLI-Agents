# Automated Runner Guide

## Overview

This guide covers the automated execution capabilities of the Sentinel MCP Anomaly Hunter framework.

## Available Automation Scripts

### 1. Run-AnomalyHunter.ps1 - Basic Automation

**Purpose**: Automated execution with token refresh

**Features:**
- ✅ Auto-refreshes authentication token
- ✅ Runs comprehensive detection
- ✅ Error handling and validation
- ✅ Generates JSON/CSV reports

**Usage:**
```powershell
.\agents\Run-AnomalyHunter.ps1

# With custom parameters
.\agents\Run-AnomalyHunter.ps1 -BaselineDays 90 -DetectionDays 14
```

### 2. Fully-Automated-Hunter.ps1 - Zero Prompts

**Purpose**: Complete automation with no user interaction

**Features:**
- ✅ Token refresh
- ✅ 12-module detection
- ✅ Report generation
- ✅ Summary output
- ✅ Zero user prompts

**Usage:**
```powershell
.\agents\Fully-Automated-Hunter.ps1
```

**Output:**
```
[1/3] Refreshing authentication... ✓
[2/3] Running 12-module detection... ✓
[3/3] Detection Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Total Anomalies: 541
  Report: comprehensive-report-20260128-202824.json

    • Failed Login Detection: 45
    • Geographic Analysis: 32
    • Activity Analysis: 78
    ...

✅ Fully automated scan complete!
```

### 3. run-agent.ps1 - Quick Alias

**Purpose**: Quick shortcut to run comprehensive hunter

**Usage:**
```powershell
.\agents\run-agent.ps1
```

Equivalent to: `.\agents\Comprehensive-Hunter.ps1`

## Automation Workflows

### Workflow 1: Daily Scheduled Scan

**Goal**: Run detection every day at 8 AM

**Setup with Windows Task Scheduler:**

```powershell
# Create scheduled task
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\App\loop\agents\Fully-Automated-Hunter.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 8am

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
    -TaskName "Sentinel Anomaly Scan" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -User "SYSTEM" `
    -RunLevel Highest
```

**Verify:**
```powershell
Get-ScheduledTask -TaskName "Sentinel Anomaly Scan"
```

**Test run:**
```powershell
Start-ScheduledTask -TaskName "Sentinel Anomaly Scan"
```

### Workflow 2: Multi-Tenant Daily Scan

**Goal**: Scan all tenants every day

**Script**: Create `Daily-Multi-Tenant-Scan.ps1`

```powershell
# Daily-Multi-Tenant-Scan.ps1
$tenants = @("woodgrove", "alpineskihouse", "customer-a")

foreach ($tenant in $tenants) {
    Write-Host "`nScanning $tenant..." -ForegroundColor Cyan
    
    # Switch tenant
    .\mcp-env.ps1 use $tenant
    
    # Run detection
    .\agents\Comprehensive-Hunter.ps1
    
    # Optional: Send email
    .\agents\Send-EmailReport.ps1
}
```

**Schedule:**
```powershell
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-File C:\App\loop\Daily-Multi-Tenant-Scan.ps1"

$trigger = New-ScheduledTaskTrigger -Daily -At 6am

Register-ScheduledTask `
    -TaskName "Multi-Tenant Security Scan" `
    -Action $action `
    -Trigger $trigger
```

### Workflow 3: Scan + Email

**Goal**: Run detection and automatically email results

**Option A**: Modify Fully-Automated-Hunter.ps1

Add at the end:
```powershell
# Send email after successful scan
if ($latestReport) {
    Write-Host "`n[4/4] Sending email report..." -ForegroundColor Yellow
    & .\agents\Send-EmailReport.ps1
}
```

**Option B**: Create wrapper script

```powershell
# Scan-And-Email.ps1
.\agents\Fully-Automated-Hunter.ps1

if ($LASTEXITCODE -eq 0) {
    .\agents\Send-EmailReport.ps1
}
```

### Workflow 4: Continuous Monitoring (Every 4 Hours)

**Setup:**
```powershell
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-File C:\App\loop\agents\Fully-Automated-Hunter.ps1"

# Run every 4 hours
$trigger = New-ScheduledTaskTrigger -Once -At 12am -RepetitionInterval (New-TimeSpan -Hours 4)

Register-ScheduledTask `
    -TaskName "Sentinel Continuous Monitor" `
    -Action $action `
    -Trigger $trigger
```

## Integration with CI/CD

### Azure DevOps Pipeline

```yaml
trigger:
  schedules:
  - cron: "0 8 * * *"  # Daily at 8 AM
    displayName: Daily Anomaly Scan
    branches:
      include:
      - main

pool:
  vmImage: 'windows-latest'

steps:
- task: AzureCLI@2
  inputs:
    azureSubscription: 'Sentinel-Connection'
    scriptType: 'ps'
    scriptLocation: 'inlineScript'
    inlineScript: |
      cd $(Build.SourcesDirectory)
      .\agents\Fully-Automated-Hunter.ps1

- task: PublishPipelineArtifact@1
  inputs:
    targetPath: '$(Build.SourcesDirectory)\reports'
    artifact: 'AnomalyReports'
```

### GitHub Actions

```yaml
name: Daily Anomaly Scan

on:
  schedule:
    - cron: '0 8 * * *'  # Daily at 8 AM UTC

jobs:
  scan:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Run Anomaly Scan
        shell: pwsh
        run: |
          .\agents\Fully-Automated-Hunter.ps1
      
      - name: Upload Reports
        uses: actions/upload-artifact@v2
        with:
          name: anomaly-reports
          path: reports/
```

## Error Handling

### Automatic Retry Logic

Create `Run-With-Retry.ps1`:

```powershell
param([int]$MaxRetries = 3)

$attempt = 0
$success = $false

while (-not $success -and $attempt -lt $MaxRetries) {
    $attempt++
    Write-Host "Attempt $attempt of $MaxRetries..." -ForegroundColor Yellow
    
    try {
        .\agents\Fully-Automated-Hunter.ps1
        $success = $true
    }
    catch {
        Write-Host "Failed: $_" -ForegroundColor Red
        if ($attempt -lt $MaxRetries) {
            Write-Host "Retrying in 60 seconds..." -ForegroundColor Yellow
            Start-Sleep -Seconds 60
        }
    }
}

if (-not $success) {
    Write-Host "All retries failed!" -ForegroundColor Red
    exit 1
}
```

### Logging

Create `Run-With-Logging.ps1`:

```powershell
$logDir = ".\logs"
if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir }

$logFile = Join-Path $logDir "scan-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

Start-Transcript -Path $logFile

try {
    .\agents\Fully-Automated-Hunter.ps1
}
finally {
    Stop-Transcript
}

# Keep only last 30 days of logs
Get-ChildItem $logDir -Filter "scan-*.log" | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | 
    Remove-Item
```

## Monitoring and Alerts

### Health Check Script

```powershell
# Check-ScanHealth.ps1
$latestReport = Get-ChildItem ".\reports\comprehensive-report-*.json" | 
    Sort-Object LastWriteTime -Descending | 
    Select-Object -First 1

if (!$latestReport) {
    Write-Host "❌ No reports found" -ForegroundColor Red
    exit 1
}

$age = (Get-Date) - $latestReport.LastWriteTime

if ($age.TotalHours -gt 25) {
    Write-Host "⚠️  Last report is $([int]$age.TotalHours) hours old" -ForegroundColor Yellow
    # Send alert email
}
else {
    Write-Host "✅ Reports are current" -ForegroundColor Green
}
```

### Performance Metrics

Track scan duration:

```powershell
# Run-With-Metrics.ps1
$startTime = Get-Date

.\agents\Fully-Automated-Hunter.ps1

$duration = (Get-Date) - $startTime

# Log to metrics file
@{
    Timestamp = Get-Date -Format "o"
    Duration = $duration.TotalSeconds
    Success = $LASTEXITCODE -eq 0
} | ConvertTo-Json | Add-Content ".\metrics.jsonl"

Write-Host "Scan completed in $([int]$duration.TotalMinutes) minutes"
```

## Best Practices

### 1. Token Management

```powershell
# Always refresh tokens before long-running scans
.\mcp-env.ps1 refresh

# Or use scripts that handle it automatically
.\agents\Run-AnomalyHunter.ps1  # Includes token refresh
```

### 2. Report Retention

```powershell
# Clean up old reports (keep last 90 days)
Get-ChildItem ".\reports" -Filter "*.json" | 
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-90) } | 
    Remove-Item
```

### 3. Notification on Failure

```powershell
# Add to scheduled task
try {
    .\agents\Fully-Automated-Hunter.ps1
}
catch {
    # Send failure notification
    Send-MailMessage `
        -From "sentinel@company.com" `
        -To "security-team@company.com" `
        -Subject "Anomaly Scan Failed" `
        -Body "Error: $_" `
        -SmtpServer "smtp.company.com"
}
```

### 4. Resource Management

```powershell
# Run during off-hours to avoid resource contention
$trigger = New-ScheduledTaskTrigger -Daily -At 2am

# Set lower priority for background scans
$settings = New-ScheduledTaskSettingsSet -Priority 7
```

## Troubleshooting Automation

### Task doesn't run

**Check:**
1. Task is enabled
2. Trigger is configured correctly
3. User account has permissions
4. Execution policy allows scripts

**Fix:**
```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass
```

### Script fails in scheduled task but works manually

**Common causes:**
- Different working directory
- Missing environment variables
- User account doesn't have access

**Fix:** Set working directory in action:
```powershell
$action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-File C:\App\loop\agents\Fully-Automated-Hunter.ps1" `
    -WorkingDirectory "C:\App\loop"
```

### Token expires during scheduled run

**Fix:** Ensure token refresh happens at start:
```powershell
# Use Run-AnomalyHunter.ps1 or Fully-Automated-Hunter.ps1
# Both include automatic token refresh
```

## See Also

- [Email Setup Guide](EMAIL-SETUP-GUIDE.md) - Configure email notifications
- [Multi-Tenant Setup](MULTI-TENANT-SETUP.md) - Multi-tenant automation
- [Quick Reference](QUICK-REFERENCE.md) - Command reference

---

**Recommended Starting Point**: Use `Fully-Automated-Hunter.ps1` with Windows Task Scheduler for daily scans
