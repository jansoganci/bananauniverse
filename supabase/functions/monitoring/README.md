# 🏥 Monitoring & Health Check System

## Overview

The monitoring system provides comprehensive health checks and weekly reporting for the cleanup infrastructure. It includes two Edge Functions and supporting SQL views for system analytics.

## 🚀 Deployed Functions

### 1. Health Check (`health-check`)
- **URL**: `https://jiorfutbmahpfgplkats.supabase.co/functions/v1/health-check`
- **Purpose**: Real-time system health monitoring
- **Frequency**: On-demand or scheduled (recommended: every 15 minutes)

### 2. Log Monitor (`log-monitor`)
- **URL**: `https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-monitor`
- **Purpose**: Weekly system statistics and reporting
- **Frequency**: Weekly (recommended: every Sunday at 2 AM UTC)

## 📊 Health Check Response

```json
{
  "status": "healthy",
  "database": "connected",
  "last_cleanup": "2025-10-19T21:10:22.192095+00:00",
  "errors_24h": 0,
  "timestamp": "2025-10-19T21:22:37.566Z",
  "details": {
    "cleanup_images_last_run": "2025-10-19T21:10:22.192095+00:00",
    "cleanup_db_last_run": "2025-10-19T21:10:22.192095+00:00",
    "cleanup_logs_last_run": "2025-10-19T21:10:22.192095+00:00",
    "recent_errors": []
  }
}
```

### Health Status Levels
- **🟢 healthy**: No errors, all systems operational
- **🟡 degraded**: Some errors detected (1-10 in 24h)
- **🔴 unhealthy**: Critical issues (>10 errors in 24h or database disconnected)

## 📈 Log Monitor Response

```json
{
  "weekly_cleanups": 8,
  "avg_exec_time": 113,
  "storage_freed_gb": 0,
  "errors": 0,
  "executionTime": 632,
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

## 🔧 Usage

### Manual Health Check

```bash
curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/health-check \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ"
```

### Manual Log Monitor

```bash
curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-monitor \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ"
```

### Scheduled Execution

#### Health Check (Every 15 minutes)
```bash
# Add to crontab or GitHub Actions
*/15 * * * * curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/health-check \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ"
```

#### Log Monitor (Weekly)
```bash
# Add to crontab or GitHub Actions
0 2 * * 0 curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/log-monitor \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ"
```

## 🗄️ Database Views & Functions

### SQL Views (Migration: 009_create_monitoring_views.sql)

#### `system_health_view`
Real-time system health metrics:
```sql
SELECT * FROM system_health_view;
```

#### `cleanup_stats_weekly`
Weekly cleanup statistics:
```sql
SELECT * FROM cleanup_stats_weekly ORDER BY week_start DESC LIMIT 4;
```

### SQL Functions

#### `get_system_health()`
Comprehensive health summary:
```sql
SELECT get_system_health();
```

#### `get_cleanup_stats_weekly(weeks_back)`
Weekly statistics for specified weeks:
```sql
SELECT get_cleanup_stats_weekly(1); -- Last week
SELECT get_cleanup_stats_weekly(4); -- Last 4 weeks
```

## 🔔 Telegram Notifications

### Health Check Alerts
- **Triggered**: When system status is `degraded` or `unhealthy`
- **Message Format**:
  ```
  🚨 System Health Alert
  
  Status: DEGRADED
  Database: connected
  Last Cleanup: 2025-10-19T21:10:22Z
  Errors (24h): 5
  Timestamp: 2025-10-19T21:22:37Z
  ```

### Weekly Summary
- **Triggered**: Every log monitor execution
- **Message Format**:
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

## 🔐 Authentication

Both functions require:
1. **Supabase Authorization**: `Bearer <JWT_TOKEN>`
2. **API Key**: `x-api-key: A8f9s@2p!B7mZQ??!Ap!B7mZQ`

## 📊 Monitoring Dashboard

### Key Metrics to Track
- **System Health**: Overall status (healthy/degraded/unhealthy)
- **Database Connectivity**: Connection status
- **Cleanup Frequency**: Last cleanup run time
- **Error Rate**: Errors in last 24 hours
- **Performance**: Average execution times
- **Storage**: Total storage freed

### Alert Thresholds
- **Critical**: Database disconnected or >10 errors in 24h
- **Warning**: 1-10 errors in 24h or no cleanup in 48h
- **Info**: Weekly summary reports

## 🛠️ Configuration

### Environment Variables
- `CLEANUP_API_KEY` - Required for authentication
- `TELEGRAM_BOT_TOKEN` - Optional, for notifications
- `TELEGRAM_CHAT_ID` - Optional, for notifications

### Database Requirements
- `cleanup_logs` table must exist
- Service role permissions required
- RLS policies configured

## 🧪 Testing

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

## 📈 Performance

- **Health Check**: ~200-500ms typical response time
- **Log Monitor**: ~500-1000ms typical response time
- **Database Queries**: Optimized with proper indexes
- **Memory Usage**: Minimal (processes data in batches)

## 🔧 Troubleshooting

### Common Issues

1. **401 Unauthorized**
   - Check API key is correct
   - Verify Supabase token is valid

2. **Database Connection Failed**
   - Check Supabase service is running
   - Verify database credentials

3. **Telegram Notifications Not Working**
   - Check bot token and chat ID
   - Verify bot has permission to send messages

4. **No Cleanup Data**
   - Run cleanup functions first
   - Check if logs are being created

### Debug Mode
Add `console.log` statements in functions for detailed debugging.

---

## 🎯 **SUMMARY**

✅ **Health Check System**: Real-time monitoring with status levels  
✅ **Log Monitor System**: Weekly statistics and reporting  
✅ **Database Views**: Analytics and health tracking  
✅ **Telegram Integration**: Alerts and weekly summaries  
✅ **Authentication**: Secure API key + Supabase auth  
✅ **Production Ready**: Tested and deployed  

**Status**: ✅ **COMPLETE AND OPERATIONAL**
