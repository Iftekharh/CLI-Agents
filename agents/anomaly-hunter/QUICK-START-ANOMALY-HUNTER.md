# Anomaly Hunter Agent - Quick Start Guide

## 🚀 Get Started in 3 Steps

### Step 1: Build Your Baseline (First Time Only)

```powershell
cd C:\App\loop\agents
.\anomaly-hunter-agent.ps1 -Mode baseline -Environment woodgrove
```

⏱️ **Time:** 5-10 minutes  
📊 **What it does:** Analyzes last 30 days to learn normal behavior

---

### Step 2: Run Your First Scan

```powershell
.\anomaly-hunter-agent.ps1 -Mode scan -Environment woodgrove
```

⏱️ **Time:** 2-5 minutes  
🔍 **What it does:** Detects anomalies in last 24 hours

---

### Step 3: Review Results

```powershell
# View latest markdown report
$report = Get-ChildItem C:\App\loop\reports\*.md | Sort-Object LastWriteTime -Descending | Select-Object -First 1
notepad $report.FullName
```

📄 **Reports saved to:** `C:\App\loop\reports\`

---

## 🎯 What Gets Detected

✅ **Impossible travel** - User in 2 countries within hours  
✅ **Off-hours logins** - Access at 2 AM  
✅ **Failed login spikes** - 20+ failed attempts  
✅ **Unusual applications** - Access to new apps  
✅ **Abnormal behavior** - Deviations from user's normal patterns  

---

## 📅 Daily Usage

Run this every morning:

```powershell
cd C:\App\loop\agents
.\anomaly-hunter-agent.ps1 -Mode scan -Environment woodgrove
```

Or schedule it (runs at 8 AM daily):

```powershell
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-File C:\App\loop\agents\anomaly-hunter-agent.ps1 -Mode scan -Environment woodgrove"

$trigger = New-ScheduledTaskTrigger -Daily -At "08:00"

Register-ScheduledTask -TaskName "Anomaly-Hunter-Daily" `
    -Action $action -Trigger $trigger
```

---

## ⚙️ Quick Configuration

Edit `anomaly-hunter-config.json` to customize:

```json
{
  "detection": {
    "modules": {
      "authenticationAnomalies": {
        "enabled": true,    // ← Turn on/off
        "priority": "High"
      }
    }
  }
}
```

---

## 🎨 Example Output

```
╔═══════════════════════════════════════════════════════════════════╗
║                    SCAN COMPLETE                                  ║
╚═══════════════════════════════════════════════════════════════════╝

Total Anomalies Found: 12

By Severity:
  Critical: 2
  High:     5
  Medium:   3
  Low:      2

Top 5 Anomalies:
  [Critical] ImpossibleTravel - alice@company.com: Tokyo to NYC in 3 hours
  [High] MultipleFailedLogins - bob@company.com: 25 failed attempts
  [High] UnusualLoginTime - charlie@company.com: Login at 03:00 AM
  [Medium] UnusualApplicationUsage - dave@company.com: 15 new apps
  [Medium] UnusualLoginTime - eve@company.com: Login at 23:00
```

---

## 🔧 Troubleshooting

### No anomalies found?

✓ Normal! Means your environment is secure  
✓ Try lowering risk thresholds in config  
✓ Ensure baseline was built properly  

### Query timeout?

```json
"performance": {
  "queryTimeoutSeconds": 600  // ← Increase this
}
```

### Need help?

Read the full documentation:
```powershell
notepad C:\App\loop\agents\ANOMALY-HUNTER-README.md
```

---

## 📚 Next Steps

1. ✅ **Schedule daily scans** (see above)
2. ✅ **Rebuild baseline weekly** (Sunday mornings)
3. ✅ **Tune detection** based on your environment
4. ✅ **Enable Teams/Email alerts** in config
5. ✅ **Build more agents** from `security-agent-use-cases.md`

---

## 🎓 Pro Tips

💡 **Rebuild baseline after:**
- Major organizational changes
- New security policies
- Holiday periods (different behavior)

💡 **Best practice:**
- Review reports daily
- Investigate Critical/High immediately
- Batch review Medium/Low weekly

💡 **Performance:**
- Run during off-peak hours
- Use caching for faster results
- Adjust concurrent queries if needed

---

**Happy hunting! 🎯**

For detailed docs: `ANOMALY-HUNTER-README.md`  
For more agents: `security-agent-use-cases.md`
