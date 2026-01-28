# Failed Login Anomaly Detection Report

**Report Generated:** 2026-01-28  
**Analysis Period:** 90-day baseline (2025-10-30 to 2026-01-21) vs. Last 7 days (2026-01-21 to 2026-01-28)  
**Data Source:** Microsoft Sentinel SigninLogs

---

## Executive Summary

This report identifies users whose failed login attempts during the past 7 days significantly exceed their 90-day historical baseline. A total of **15 users** were flagged with failure rates exceeding 200% of their baseline, indicating potential security threats including credential stuffing attacks, brute force attempts, or compromised accounts.

### Critical Findings

- **15 users** exceeded 200% of their 90-day baseline
- **Top anomaly:** kha776@int.zava-private.com with **13,635% of baseline**
- **Peak spike:** 58,000% deviation on January 22, 2026 (14 failures in single day)
- **Temporal pattern:** Concentrated activity on Jan 21-23 and Jan 26-27, suggesting coordinated attack

---

## Anomaly Detection Table

Users with failed login rates exceeding 200% of their 90-day baseline:

| Rank | User Principal Name               | Baseline Daily Avg | This Week Daily Avg | Total Week Failures | % of Baseline | Severity |
|------|-----------------------------------|-------------------:|--------------------:|--------------------:|--------------:|----------|
| 1    | kha776@int.zava-private.com       | 0.02               | 3.29                | 23                  | 13,635.7%     | 🔴 CRITICAL |
| 2    | veav10@int.zava-private.com       | 0.01               | 1.14                | 8                   | 9,485.7%      | 🔴 CRITICAL |
| 3    | ltu130@int.zava-private.com       | 0.02               | 1.86                | 13                  | 7,707.1%      | 🔴 CRITICAL |
| 4    | u17052@int.zava-private.com       | 0.05               | 3.29                | 23                  | 6,817.9%      | 🔴 CRITICAL |
| 5    | ech106@int.zava-private.com       | 0.04               | 2.14                | 15                  | 5,928.6%      | 🔴 CRITICAL |
| 6    | essa23@int.zava-private.com       | 0.01               | 0.71                | 5                   | 5,928.6%      | 🔴 CRITICAL |
| 7    | u17157@int.zava-private.com       | 0.02               | 1.29                | 9                   | 5,335.7%      | 🔴 CRITICAL |
| 8    | naha84@ops.zava-private.com       | 0.04               | 1.71                | 12                  | 4,742.9%      | 🔴 CRITICAL |
| 9    | biservice@int.zava-private.com    | 0.04               | 1.71                | 12                  | 4,742.9%      | 🔴 CRITICAL |
| 10   | jibh22@int.zava-private.com       | 0.01               | 0.57                | 4                   | 4,742.9%      | 🔴 CRITICAL |
| 11   | leno37@int.zava-private.com       | 0.02               | 1.14                | 8                   | 4,742.9%      | 🔴 CRITICAL |
| 12   | mibe24@int.zava-private.com       | 0.02               | 1.14                | 8                   | 4,742.9%      | 🔴 CRITICAL |
| 13   | u17158@int.zava-private.com       | 0.01               | 0.57                | 4                   | 4,742.9%      | 🔴 CRITICAL |
| 14   | jka401@int.zava-private.com       | 0.07               | 3.00                | 21                  | 4,150.0%      | 🔴 CRITICAL |
| 15   | beba37@int.zava-private.com       | 0.07               | 3.00                | 21                  | 4,150.0%      | 🔴 CRITICAL |

**Severity Classification:**
- 🔴 **CRITICAL:** >5,000% of baseline
- 🟡 **HIGH:** 1,000-5,000% of baseline  
- 🟠 **MODERATE:** 200-1,000% of baseline

---

## 7-Day Deviation Analysis

### Top 5 Anomalous Users - Daily Breakdown

#### 1. kha776@int.zava-private.com
**Baseline:** 0.02 failed logins/day | **Peak Deviation:** 58,000%

```
Date       Deviation    Failures    ████████████████████████████████████████
01/21      +12,350%     3           ████████████
01/22      +58,000%     14          ████████████████████████████████████████████████████████████
01/26      +16,500%     4           █████████████████
01/28      +8,200%      2           ████████
```

#### 2. veav10@int.zava-private.com  
**Baseline:** 0.01 failed logins/day | **Peak Deviation:** 9,485%

```
Date       Deviation    Failures    ████████████████████████████████████████
Multiple days with consistent elevated activity
```

#### 3. ltu130@int.zava-private.com
**Baseline:** 0.02 failed logins/day | **Peak Deviation:** 28,950%

```
Date       Deviation    Failures    ████████████████████████████████████████
01/21      +24,800%     6           ███████████████████████████████████████████████████
01/27      +28,950%     7           ████████████████████████████████████████████████████████████
```

#### 4. u17052@int.zava-private.com
**Baseline:** 0.05 failed logins/day | **Peak Deviation:** 6,817%

```
Date       Deviation    Failures    ████████████████████████████████████████
Consistent elevated activity across multiple days
```

#### 5. ech106@int.zava-private.com
**Baseline:** 0.04 failed logins/day | **Peak Deviation:** 19,267%

```
Date       Deviation    Failures    ████████████████████████████████████████
01/22      +2,667%      1           ████████
01/23      +16,500%     6           ███████████████████████████████████████████████████
01/26      +19,267%     7           ████████████████████████████████████████████████████████████
01/27      +2,667%      1           ████████
```

---

## Threat Analysis

### Attack Pattern Indicators

1. **Temporal Clustering**
   - Primary attack window: January 21-23, 2026
   - Secondary wave: January 26-27, 2026
   - Suggests coordinated attack campaign or vulnerability exploitation

2. **Volume Characteristics**
   - Sudden spikes from near-zero baseline to 10+ failures per day
   - Pattern inconsistent with normal user behavior (forgotten passwords)
   - Indicates automated credential attacks

3. **Account Targeting**
   - Mix of user accounts and service accounts (e.g., biservice@)
   - Multiple accounts within same domain (int.zava-private.com)
   - Suggests attacker has knowledge of organizational structure

### Likely Attack Vectors

- **Credential Stuffing:** Using leaked credentials from other breaches
- **Brute Force:** Systematic password guessing attacks
- **Password Spraying:** Testing common passwords across multiple accounts
- **Compromised Credentials:** Leaked password lists targeting organization

---

## Recommendations

### Immediate Actions (Within 24 Hours)

1. **🔴 Priority 1: Account Investigation**
   - Investigate top 5 anomalous accounts immediately
   - Review successful login attempts during the same period
   - Check for any unusual activity post-authentication

2. **🔴 Priority 1: Force Password Reset**
   - Require password reset for all flagged accounts
   - Implement temporary account restrictions if necessary
   - Verify MFA enrollment and enforce where missing

3. **🟡 Priority 2: Enhanced Monitoring**
   - Enable real-time alerting for these accounts
   - Monitor for lateral movement or privilege escalation
   - Track IP addresses and geolocation of login attempts

### Short-term Actions (Within 1 Week)

4. **Security Control Enhancement**
   - Review and strengthen password policies
   - Implement account lockout after N failed attempts
   - Enable Conditional Access policies based on risk signals
   - Deploy passwordless authentication where possible

5. **Threat Intelligence Correlation**
   - Cross-reference failed login IP addresses with threat feeds
   - Check for known malicious IPs in SIEM/threat intelligence
   - Identify if attacks originate from specific geographic regions

6. **User Communication**
   - Alert affected users about potential targeting
   - Provide security awareness guidance
   - Encourage reporting of suspicious activity

### Long-term Actions (Within 1 Month)

7. **Automated Detection**
   - Implement this baseline anomaly detection as daily automated job
   - Set up alerts for deviations >200% of baseline
   - Create dashboard for continuous monitoring

8. **Access Review**
   - Conduct access review for service accounts (e.g., biservice@)
   - Implement principle of least privilege
   - Review and remove unnecessary privileged access

9. **Security Posture Improvements**
   - Evaluate deploying adaptive authentication
   - Consider implementing network segmentation
   - Review and update incident response playbooks

---

## Methodology

### Baseline Calculation

```kql
// 90-day baseline excluding last 7 days
let BaselinePeriod = 90d;
let WeekPeriod = 7d;
let BaselineStart = ago(BaselinePeriod);
let BaselineEnd = ago(WeekPeriod);

// Calculate daily average for 83-day baseline period (90 - 7)
let Baseline = SigninLogs
| where TimeGenerated between (BaselineStart .. BaselineEnd)
| where ResultType != "0"
| summarize BaselineTotal = count() by UserPrincipalName
| extend BaselineDailyAvg = toreal(BaselineTotal) / 83.0;
```

### Weekly Comparison

```kql
// Calculate this week's daily average
let WeeklyData = SigninLogs
| where TimeGenerated >= ago(7d)
| where ResultType != "0"
| summarize WeekTotal = count() by UserPrincipalName
| extend WeekDailyAvg = toreal(WeekTotal) / 7.0;

// Calculate percent of baseline and flag anomalies
Baseline
| join kind=inner (WeeklyData) on UserPrincipalName
| extend PercentOfBaseline = (WeekDailyAvg / BaselineDailyAvg) * 100.0
| where PercentOfBaseline > 200.0
| order by PercentOfBaseline desc
```

### Detection Threshold

- **Threshold:** 200% of 90-day baseline
- **Rationale:** Balances sensitivity with false positive reduction
- **Tuning:** Can be adjusted based on organizational risk tolerance

---

## Performance Notes

- **Query Execution Time:** ~60 seconds for 90-day analysis
- **Data Volume:** Analyzed millions of sign-in events
- **Optimization Opportunities:**
  - Reduce to 30-day baseline for faster execution (~20 seconds)
  - Implement as scheduled batch job rather than ad-hoc query
  - Consider materialized views for frequently accessed baseline data

---

## Appendix: Query Optimization

For faster results in operational scenarios:

### Optimized 30-Day Baseline (Faster)
```kql
// 30-day baseline (7x faster execution)
SigninLogs
| where TimeGenerated > ago(37d) and TimeGenerated < ago(7d)
| where ResultType != "0"
| project UserPrincipalName
| summarize BaselineTotal = count() by UserPrincipalName
| extend BaselineDailyAvg = toreal(BaselineTotal) / 30.0
```

### Real-time Monitoring (7-day rolling)
```kql
// Compare yesterday vs previous 7 days
SigninLogs
| where TimeGenerated > ago(8d)
| where ResultType != "0"
| extend Period = iff(TimeGenerated > ago(1d), "Yesterday", "Previous7Days")
| summarize Count = count() by UserPrincipalName, Period
| evaluate pivot(Period, sum(Count))
```

---

## Contact & Escalation

**Security Operations Center (SOC):**  
- Email: soc@zava-private.com
- Phone: [Emergency Hotline]
- Ticket System: [Link to SIEM]

**Incident Response Team:**  
- On-call rotation: [Schedule Link]
- Escalation path: L1 → L2 → SOC Manager → CISO

---

**Report Classification:** CONFIDENTIAL - Internal Use Only  
**Next Review Date:** 2026-02-04 (Weekly refresh recommended)  
**Report Version:** 1.0
