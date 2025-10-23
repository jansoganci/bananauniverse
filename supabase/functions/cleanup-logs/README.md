# 🧹 Log Rotation System

## Overview

The `cleanup-logs` Edge Function implements automated 90-day log rotation for the `cleanup_logs` table. It safely deletes old log entries in batches to maintain database performance and storage efficiency.

## Features

- **90-day retention policy** - Deletes logs older than 90 days
- **Batch processing** - Processes 500 logs per batch to avoid database locks
- **Safe deletion** - Includes error handling and continues on partial failures
- **Comprehensive logging** - Tracks deletion statistics and execution metrics
- **Telegram notifications** - Sends cleanup summary to configured chat
- **Authentication** - Requires Supabase auth + API key for security

## Usage

### Manual Execution

```bash
curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-logs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY"
```

### Scheduled Execution

Set up external cron job to run daily:

```bash
# Daily at 2 AM UTC
0 2 * * * curl -X POST https://jiorfutbmahpfgplkats.supabase.co/functions/v1/cleanup-logs \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "x-api-key: YOUR_CLEANUP_API_KEY"
```

## Response Format

```json
{
  "logsDeleted": 1500,
  "batchesProcessed": 3,
  "errors": [],
  "executionTime": 1250,
  "oldestDeletedDate": "2024-07-15T10:30:00Z",
  "newestDeletedDate": "2024-07-20T14:45:00Z"
}
```

## Configuration

### Environment Variables

- `CLEANUP_API_KEY` - Required for authentication
- `TELEGRAM_BOT_TOKEN` - Optional, for notifications
- `TELEGRAM_CHAT_ID` - Optional, for notifications

### Database Requirements

- `cleanup_logs` table must exist
- Service role permissions required
- RLS policies configured

## Safety Features

1. **Batch Processing** - Limits to 500 records per batch
2. **Error Isolation** - Individual batch failures don't stop the process
3. **Date Validation** - Only deletes logs older than 90 days
4. **Comprehensive Logging** - All operations logged to `cleanup_logs`
5. **Telegram Integration** - Non-blocking notifications

## Monitoring

### Check Recent Rotations

```sql
SELECT * FROM cleanup_logs 
WHERE operation = 'log_rotation_complete' 
ORDER BY created_at DESC 
LIMIT 10;
```

### View Deletion Statistics

```sql
SELECT 
  details->>'logs_deleted' as logs_deleted,
  details->>'batches_processed' as batches_processed,
  details->>'execution_time_ms' as execution_time_ms,
  created_at
FROM cleanup_logs 
WHERE operation = 'log_rotation_complete'
ORDER BY created_at DESC;
```

## Error Handling

The function includes comprehensive error handling:

- **Authentication errors** - Returns 401 with clear message
- **Database errors** - Logs error and continues with next batch
- **Telegram errors** - Logs warning but doesn't fail the operation
- **Fatal errors** - Returns 500 with error details

## Performance

- **Batch size**: 500 records per batch
- **Delay between batches**: 100ms
- **Typical execution time**: 1-5 seconds for 1000+ logs
- **Memory usage**: Minimal (processes in batches)

## Security

- **Authentication required** - Supabase Bearer token + API key
- **Service role only** - Database operations use service role
- **RLS policies** - Row Level Security enabled
- **Input validation** - Validates all inputs before processing

---

**Status**: ✅ **PRODUCTION READY**  
**Last Updated**: October 20, 2025  
**Version**: 1.0.0
