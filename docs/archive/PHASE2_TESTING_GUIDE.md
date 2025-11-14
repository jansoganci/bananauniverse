# Phase 2 Testing Guide

## ✅ Phase 2 Complete Summary

You now have:
- ✅ `ThemeService.swift` - API communication layer
- ✅ `Theme.swift` - Database-driven model with Codable support
- ✅ `Tool.swift` - Marked as legacy with migration notes
- ✅ JSONB decoding helper (AnyCodable)
- ✅ 5-minute caching to reduce API calls
- ✅ Proper error handling with AppError

---

## 🧪 Testing the API

### Test 1: Manual API Test (Supabase Dashboard)

1. **Go to Supabase Dashboard → SQL Editor**
2. **Run this query:**
   ```sql
   SELECT
       id,
       name,
       category,
       is_featured,
       is_available,
       model_name
   FROM themes
   WHERE is_available = true
   ORDER BY is_featured DESC, name ASC;
   ```

3. **Expected Results:**
   - 28 total themes
   - 5 featured themes at the top
   - All with `is_available = true`

---

### Test 2: REST API Test (curl)

**Local Supabase:**
```bash
curl -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "apikey: YOUR_ANON_KEY" \
     "http://127.0.0.1:54321/rest/v1/themes?is_available=eq.true&select=id,name,category,is_featured"
```

**Production Supabase:**
```bash
curl -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "apikey: YOUR_ANON_KEY" \
     "https://YOUR_PROJECT.supabase.co/rest/v1/themes?is_available=eq.true&select=id,name,category,is_featured"
```

**Expected Response:**
```json
[
  {
    "id": "uuid",
    "name": "Remove Object from Image",
    "category": "main_tools",
    "is_featured": true
  },
  ...
]
```

---

### Test 3: iOS App Test (Next Phase)

In Phase 3, we'll test:
1. HomeView loads themes from API
2. Featured carousel shows 5 themes
3. Categories show correct tools
4. Search works with dynamic data

---

## 🔍 Verification Checklist

### Files Created ✅
- [x] `ThemeService.swift` - Service layer
- [x] `Theme.swift` - New model
- [x] Updated `Tool.swift` - Legacy notice
- [x] Test scripts created

### Code Features ✅
- [x] Codable support for JSON decoding
- [x] Snake_case to camelCase mapping
- [x] JSONB field decoding
- [x] Date parsing (ISO8601)
- [x] URL parsing for thumbnails
- [x] Error handling with AppError
- [x] 5-minute caching
- [x] Mock service for testing

### API Query Features ✅
- [x] Filter by `is_available = true`
- [x] Select all needed fields
- [x] Sort by featured then name
- [x] Proper Supabase headers

---

## 📝 Code Review

### ThemeService.swift Key Points

```swift
// ✅ Caching reduces API calls
private var cachedThemes: [Theme]?
private let cacheValidity: TimeInterval = 300  // 5 minutes

// ✅ Proper Supabase headers
request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
request.setValue(anonKey, forHTTPHeaderField: "apikey")

// ✅ Query filters available themes
"is_available=eq.true"

// ✅ Sorts featured first
"order=is_featured.desc,name.asc"

// ✅ Error handling maps to AppError
switch httpResponse.statusCode {
    case 401, 403: throw AppError.authenticationFailed
    case 500...599: throw AppError.serverUnavailable
}
```

### Theme.swift Key Points

```swift
// ✅ Snake_case mapping
enum CodingKeys: String, CodingKey {
    case thumbnailURL = "thumbnail_url"
    case modelName = "model_name"
    case isFeatured = "is_featured"
}

// ✅ Optional URL handling
if let urlString = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) {
    thumbnailURL = URL(string: urlString)
}

// ✅ JSONB decoding
if let settingsData = try container.decodeIfPresent([String: AnyCodable].self) {
    defaultSettings = settingsData.mapValues { $0.value }
}

// ✅ Backward compatibility
typealias Tool = Theme
```

---

## 🎯 What Works Now

### 1. Theme Model
```swift
// Create a theme
let theme = Theme(
    name: "Remove Object",
    category: "main_tools",
    modelName: "lama-cleaner",
    placeholderIcon: "eraser.fill",
    prompt: "Remove object naturally",
    isFeatured: true
)

// Access properties
print(theme.name)           // "Remove Object"
print(theme.isFeatured)     // true
print(theme.category)       // "main_tools"
```

### 2. Theme Service
```swift
// Fetch themes
let service = ThemeService.shared
let themes = try await service.fetchThemes()

// Filter featured
let featured = themes.filter { $0.isFeatured }

// Filter by category
let mainTools = themes.filter { $0.category == "main_tools" }
```

### 3. Backward Compatibility
```swift
// Old code still works!
let tool: Tool = themes[0]  // Tool is now Theme
print(tool.name)            // Works!
```

---

## 🚨 Common Issues & Solutions

### Issue 1: "Cannot connect to Supabase"
**Solution:**
- Check `Config.swift` has correct `SUPABASE_URL` and `SUPABASE_ANON_KEY`
- Verify Supabase project is active
- Check internet connection

### Issue 2: "Failed to decode themes"
**Solution:**
- Run verification SQL: `SELECT * FROM themes LIMIT 1;`
- Check all required fields exist
- Verify date format is ISO8601

### Issue 3: "Empty themes array"
**Solution:**
- Check RLS policy: `SELECT * FROM pg_policies WHERE tablename = 'themes';`
- Verify themes exist: `SELECT COUNT(*) FROM themes WHERE is_available = true;`
- Check `is_available` flag is true

### Issue 4: "HTTP 401 Unauthorized"
**Solution:**
- Verify anon key is correct
- Check RLS policy allows SELECT
- Ensure `is_available = true` in policy

---

## 📊 Expected API Response

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Remove Object from Image",
    "description": "Remove unwanted objects",
    "thumbnail_url": null,
    "category": "main_tools",
    "model_name": "lama-cleaner",
    "placeholder_icon": "eraser.fill",
    "prompt": "Remove the selected object naturally...",
    "is_featured": true,
    "is_available": true,
    "requires_pro": false,
    "default_settings": {},
    "created_at": "2025-11-14T10:00:00.000Z"
  },
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "name": "Remove Background",
    "description": "Remove image backgrounds",
    "thumbnail_url": null,
    "category": "main_tools",
    "model_name": "rembg",
    "placeholder_icon": "scissors",
    "prompt": "Remove the background cleanly...",
    "is_featured": true,
    "is_available": true,
    "requires_pro": false,
    "default_settings": {},
    "created_at": "2025-11-14T10:01:00.000Z"
  }
]
```

---

## 🔄 Next Steps: Phase 3

Ready for Phase 3? It will include:
1. Create `HomeViewModel.swift`
2. Update `HomeView.swift` to use ViewModel
3. Test featured carousel with dynamic data
4. Test category filtering
5. Test search with dynamic data
6. Remove static Tool arrays

**Estimated Time:** 45 minutes

---

## 💡 Testing Tips

1. **Start Supabase locally:**
   ```bash
   supabase start
   ```

2. **Check database has themes:**
   ```sql
   SELECT COUNT(*) FROM themes;  -- Should be 28
   ```

3. **Test RLS policy:**
   ```sql
   SET ROLE anon;
   SELECT COUNT(*) FROM themes WHERE is_available = true;
   RESET ROLE;
   ```

4. **View logs in Supabase:**
   - Dashboard → Logs → Filter by "themes"

5. **Test caching:**
   - First call: Takes ~100-300ms
   - Subsequent calls (within 5 min): ~1-5ms

---

## 📚 Architecture Review

```
┌─────────────────────────────────────────┐
│           iOS App (SwiftUI)             │
│                                         │
│  ┌────────────────────────────────┐    │
│  │         HomeView               │    │
│  │  (Will use ViewModel in Phase 3)    │
│  └────────────────────────────────┘    │
│                  │                      │
│                  ▼                      │
│  ┌────────────────────────────────┐    │
│  │       ThemeService ✅          │    │
│  │  - fetchThemes()               │    │
│  │  - 5-min caching               │    │
│  └────────────────────────────────┘    │
│                  │                      │
└──────────────────┼──────────────────────┘
                   │ HTTP GET
                   ▼
┌─────────────────────────────────────────┐
│          Supabase REST API              │
│  GET /rest/v1/themes?                   │
│      is_available=eq.true               │
└──────────────────┬──────────────────────┘
                   │ SQL Query
                   ▼
┌─────────────────────────────────────────┐
│        PostgreSQL Database              │
│  ┌───────────────────────────────┐     │
│  │       themes table ✅         │     │
│  │  - 28 tools seeded            │     │
│  │  - RLS enabled                │     │
│  │  - Indexes created            │     │
│  └───────────────────────────────┘     │
└─────────────────────────────────────────┘
```

**Status:**
- ✅ Database Layer (Phase 1)
- ✅ Service Layer (Phase 2)
- ⏳ ViewModel Layer (Phase 3)
- ⏳ View Layer (Phase 3)

---

**Phase 2 Complete!** 🎉

Ready to move to Phase 3 (ViewModel + View updates)?
