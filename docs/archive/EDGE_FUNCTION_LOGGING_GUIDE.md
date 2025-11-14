# 📊 Edge Function Logging Guide

**Purpose:** Structured logging for manual testing and debugging

---

## 🎯 Neden Structured Logging?

### Mevcut Durum (console.log)
```typescript
console.log('🚀 [SUBMIT-JOB] Request started');
console.log('✅ [CREDITS] Result:', JSON.stringify(quotaResult));
```
**Sorunlar:**
- ❌ Parse edilmesi zor
- ❌ Request tracking yok
- ❌ Performance timing yok
- ❌ Log level yok

### Yeni Yaklaşım (Structured Logger)
```typescript
logger.info('Request started');
logger.step('Credit consumption', { creditsBefore: 10, creditsAfter: 9 });
logger.summary('success', { jobId: 'abc123', duration: 150 });
```
**Avantajlar:**
- ✅ JSON format (kolay parse)
- ✅ Request ID tracking
- ✅ Performance timing
- ✅ Log levels (DEBUG, INFO, WARN, ERROR)
- ✅ Step tracking (manuel test için ideal)

---

## 🚀 Kullanım

### 1. Logger Oluştur

```typescript
import { createLogger } from '../_shared/logger.ts';

Deno.serve(async (req: Request) => {
  // Request ID'yi body'den veya header'dan al
  const body = await req.json();
  const requestId = body.client_request_id || `req-${Date.now()}`;
  
  // Logger oluştur
  const logger = createLogger('submit-job', requestId, {
    deviceId: body.device_id,
    userId: body.user_id,
  });
  
  logger.info('Request received', { method: req.method });
  // ...
});
```

### 2. Logging Metodları

#### Basic Logging
```typescript
logger.debug('Detailed debug info', { someData: 'value' });
logger.info('General information', { status: 'processing' });
logger.warn('Warning message', { issue: 'minor problem' });
logger.error('Error occurred', error);
```

#### Step Tracking (Manuel Test İçin)
```typescript
logger.step('1. Parse request', { hasImage: !!image_url });
logger.step('2. Authenticate user', { userType, isPremium });
logger.step('3. Consume credits', { creditsBefore: 10, creditsAfter: 9 });
logger.step('4. Submit to fal.ai', { falJobId });
logger.step('5. Insert job result', { jobId });
```

#### Performance Tracking
```typescript
logger.time('Credit consumption'); // Logs elapsed time
logger.time('Fal.ai submission');
```

#### Request Summary
```typescript
// Function sonunda
logger.summary('success', {
  jobId: falJobId,
  creditsRemaining: quotaResult.credits_remaining,
});
```

---

## 📋 Log Format

### JSON Output
```json
{
  "timestamp": "2025-01-27T10:30:45.123Z",
  "level": "INFO",
  "function": "submit-job",
  "message": "[STEP] Credit consumption",
  "requestId": "req-1706352645123-abc123",
  "deviceId": "device-123",
  "duration": 45,
  "data": {
    "creditsBefore": 10,
    "creditsAfter": 9
  }
}
```

### Supabase Dashboard'da Görünüm
```
2025-01-27 10:30:45 [INFO] submit-job: [STEP] Credit consumption
  requestId: req-1706352645123-abc123
  deviceId: device-123
  duration: 45ms
  data: { creditsBefore: 10, creditsAfter: 9 }
```

---

## 🔍 Manuel Test Senaryoları

### Senaryo 1: Normal Flow Tracking

```typescript
const logger = createLogger('submit-job', requestId);

logger.step('1. Request received');
logger.step('2. Parsing request body', { hasImage: !!image_url });
logger.step('3. Authenticating user', { userType, isPremium });
logger.step('4. Consuming credits', { 
  creditsBefore: currentBalance,
  creditsAfter: quotaResult.credits_remaining 
});
logger.step('5. Submitting to fal.ai', { falJobId });
logger.step('6. Inserting job result', { jobId });
logger.summary('success', { jobId, creditsRemaining });
```

**Çıktı:**
```
[STEP] 1. Request received
[STEP] 2. Parsing request body { hasImage: true }
[STEP] 3. Authenticating user { userType: 'anonymous', isPremium: false }
[STEP] 4. Consuming credits { creditsBefore: 10, creditsAfter: 9 }
[STEP] 5. Submitting to fal.ai { falJobId: 'fal-123' }
[STEP] 6. Inserting job result { jobId: 'job-456' }
[SUMMARY] Request success { jobId: 'job-456', creditsRemaining: 9, totalDuration: 234 }
```

### Senaryo 2: Error Tracking

```typescript
try {
  logger.step('Consuming credits');
  const result = await consumeCredits(...);
  logger.step('Credits consumed', { result });
} catch (error) {
  logger.error('Credit consumption failed', error);
  logger.summary('error', { error: error.message });
  throw error;
}
```

### Senaryo 3: Performance Analysis

```typescript
logger.time('Total request');
logger.time('Credit check');
// ... credit check code ...
logger.time('Fal.ai submission');
// ... fal.ai code ...
logger.time('Database insert');
// ... database code ...
logger.summary('success', { 
  creditCheckDuration: 45,
  falSubmissionDuration: 120,
  dbInsertDuration: 30
});
```

---

## 🛠️ Implementation Plan

### Adım 1: Logger'ı Tüm Function'lara Ekle

**Priority Order:**
1. ✅ `submit-job` (en kritik)
2. ✅ `webhook-handler` (credit refund tracking)
3. ✅ `verify-iap-purchase` (IAP flow tracking)
4. ✅ `iap-webhook` (refund tracking)
5. Diğerleri (opsiyonel)

### Adım 2: Mevcut console.log'ları Değiştir

**Önce:**
```typescript
console.log('🚀 [SUBMIT-JOB] Request started');
console.log('✅ [CREDITS] Result:', JSON.stringify(quotaResult));
```

**Sonra:**
```typescript
logger.info('Request started');
logger.step('Credit consumption', quotaResult);
```

### Adım 3: Test ve Doğrulama

1. Function'ı deploy et
2. Test request gönder
3. Supabase Dashboard → Edge Functions → Logs
4. Logları kontrol et

---

## 📊 Log Analysis

### Supabase Dashboard'da Görüntüleme

1. **Supabase Dashboard** → **Edge Functions** → **submit-job** → **Logs**
2. Logları filtrele:
   - Request ID ile
   - Timestamp ile
   - Level ile (ERROR, WARN, etc.)

### Command Line'da Parse

```bash
# Tüm logları çek
supabase functions logs submit-job --limit 100

# JSON formatında parse et
supabase functions logs submit-job | jq 'select(.level == "ERROR")'

# Request ID ile filtrele
supabase functions logs submit-job | jq 'select(.requestId == "req-123")'

# Step tracking'i göster
supabase functions logs submit-job | jq 'select(.message | startswith("[STEP]"))'
```

### Log Aggregation (İsteğe Bağlı)

```bash
# Tüm step'leri göster
supabase functions logs submit-job | \
  jq -r 'select(.message | startswith("[STEP]")) | "\(.timestamp) \(.message) \(.data)"'

# Performance analizi
supabase functions logs submit-job | \
  jq 'select(.duration) | {step: .message, duration: .duration}'
```

---

## ✅ Avantajlar

### Manuel Test İçin
- ✅ Her adımı takip edebilirsin
- ✅ Request ID ile tüm flow'u izleyebilirsin
- ✅ Performance bottleneck'leri görebilirsin
- ✅ Error'ları kolayca bulabilirsin

### Production İçin
- ✅ Structured format (monitoring tools ile entegre)
- ✅ Log levels (sadece önemli logları göster)
- ✅ Request tracking (debug için)
- ✅ Performance metrics (optimization için)

---

## 🎯 Sonuç

**Senin yöntemin (console.log):**
- ✅ Basit ve çalışır
- ❌ Parse edilmesi zor
- ❌ Request tracking yok
- ❌ Performance timing yok

**Structured Logger:**
- ✅ Parse edilmesi kolay (JSON)
- ✅ Request tracking (requestId)
- ✅ Performance timing (duration)
- ✅ Step tracking (manuel test için ideal)
- ✅ Log levels (sadece önemli logları göster)

**Öneri:** Structured logger kullan, ama basit tut. Sadece kritik adımları logla.

---

**Hazır mısın?** `submit-job`'a logger ekleyeyim mi?


