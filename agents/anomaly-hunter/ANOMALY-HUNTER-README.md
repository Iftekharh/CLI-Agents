# Anomaly Hunter Agent - Documentation

## Overview

The Anomaly Hunter Agent is an intelligent security automation tool that continuously monitors Microsoft Sentinel data to detect anomalous patterns and behaviors that may indicate security threats.

---

## Features

### Detection Capabilities

1. **Authentication Anomalies**
   - Unusual login times (off-hours access)
   - Impossible travel (geographically impossible logins)
   - Multiple failed login attempts
   - Unusual user agents
   - New location access

2. **User Behavior Anomalies**
   - Deviations from normal application usage
   - Working hours violations
   - Resource access pattern changes
   - Role-based activity anomalies

3. **Data Access Anomalies**
   - Unusual data volume access
   - Bulk downloads
   - Sensitive data access patterns
   - Query pattern anomalies

4. **Network Anomalies**
   - Connections to unusual destinations
   - Unusual protocols
   - Abnormal data transfer volumes

5. **Privilege Anomalies**
   - Unexpected privilege escalation
   - Unusual admin activity
   - Service account misuse

### Baseline Learning

The agent builds behavioral baselines over configurable time periods (default: 30 days) to understand normal patterns before flagging deviations.

### Risk Scoring

Each anomaly is assigned a risk score (0-100) based on:
- Deviation magnitude
- Historical frequency
- Entity risk profile
- Time context
- Correlation with other events

### Automated Reporting

Generates comprehensive reports in multiple formats:
- JSON (machine-readable)
- Markdown (human-readable)
- CSV (for analysis)

---

## Installation

### Prerequisites

- Windows PowerShell 5.1 or later
- Microsoft Sentinel MCP access configured
- MCP environment profiles set up (see `README.md`)

### Setup

1. **Directory Structure Created:**
   ```
   C:\App\loop\
   ├── agents\
   │   ├── anomaly-hunter-agent.ps1
   │   └── anomaly-hunter-config.json
   ├── baselines\       (baseline storage)
   ├── anomalies\       (anomaly findings)
   └── reports\         (generated reports)
   ```

2. **Configuration:**
   Edit `C:\App\loop\agents\anomaly-hunter-config.json` to customize:
   - Detection modules to enable/disable
   - Severity thresholds
   - Alert methods
   - Reporting preferences

---

## Usage

### First Time: Build Baseline

Before running anomaly detection, build a baseline of normal behavior:

```powershell
cd C:\App\loop\agents
.\anomaly-hunter-agent.ps1 -Mode baseline -Environment woodgrove
```

This will:
- Connect to Sentinel MCP
- Analyze the last 30 days of data
- Build behavioral profiles
- Save baseline to `C:\App\loop\baselines\`

**Estimated time:** 5-10 minutes (depending on data volume)

### Run Anomaly Scan

Once baseline is established, run anomaly detection:

```powershell
.\anomaly-hunter-agent.ps1 -Mode scan -Environment woodgrove
```

This will:
- Load the current baseline
- Query Sentinel for recent activity (last 24 hours)
- Compare against baseline
- Score anomalies
- Generate reports

**Estimated time:** 2-5 minutes

### Interactive Mode

For interactive investigation:

```powershell
.\anomaly-hunter-agent.ps1 -Mode scan -Interactive
```

Provides detailed output and allows exploration of findings.

---

## Example Workflows

### Daily Morning Security Check

```powershell
# Run at 8 AM daily
cd C:\App\loop\agents
.\anomaly-hunter-agent.ps1 -Mode scan -Environment woodgrove

# Review the markdown report
$latestReport = Get-ChildItem C:\App\loop\reports\*.md | Sort-Object LastWriteTime -Descending | Select-Object -First 1
notepad $latestReport.FullName
```

### Weekly Baseline Refresh

```powershell
# Run every Sunday
.\anomaly-hunter-agent.ps1 -Mode baseline -Environment woodgrove
```

### Automated Scheduled Scanning

Create a Windows Scheduled Task:

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\App\loop\agents\anomaly-hunter-agent.ps1 -Mode scan -Environment woodgrove"

$trigger = New-ScheduledTaskTrigger -Daily -At "08:00"

Register-ScheduledTask -TaskName "Anomaly-Hunter-Daily" -Action $action -Trigger $trigger -Description "Daily anomaly detection scan"
```

---

## Configuration Guide

### anomaly-hunter-config.json

#### Baseline Settings

```json
"baseline": {
  "enabled": true,
  "baselinePeriodDays": 30,        // How many days to analyze for baseline
  "minimumDataPoints": 10,          // Minimum events required
  "refreshIntervalHours": 24,       // How often to rebuild
  "storageLocation": "C:\\App\\loop\\baselines"
}
```

#### Detection Modules

Enable/disable specific detection types:

```json
"detection": {
  "modules": {
    "authenticationAnomalies": {
      "enabled": true,
      "priority": "High",
      "checks": [
        "unusual_login_times",
        "unusual_locations",
        "impossible_travel",
        "unusual_user_agent",
        "multiple_failed_logins"
      ]
    }
  }
}
```

#### Scoring Thresholds

Adjust risk score thresholds:

```json
"scoring": {
  "thresholds": {
    "critical": 90,   // Score >= 90 = Critical
    "high": 70,       // Score >= 70 = High
    "medium": 50,     // Score >= 50 = Medium
    "low": 30         // Score >= 30 = Low
  }
}
```

#### Alerting

Configure alert methods:

```json
"alerting": {
  "methods": {
    "email": {
      "enabled": false,
      "recipients": ["soc@company.com"],
      "severityThreshold": "High"
    },
    "file": {
      "enabled": true,
      "outputPath": "C:\\App\\loop\\anomalies",
      "severityThreshold": "Medium"
    }
  }
}
```

---

## Understanding Results

### Risk Scores

- **90-100 (Critical):** Immediate investigation required
- **70-89 (High):** Investigate within 1 hour
- **50-69 (Medium):** Investigate within 24 hours
- **30-49 (Low):** Monitor and review

### Anomaly Types

#### Impossible Travel
**Example:**
```
User: alice@company.com
Current Location: Tokyo, Japan
Previous Location: New York, USA
Time Difference: 2 hours
Risk Score: 80
```

**Action:** Investigate account compromise

#### Unusual Login Time
**Example:**
```
User: bob@company.com
Login Time: 02:30 AM (Local)
Normal Hours: 8 AM - 6 PM
Risk Score: 50
```

**Action:** Verify legitimate after-hours work

#### Multiple Failed Logins
**Example:**
```
User: admin@company.com
Failed Attempts: 25 (last hour)
Source IP: 192.168.1.100
Risk Score: 95
```

**Action:** Check for brute force attack

---

## Interpreting Reports

### Markdown Report Structure

```markdown
# Anomaly Hunter Report

## Summary by Severity
- Shows count per severity level

## Summary by Type
- Shows count per anomaly type

## Detailed Findings
- Individual anomaly details
- Risk scores
- User information
- Recommendations
```

### JSON Report Structure

```json
[
  {
    "Type": "ImpossibleTravel",
    "Severity": "High",
    "User": "user@company.com",
    "RiskScore": 80,
    "Description": "...",
    "Time": "2026-01-28T10:30:00Z",
    "CurrentLocation": "Tokyo",
    "PreviousLocation": "New York",
    "TimeDiffHours": 2
  }
]
```

---

## Tuning and Optimization

### Reducing False Positives

1. **Adjust Baselines:**
   - Increase `baselinePeriodDays` for more stable baselines
   - Increase `minimumDataPoints` to require more historical data

2. **Refine Detection Logic:**
   - Edit time thresholds for "off-hours" based on your organization
   - Whitelist known VPN IP ranges
   - Exclude service accounts from certain checks

3. **Adjust Scoring:**
   - Increase thresholds if too many false positives
   - Adjust weights to emphasize important factors

### Performance Tuning

```json
"performance": {
  "maxConcurrentQueries": 3,      // Parallel query execution
  "queryTimeoutSeconds": 300,     // Timeout for long queries
  "cacheResults": true,           // Cache query results
  "cacheTTLMinutes": 60           // Cache duration
}
```

---

## Integration with Other Tools

### Sentinel Incidents

Enable automatic incident creation:

```json
"alerting": {
  "methods": {
    "sentinelIncident": {
      "enabled": true,
      "severityThreshold": "High"
    }
  }
}
```

### Microsoft Teams

Get alerts in Teams:

```json
"alerting": {
  "methods": {
    "teams": {
      "enabled": true,
      "webhookUrl": "https://outlook.office.com/webhook/...",
      "severityThreshold": "Critical"
    }
  }
}
```

### Email Notifications

```json
"alerting": {
  "methods": {
    "email": {
      "enabled": true,
      "recipients": ["soc@company.com", "security@company.com"],
      "severityThreshold": "High"
    }
  }
}
```

---

## Troubleshooting

### "No baseline found"

**Solution:** Run baseline build first:
```powershell
.\anomaly-hunter-agent.ps1 -Mode baseline
```

### "Failed to connect to Sentinel"

**Solution:** Verify MCP environment:
```powershell
cd C:\App\loop
.\mcp-env.ps1 current
.\mcp-env.ps1 use woodgrove
```

### "Query timeout"

**Solution:** Increase timeout or reduce query scope:
```json
"performance": {
  "queryTimeoutSeconds": 600
}
```

### No anomalies detected

**Possible causes:**
- Baseline too recent (not enough normal behavior learned)
- No actual anomalies in the time window
- Detection thresholds too high

**Actions:**
- Run baseline over longer period
- Lower risk score thresholds
- Review baseline data quality

---

## Best Practices

1. **Baseline Management:**
   - Rebuild baseline weekly
   - Keep historical baselines for comparison
   - Adjust baseline period for seasonal variations

2. **Continuous Improvement:**
   - Review false positives weekly
   - Tune detection logic based on findings
   - Document known patterns to exclude

3. **Response Workflow:**
   - Triage by risk score
   - Investigate Critical/High immediately
   - Batch review Medium/Low daily

4. **Performance:**
   - Run during off-peak hours if possible
   - Monitor query execution times
   - Adjust concurrent query limit based on system load

5. **Security:**
   - Protect baseline files (contain behavioral data)
   - Audit agent configuration changes
   - Regularly review enabled detection modules

---

## Advanced Usage

### Custom Detection Modules

Add custom queries to the agent by editing detection functions:

```powershell
function Detect-CustomAnomaly {
    $query = @"
    // Your custom KQL query
    SigninLogs
    | where ...
"@
    
    $result = Invoke-SentinelQuery -Query $query
    # Process results...
}
```

### Baseline Enrichment

Enhance baselines with additional data sources:

```powershell
function Build-EnrichedBaseline {
    # Combine multiple data sources
    # Add threat intelligence
    # Include asset inventory
}
```

---

## Roadmap

### Planned Features

- [ ] Machine learning-based anomaly detection
- [ ] Automated response actions
- [ ] Real-time streaming detection
- [ ] Integration with SOAR platforms
- [ ] Mobile app notifications
- [ ] Customizable detection rules UI

---

## Support

For issues or questions:
- Review configuration guide
- Check troubleshooting section
- Enable debug logging: `$VerbosePreference = "Continue"`
- Review generated logs in reports directory

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `.\anomaly-hunter-agent.ps1 -Mode baseline` | Build baseline |
| `.\anomaly-hunter-agent.ps1 -Mode scan` | Run anomaly scan |
| `.\anomaly-hunter-agent.ps1 -Mode scan -Interactive` | Interactive mode |
| `.\mcp-env.ps1 use woodgrove` | Connect to environment |

**Configuration:** `C:\App\loop\agents\anomaly-hunter-config.json`  
**Reports:** `C:\App\loop\reports\`  
**Baselines:** `C:\App\loop\baselines\`  
**Anomalies:** `C:\App\loop\anomalies\`

---

**Version:** 1.0  
**Last Updated:** 2026-01-28
