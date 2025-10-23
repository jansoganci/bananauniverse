# 🚨 Alerting & Scheduling Automation System

## Overview

The alerting and scheduling system provides automated monitoring, alerting, and reporting for the cleanup infrastructure. It includes intelligent alert detection, Telegram notifications, and GitHub Actions-based scheduling.

## 🚀 Deployed Functions

### 1. Log Alert (`log-alert`) - NEW
- **URL**: `https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-alert`
- **Purpose**: Automated alert detection and notification
- **Frequency**: Daily at 3 AM UTC (via GitHub Actions)

### 2. Health Check (`health-check`) - UPDATED
- **URL**: `https://jiorfutbmahpfgplkats.supabase.co/functions/v1/health-check`
- **Purpose**: Real-time system health monitoring
- **Frequency**: Every 15 minutes (via GitHub Actions)
- **New Features**: `alerted` field, alert thresholds

### 3. Log Monitor (`log-monitor`) - UPDATED
- **URL**: `https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-monitor`
- **Purpose**: Weekly system statistics and reporting
- **Frequency**: Daily at 2 AM UTC (via GitHub Actions)
- **New Features**: `alerted` field, alert thresholds

## 📊 Alert Detection Logic

### Alert Thresholds
```typescript
const ALERT_THRESHOLDS = {
  maxErrors24h: 5,           // Alert if >5 errors in 24h
  maxCleanupDelayHours: 24   // Alert if no cleanup >24h
};
```

### Alert Conditions
1. **🚨 High Error Rate**: >5 errors in last 24 hours
2. **⚠️ Cleanup Delay**: No cleanup run in >24 hours
3. **❌ Database Unreachable**: Database connection failed

### Alert Status Levels
- **🟢 healthy**: No alerts needed
- **🟡 degraded**: Some issues detected (1-5 errors or cleanup delay)
- **🔴 critical**: Database disconnected or >5 errors

## 📋 Response Formats

### Log Alert Response
```json
{
  "status": "healthy",
  "errors_24h": 0,
  "last_cleanup_hours": 0.31,
  "alert_sent": false,
  "timestamp": "2025-10-19T21:29:06.490Z",
  "details": {
    "error_breakdown": {
      "cleanup_errors": 0,
      "api_errors": 0,
      "total_errors": 0
    },
    "cleanup_status": {
      "last_cleanup": "2025-10-19T21:10:22.192095+00:00",
      "hours_since_cleanup": 0.31,
      "cleanup_delay": false
    },
    "database_status": {
      "connected": true
    }
  }
}
```

### Updated Health Check Response
```json
{
  "status": "healthy",
  "database": "connected",
  "last_cleanup": "2025-10-19T21:10:22.192095+00:00",
  "errors_24h": 0,
  "timestamp": "2025-10-19T21:22:37.566Z",
  "alerted": false,
  "details": {
    "cleanup_images_last_run": "2025-10-19T21:10:22.192095+00:00",
    "cleanup_db_last_run": "2025-10-19T21:10:22.192095+00:00",
    "cleanup_logs_last_run": "2025-10-19T21:10:22.192095+00:00",
    "recent_errors": []
  }
}
```

### Updated Log Monitor Response
```json
{
  "weekly_cleanups": 8,
  "avg_exec_time": 113,
  "storage_freed_gb": 0,
  "errors": 0,
  "executionTime": 632,
  "alerted": true,
  "details": {
    "cleanup_breakdown": {
      "images": 3,
      "database": 4,
      "logs": 2
    },
    "error_breakdown": {
      "images": 0,
      "database": 0,
      "logs": 0
    },
    "top_operations": [
      {
        "operation": "cleanup_images",
        "count": 3,
        "avg_time": 0
      }
    ]
  }
}
```

## 🔔 Telegram Alert Messages

### System Alert (Degraded)
```
🚨 System Alert: Degraded

• 12 errors in last 24h
  - Cleanup: 8
  - API: 4
• Last cleanup: 26h ago
• DB: ✅ connected
• Status: ⚠️ Degraded

⏰ Generated: 10/19/2025, 9:29:06 PM
```

### System Alert (Critical)
```
🚨 System Alert: Critical

• 15 errors in last 24h
  - Cleanup: 10
  - API: 5
• Last cleanup: Never
• DB: ❌ disconnected
• Status: 🚨 Critical

⏰ Generated: 10/19/2025, 9:29:06 PM
```

### Weekly Summary
```
🧠 Weekly System Summary

• 8 cleanups
• 0 GB freed
• 0 errors
• 113ms avg execution time

Breakdown:
• Images: 3
• Database: 4
• Logs: 2

Generated: 10/19/2025, 9:22:37 PM
```

## ⏰ Automated Scheduling

### GitHub Actions Workflow
- **File**: `.github/workflows/monitoring-cron.yml`
- **Triggers**: 
  - Scheduled (cron)
  - Manual (workflow_dispatch)

### Schedule
- **Health Check**: Every 15 minutes (`*/15 * * * *`)
- **Log Monitor**: Daily at 2 AM UTC (`0 2 * * *`)
- **Log Alert**: Daily at 3 AM UTC (`0 3 * * *`)

### Manual Execution
```bash
# Trigger all jobs
gh workflow run monitoring-cron.yml

# Trigger specific job
gh workflow run monitoring-cron.yml -f job_type=health-check
gh workflow run monitoring-cron.yml -f job_type=log-monitor
gh workflow run monitoring-cron.yml -f job_type=log-alert
```

## 🔧 Usage

### Manual Function Calls
```bash
# Log Alert
curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-alert \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ"

# Health Check
curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/health-check \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ"

# Log Monitor
curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-monitor \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ"
```

## 🛠️ Configuration

### Required Secrets (GitHub Actions)
- `SUPABASE_ANON_KEY` - Supabase anonymous key
- `CLEANUP_API_KEY` - API key for authentication

### Environment Variables (Functions)
- `CLEANUP_API_KEY` - Required for authentication
- `TELEGRAM_BOT_TOKEN` - Optional, for notifications
- `TELEGRAM_CHAT_ID` - Optional, for notifications

### Alert Thresholds (Configurable)
```typescript
const ALERT_THRESHOLDS = {
  maxErrors24h: 5,           // Adjust based on tolerance
  maxCleanupDelayHours: 24   // Adjust based on cleanup frequency
};
```

## 🧪 Testing

### Test Log Alert
```bash
cd supabase/functions/log-alert
node test-log-alert.js
```

### Test Health Check
```bash
cd supabase/functions/health-check
node test-health-check.js
```

### Test Log Monitor
```bash
cd supabase/functions/log-monitor
node test-log-monitor.js
```

## 📈 Monitoring Dashboard

### Key Metrics
- **Alert Status**: Current system status (healthy/degraded/critical)
- **Error Rate**: Errors in last 24 hours
- **Cleanup Delay**: Hours since last cleanup
- **Database Status**: Connection status
- **Alert History**: Recent alerts sent

### Alert History
```sql
SELECT * FROM cleanup_logs 
WHERE operation = 'log_alert_complete' 
ORDER BY created_at DESC 
LIMIT 10;
```

## 🔧 Troubleshooting

### Common Issues

1. **No Alerts Being Sent**
   - Check Telegram bot token and chat ID
   - Verify alert thresholds are appropriate
   - Check if system is actually healthy

2. **GitHub Actions Failing**
   - Verify secrets are set correctly
   - Check function URLs and authentication
   - Review GitHub Actions logs

3. **False Alerts**
   - Adjust alert thresholds
   - Check for temporary issues
   - Review error patterns

4. **Missing Cleanup Data**
   - Ensure cleanup functions are running
   - Check database connectivity
   - Verify cleanup logs are being created

### Debug Mode
Add `console.log` statements in functions for detailed debugging.

---

## 🎯 **SUMMARY**

✅ **Log Alert System**: Automated alert detection and notification  
✅ **Updated Health Check**: Enhanced with alerting capabilities  
✅ **Updated Log Monitor**: Enhanced with alerting capabilities  
✅ **GitHub Actions Scheduling**: Automated monitoring schedule  
✅ **Telegram Integration**: Rich alert messages and notifications  
✅ **Configurable Thresholds**: Adjustable alert sensitivity  
✅ **Production Ready**: Tested and deployed  

**Status**: ✅ **COMPLETE AND OPERATIONAL**

### **All 7 Functions Deployed**
- ✅ `process-image` - Image processing
- ✅ `cleanup-images` - Image cleanup automation
- ✅ `cleanup-db` - Database cleanup automation
- ✅ `cleanup-logs` - Log rotation automation
- ✅ `health-check` - Real-time health monitoring (v2)
- ✅ `log-monitor` - Weekly statistics reporting (v2)
- ✅ `log-alert` - Automated alerting system (NEW)

**Complete monitoring and alerting infrastructure is now operational!** 🚀
