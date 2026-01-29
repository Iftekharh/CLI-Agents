<#
.SYNOPSIS
    Email Report Sender using Microsoft Graph API
.DESCRIPTION
    Sends security anomaly reports via email with HTML/PDF attachments
.PARAMETER TestMode
    Run in test mode (validates configuration without sending email)
.PARAMETER ReportPath
    Path to the JSON report file (default: latest in reports/)
.EXAMPLE
    .\Send-EmailReport.ps1
    .\Send-EmailReport.ps1 -TestMode
    .\Send-EmailReport.ps1 -ReportPath ".\reports\comprehensive-report-20260128-202824.json"
#>

param(
    [switch]$TestMode,
    [string]$ReportPath
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║            EMAIL REPORT SENDER - Microsoft Graph API         ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Load email configuration
$configPath = ".\email-config.json"
if (!(Test-Path $configPath)) {
    Write-Host "❌ Email configuration not found: $configPath" -ForegroundColor Red
    Write-Host "   Copy email-config.json.template to email-config.json and configure it" -ForegroundColor Yellow
    Write-Host "   See: docs\STEP-BY-STEP-EMAIL-SETUP.md" -ForegroundColor Yellow
    exit 1
}

$config = Get-Content $configPath | ConvertFrom-Json

# Validate configuration
$required = @('tenantId', 'clientId', 'clientSecret', 'senderEmail', 'recipientEmail')
foreach ($field in $required) {
    if (!$config.$field -or $config.$field -eq "YOUR_$($field.ToUpper())" -or $config.$field -match "^<.*>$") {
        Write-Host "❌ Configuration incomplete: $field not set" -ForegroundColor Red
        Write-Host "   Edit $configPath and fill in all values" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "✓ Configuration loaded" -ForegroundColor Green
Write-Host "  Tenant: $($config.tenantId)" -ForegroundColor Gray
Write-Host "  Sender: $($config.senderEmail)" -ForegroundColor Gray
Write-Host "  Recipient: $($config.recipientEmail)" -ForegroundColor Gray

# Find report file
if (!$ReportPath) {
    $ReportPath = Get-ChildItem ".\reports\comprehensive-report-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
    if (!$ReportPath) {
        Write-Host "❌ No report files found in .\reports\" -ForegroundColor Red
        Write-Host "   Run: .\agents\Comprehensive-Hunter.ps1" -ForegroundColor Yellow
        exit 1
    }
}

if (!(Test-Path $ReportPath)) {
    Write-Host "❌ Report file not found: $ReportPath" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Report file: $ReportPath" -ForegroundColor Green

# Load report data
$report = Get-Content $ReportPath | ConvertFrom-Json
$timestamp = $report.Timestamp
$totalAnomalies = $report.TotalAnomalies

# Get top 5 critical/high severity anomalies
$topThreats = $report.Anomalies | Where-Object { $_.Severity -in @("Critical", "High") } | Select-Object -First 5

# Build executive summary
$criticalCount = ($report.Anomalies | Where-Object { $_.Severity -eq "Critical" }).Count
$highCount = ($report.Anomalies | Where-Object { $_.Severity -eq "High" }).Count
$mediumCount = ($report.Anomalies | Where-Object { $_.Severity -eq "Medium" }).Count

# Generate email body HTML
$emailBody = @"
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; }
        .summary { background: #f8f9fa; padding: 15px; border-left: 4px solid #667eea; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-value { font-size: 24px; font-weight: bold; }
        .critical { color: #dc3545; }
        .high { color: #fd7e14; }
        .medium { color: #ffc107; }
        .threat-list { background: white; padding: 15px; border: 1px solid #dee2e6; border-radius: 5px; }
        .threat-item { padding: 10px; border-bottom: 1px solid #eee; }
        .threat-item:last-child { border-bottom: none; }
        .footer { color: #6c757d; font-size: 12px; margin-top: 30px; padding-top: 20px; border-top: 1px solid #dee2e6; }
    </style>
</head>
<body>
    <div class="header">
        <h2>🔒 Security Anomaly Detection Report</h2>
        <p>Microsoft Sentinel MCP - Comprehensive Hunter</p>
    </div>
    
    <div class="summary">
        <h3>📊 Executive Summary</h3>
        <p><strong>Detection Period:</strong> Last $($report.DetectionDays) days (baseline: $($report.BaselineDays) days)</p>
        <p><strong>Total Anomalies Detected:</strong> $totalAnomalies</p>
        
        <div class="metric">
            <div class="metric-value critical">$criticalCount</div>
            <div>Critical</div>
        </div>
        <div class="metric">
            <div class="metric-value high">$highCount</div>
            <div>High</div>
        </div>
        <div class="metric">
            <div class="metric-value medium">$mediumCount</div>
            <div>Medium</div>
        </div>
    </div>
    
    <div class="threat-list">
        <h3>🎯 Top Priority Threats</h3>
"@

foreach ($threat in $topThreats) {
    $severityClass = $threat.Severity.ToLower()
    $emailBody += @"
        <div class="threat-item">
            <strong class="$severityClass">[$($threat.Severity)]</strong> 
            <strong>$($threat.Module)</strong><br>
            <em>User:</em> $($threat.User)<br>
            <em>Details:</em> $($threat.Description)
        </div>
"@
}

$emailBody += @"
    </div>
    
    <div style="margin-top: 20px;">
        <h3>📋 Next Steps</h3>
        <ol>
            <li>Review attached comprehensive report (HTML/PDF)</li>
            <li>Investigate critical and high-severity anomalies</li>
            <li>Verify legitimate business activity vs potential threats</li>
            <li>Take appropriate remediation actions</li>
        </ol>
    </div>
    
    <div class="footer">
        <p>This is an automated security report generated by Sentinel MCP Comprehensive Hunter.</p>
        <p>Report generated: $timestamp</p>
    </div>
</body>
</html>
"@

if ($TestMode) {
    Write-Host "`n✅ TEST MODE - Email validation successful" -ForegroundColor Green
    Write-Host "   Email body generated ($($emailBody.Length) characters)" -ForegroundColor Gray
    Write-Host "   Would send to: $($config.recipientEmail)" -ForegroundColor Gray
    Write-Host "   From: $($config.senderEmail)" -ForegroundColor Gray
    exit 0
}

# Get access token from Microsoft Graph
Write-Host "`n🔐 Authenticating with Microsoft Graph..." -NoNewline

$tokenBody = @{
    grant_type    = "client_credentials"
    scope         = "https://graph.microsoft.com/.default"
    client_id     = $config.clientId
    client_secret = $config.clientSecret
}

try {
    $tokenResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$($config.tenantId)/oauth2/v2.0/token" -Body $tokenBody
    $accessToken = $tokenResponse.access_token
    Write-Host " ✓" -ForegroundColor Green
}
catch {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "   Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Verify your client ID, client secret, and tenant ID" -ForegroundColor Yellow
    exit 1
}

# Prepare email message
Write-Host "📧 Preparing email message..." -NoNewline

$subject = "🔒 Security Anomaly Report - $totalAnomalies anomalies detected"

# Base64 encode HTML report if it exists
$htmlReportPath = $ReportPath -replace '\.json$', '.html'
$attachments = @()

if (Test-Path $htmlReportPath) {
    $htmlContent = Get-Content $htmlReportPath -Raw -Encoding UTF8
    $htmlBytes = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
    $htmlBase64 = [System.Convert]::ToBase64String($htmlBytes)
    
    $attachments += @{
        "@odata.type" = "#microsoft.graph.fileAttachment"
        name = "anomaly-report.html"
        contentType = "text/html"
        contentBytes = $htmlBase64
    }
}

$emailMessage = @{
    message = @{
        subject = $subject
        body = @{
            contentType = "HTML"
            content = $emailBody
        }
        toRecipients = @(
            @{
                emailAddress = @{
                    address = $config.recipientEmail
                }
            }
        )
        attachments = $attachments
    }
    saveToSentItems = $true
}

Write-Host " ✓" -ForegroundColor Green

# Send email
Write-Host "📤 Sending email..." -NoNewline

try {
    $sendMailUri = "https://graph.microsoft.com/v1.0/users/$($config.senderEmail)/sendMail"
    
    Invoke-RestMethod -Method Post -Uri $sendMailUri `
        -Headers @{
            "Authorization" = "Bearer $accessToken"
            "Content-Type" = "application/json"
        } `
        -Body ($emailMessage | ConvertTo-Json -Depth 10)
    
    Write-Host " ✓" -ForegroundColor Green
    Write-Host "`n✅ Email sent successfully!" -ForegroundColor Green
    Write-Host "   To: $($config.recipientEmail)" -ForegroundColor Gray
    Write-Host "   Subject: $subject" -ForegroundColor Gray
    Write-Host "   Attachments: $($attachments.Count)" -ForegroundColor Gray
}
catch {
    Write-Host " ❌" -ForegroundColor Red
    Write-Host "   Failed to send email: $($_.Exception.Message)" -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        $errorDetail = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($errorDetail.error.message) {
            Write-Host "   Error: $($errorDetail.error.message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`n   Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   - Verify Mail.Send permission is granted with admin consent" -ForegroundColor Yellow
    Write-Host "   - Check sender mailbox exists and is licensed" -ForegroundColor Yellow
    Write-Host "   - Ensure client secret hasn't expired" -ForegroundColor Yellow
    Write-Host "   See: docs\STEP-BY-STEP-EMAIL-SETUP.md" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
