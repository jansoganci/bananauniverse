# 🎯 Remote Content Management System
## Complete Implementation Guide

**Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Purpose:** Comprehensive guide for implementing a database-driven remote content management system that allows dynamic content updates without app store releases.

---

## 📋 Table of Contents

1. [Overview & Concept](#overview--concept)
2. [System Architecture](#system-architecture)
3. [Database Layer](#database-layer)
4. [Security Layer (RLS)](#security-layer-rls)
5. [Backend/API Layer](#backendapi-layer)
6. [Frontend Layer](#frontend-layer)
7. [Remote Control Scenarios](#remote-control-scenarios)
8. [Workflow Diagrams](#workflow-diagrams)
9. [Code Examples](#code-examples)
10. [Best Practices](#best-practices)
11. [Troubleshooting](#troubleshooting)
12. [Future Enhancements](#future-enhancements)

---

## 🎯 Overview & Concept

### What is This System?

A **Remote Content Management System** allows you to:
- ✅ Update app content without releasing new app versions
- ✅ Control visibility of content items dynamically
- ✅ Feature/promote specific items remotely
- ✅ A/B test different content configurations
- ✅ Quickly disable problematic content
- ✅ Run seasonal campaigns without code changes

### Core Principle

**Content is stored in a database, not hardcoded in the app.** The app fetches content dynamically on each load, allowing instant updates from the backend.

### Key Benefits

1. **No App Store Updates Required** - Change content instantly
2. **A/B Testing** - Test different content configurations
3. **Seasonal Campaigns** - Promote holiday/seasonal content easily
4. **Quick Fixes** - Disable problematic content immediately
5. **Dynamic Content** - Add new content without app updates
6. **Centralized Management** - Control all content from one place

---

## 🏗️ System Architecture

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    FRONTEND LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  HomeView   │  │  ViewModel   │  │  Service     │   │
│  │  (UI)       │→ │  (State)     │→ │  (API Call)  │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          │ HTTP/REST API
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    BACKEND LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │  Supabase   │  │  RLS Policy  │  │  REST API    │   │
│  │  Database   │  │  (Security)  │  │  (Query)     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
                          │
                          │ SQL Query
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    DATABASE LAYER                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              themes table                         │   │
│  │  • id (UUID)                                     │   │
│  │  • name, description, thumbnail_url              │   │
│  │  • prompt (content generation template)         │   │
│  │  • is_featured (BOOLEAN)                        │   │
│  │  • is_available (BOOLEAN)                       │   │
│  │  • default_settings (JSONB)                     │   │
│  │  • created_at (TIMESTAMPTZ)                     │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
1. User opens app
   ↓
2. HomeView appears → calls ViewModel.loadData()
   ↓
3. ViewModel calls ThemeService.fetchThemes()
   ↓
4. Service makes HTTP GET request to Supabase REST API
   ↓
5. RLS Policy checks: is_available = true?
   ↓
6. Database returns filtered results
   ↓
7. Service decodes JSON → [Theme] array
   ↓
8. ViewModel updates state:
   - allThemes = all available themes
   - featuredThemes = themes where is_featured = true
   ↓
9. HomeView renders:
   - Featured themes in carousel
   - All themes in grid
```

---

## 💾 Database Layer

### Table Schema

```sql
CREATE TABLE IF NOT EXISTS themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    prompt TEXT NOT NULL,
    is_featured BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    default_settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);
```

### Field Descriptions

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| `id` | UUID | Unique identifier | Auto-generated |
| `name` | TEXT | Display name | Required |
| `description` | TEXT | Short description | Optional |
| `thumbnail_url` | TEXT | Image URL | Optional |
| `prompt` | TEXT | Content generation template | Required |
| `is_featured` | BOOLEAN | Show in featured section | `false` |
| `is_available` | BOOLEAN | Visible to users | `true` |
| `default_settings` | JSONB | Default configuration | `{}` |
| `created_at` | TIMESTAMPTZ | Creation timestamp | Auto |

### Key Flags

#### `is_available`
- **Purpose:** Master visibility control
- **Behavior:**
  - `true` → Theme appears in app
  - `false` → Theme hidden from all users
- **Use Cases:**
  - Disable problematic content
  - Remove outdated content
  - Temporarily hide content for maintenance

#### `is_featured`
- **Purpose:** Promotion/priority control
- **Behavior:**
  - `true` → Theme appears in featured carousel
  - `false` → Theme appears only in grid
- **Use Cases:**
  - Promote seasonal content
  - Highlight new releases
  - A/B test different featured items

### Indexes

```sql
-- Partial index for featured themes (optimizes carousel queries)
CREATE INDEX IF NOT EXISTS idx_themes_featured 
ON themes(is_featured) 
WHERE is_featured = true;

-- Partial index for available themes (optimizes main queries)
CREATE INDEX IF NOT EXISTS idx_themes_available 
ON themes(is_available) 
WHERE is_available = true;
```

**Why Partial Indexes?**
- Only index rows that match the condition
- Smaller index size = faster queries
- Better performance for filtered queries

### Migration File

```sql
-- Migration: Create themes table
-- Version: 1.0
-- Date: 2025-11-06
-- Purpose: Create themes table for user-facing content/vibes

CREATE TABLE IF NOT EXISTS themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    prompt TEXT NOT NULL,
    is_featured BOOLEAN DEFAULT false,
    is_available BOOLEAN DEFAULT true,
    default_settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_themes_featured 
ON themes(is_featured) 
WHERE is_featured = true;

CREATE INDEX IF NOT EXISTS idx_themes_available 
ON themes(is_available) 
WHERE is_available = true;

-- Enable RLS
ALTER TABLE themes ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Anyone can view available themes
CREATE POLICY "Anyone can view available themes"
ON themes FOR SELECT
USING (is_available = true);
```

---

## 🔒 Security Layer (RLS)

### Row Level Security (RLS)

**RLS** ensures users can only see content they're allowed to see, even if they try to query the database directly.

### RLS Policy

```sql
-- Policy: Anyone can view available themes
CREATE POLICY "Anyone can view available themes"
ON themes FOR SELECT
USING (is_available = true);
```

### How It Works

1. **User makes request** → Supabase checks RLS policy
2. **Policy evaluates** → `is_available = true` condition
3. **If true** → Query proceeds, returns theme
4. **If false** → Query returns empty (theme hidden)
5. **No INSERT/UPDATE/DELETE policies** → Only backend can modify

### Security Model

```
┌─────────────────────────────────────────┐
│         User Request                    │
│  GET /rest/v1/themes                   │
└─────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      RLS Policy Check                   │
│  USING (is_available = true)            │
└─────────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌──────────────┐   ┌──────────────┐
│   PASS       │   │   BLOCK      │
│ Returns data │   │ Returns []   │
└──────────────┘   └──────────────┘
```

### Admin Access

**Only backend (service_role key) can modify themes:**
- No INSERT/UPDATE/DELETE policies for users
- Admin must use service_role key or Supabase Dashboard
- Prevents unauthorized content manipulation

---

## 🔌 Backend/API Layer

### REST API Endpoint

**Base URL:** `{SUPABASE_URL}/rest/v1/themes`

### Query Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `is_available` | `eq.true` | Filter only available themes |
| `select` | Field list | Specify which fields to return |
| `order` | `is_featured.desc,name.asc` | Sort order |

### Example Request

```http
GET /rest/v1/themes?is_available=eq.true&select=id,name,description,thumbnail_url,prompt,is_featured,is_available,default_settings,created_at&order=is_featured.desc,name.asc

Headers:
  Authorization: Bearer {ANON_KEY}
  apikey: {ANON_KEY}
  Content-Type: application/json
  Accept: application/json
  Prefer: return=representation
```

### Response Format

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Christmas Magic",
    "description": "Create festive holiday videos",
    "thumbnail_url": "https://example.com/thumb.jpg",
    "prompt": "A cozy Christmas scene with decorations",
    "is_featured": true,
    "is_available": true,
    "default_settings": {
      "duration": 8,
      "aspect_ratio": "16:9"
    },
    "created_at": "2025-11-06T10:00:00.000Z"
  },
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "name": "Summer Beach",
    "description": "Relaxing beach vibes",
    "thumbnail_url": null,
    "prompt": "A beautiful beach at sunset",
    "is_featured": false,
    "is_available": true,
    "default_settings": {
      "duration": 4,
      "aspect_ratio": "16:9"
    },
    "created_at": "2025-11-06T11:00:00.000Z"
  }
]
```

### Error Handling

| Status Code | Meaning | Action |
|-------------|---------|--------|
| `200` | Success | Parse and display themes |
| `400` | Bad Request | Check query parameters |
| `401` | Unauthorized | Check API key |
| `500` | Server Error | Retry or show error message |

---

## 📱 Frontend Layer

### Architecture Components

```
HomeView (UI)
    ↓
HomeViewModel (State Management)
    ↓
ThemeService (API Communication)
    ↓
Supabase REST API
```

### 1. Service Layer (API Communication)

**File:** `ThemeService.swift`

```swift
protocol ThemeServiceProtocol {
    func fetchThemes() async throws -> [Theme]
    func fetchThemeDetail(id: String) async throws -> Theme
}

class ThemeService: ThemeServiceProtocol {
    static let shared = ThemeService()
    
    private var baseURL: String { AppConfig.supabaseURL }
    private var anonKey: String { AppConfig.supabaseAnonKey }
    private let session: URLSession
    
    func fetchThemes() async throws -> [Theme] {
        // Build query URL with filters
        guard let url = URL(string: 
            "\(baseURL)/rest/v1/themes?" +
            "is_available=eq.true&" +
            "select=id,name,description,thumbnail_url,prompt,is_featured,is_available,default_settings,created_at&" +
            "order=is_featured.desc,name.asc"
        ) else {
            throw AppError.invalidResponse
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Execute request
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppError.networkFailure
        }
        
        // Decode JSON
        let decoder = JSONDecoder()
        let themes = try decoder.decode([Theme].self, from: data)
        return themes
    }
}
```

### 2. ViewModel Layer (State Management)

**File:** `HomeViewModel.swift`

```swift
@MainActor
class HomeViewModel: ObservableObject {
    @Published var featuredThemes: [Theme] = []
    @Published var allThemes: [Theme] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let themeService: ThemeServiceProtocol
    
    init(themeService: ThemeServiceProtocol = ThemeService.shared) {
        self.themeService = themeService
    }
    
    func loadData() {
        Task {
            isLoading = true
            do {
                // Fetch themes from API
                let fetchedThemes = try await themeService.fetchThemes()
                
                // Update state
                allThemes = fetchedThemes
                featuredThemes = fetchedThemes.filter { $0.isFeatured }
                
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }
    
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            errorMessage = appError.errorDescription
        } else {
            errorMessage = "error.general.unexpected"
        }
    }
}
```

### 3. Model Layer (Data Structure)

**File:** `Theme.swift`

```swift
struct Theme: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let thumbnailURL: URL?
    let prompt: String
    let isFeatured: Bool
    let isAvailable: Bool
    let defaultSettings: [String: Any]?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case thumbnailURL = "thumbnail_url"
        case prompt
        case isFeatured = "is_featured"
        case isAvailable = "is_available"
        case defaultSettings = "default_settings"
        case createdAt = "created_at"
    }
    
    // Custom decoding for snake_case → camelCase
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // Decode thumbnail_url as URL
        if let urlString = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) {
            thumbnailURL = URL(string: urlString)
        } else {
            thumbnailURL = nil
        }
        
        prompt = try container.decode(String.self, forKey: .prompt)
        isFeatured = try container.decode(Bool.self, forKey: .isFeatured)
        isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
        
        // Decode default_settings as JSONB
        if let settingsData = try container.decodeIfPresent([String: AnyCodable].self, forKey: .defaultSettings) {
            defaultSettings = settingsData.mapValues { $0.value }
        } else {
            defaultSettings = nil
        }
        
        // Decode created_at with ISO8601 format
        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        createdAt = formatter.date(from: dateString) ?? Date()
    }
}
```

### 4. View Layer (UI)

**File:** `HomeView.swift`

```swift
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedThemeId: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Featured Themes Carousel
                if !viewModel.featuredThemes.isEmpty {
                    featuredThemesSection
                }
                
                // All Themes Grid
                allThemesSection
            }
        }
        .onAppear {
            viewModel.loadData()
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedThemeId != nil },
            set: { if !$0 { selectedThemeId = nil } }
        )) {
            if let themeId = selectedThemeId {
                ThemeDetailView(themeId: themeId)
            }
        }
    }
    
    // Featured Themes Carousel
    private var featuredThemesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Featured Themes")
                .font(.title2)
                .fontWeight(.semibold)
            
            TabView {
                ForEach(viewModel.featuredThemes) { theme in
                    FeaturedThemeCard(theme: theme) {
                        selectedThemeId = theme.id
                    }
                }
            }
            .frame(height: 200)
        }
    }
    
    // All Themes Grid
    private var allThemesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Themes")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.allThemes) { theme in
                    ThemeGridCard(theme: theme) {
                        selectedThemeId = theme.id
                    }
                }
            }
        }
    }
}
```

---

## 🎮 Remote Control Scenarios

### Scenario 1: Add New Content

**Goal:** Add a new theme that appears immediately in the app.

**Steps:**
1. Open Supabase Dashboard → Table Editor → `themes`
2. Click "Insert" → "Insert row"
3. Fill in fields:
   ```sql
   name: "New Year Celebration"
   description: "Ring in the new year with style"
   prompt: "A festive New Year celebration with fireworks and confetti"
   is_featured: true
   is_available: true
   default_settings: {"duration": 8, "aspect_ratio": "16:9"}
   ```
4. Click "Save"

**Result:** Theme appears in app on next load (no app update needed)

### Scenario 2: Hide Content

**Goal:** Temporarily hide a theme from all users.

**Steps:**
```sql
UPDATE themes 
SET is_available = false 
WHERE id = '550e8400-e29b-41d4-a716-446655440000';
```

**Result:** Theme disappears from app immediately

### Scenario 3: Feature/Unfeature Content

**Goal:** Promote a theme to featured carousel.

**Steps:**
```sql
-- Feature a theme
UPDATE themes 
SET is_featured = true 
WHERE id = '550e8400-e29b-41d4-a716-446655440000';

-- Unfeature a theme
UPDATE themes 
SET is_featured = false 
WHERE id = '550e8400-e29b-41d4-a716-446655440001';
```

**Result:** Theme moves to/from featured carousel

### Scenario 4: Update Content

**Goal:** Change prompt or settings without app update.

**Steps:**
```sql
UPDATE themes 
SET 
    prompt = 'Updated prompt text',
    default_settings = '{"duration": 12, "aspect_ratio": "9:16"}'::jsonb
WHERE id = '550e8400-e29b-41d4-a716-446655440000';
```

**Result:** Changes apply on next app load

### Scenario 5: Seasonal Campaign

**Goal:** Promote Christmas themes during December.

**Steps:**
```sql
-- Feature all Christmas-related themes
UPDATE themes 
SET is_featured = true 
WHERE name ILIKE '%christmas%' OR name ILIKE '%holiday%';

-- After season, unfeature them
UPDATE themes 
SET is_featured = false 
WHERE name ILIKE '%christmas%' OR name ILIKE '%holiday%';
```

**Result:** Seasonal content automatically promoted/demoted

### Scenario 6: A/B Testing

**Goal:** Test which themes perform better when featured.

**Steps:**
1. Feature Theme A for 1 week
2. Track analytics (views, clicks)
3. Feature Theme B for 1 week
4. Compare results
5. Keep better performer featured

**SQL:**
```sql
-- Week 1: Feature Theme A
UPDATE themes SET is_featured = true WHERE id = 'theme-a-id';
UPDATE themes SET is_featured = false WHERE id = 'theme-b-id';

-- Week 2: Feature Theme B
UPDATE themes SET is_featured = false WHERE id = 'theme-a-id';
UPDATE themes SET is_featured = true WHERE id = 'theme-b-id';
```

---

## 📊 Workflow Diagrams

### Complete Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    USER OPENS APP                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              HomeView.onAppear()                             │
│              → viewModel.loadData()                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         HomeViewModel.loadData()                             │
│         → themeService.fetchThemes()                        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         ThemeService.fetchThemes()                           │
│         → HTTP GET /rest/v1/themes?is_available=eq.true     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              SUPABASE REST API                               │
│              → RLS Policy Check                             │
│              → SQL Query Execution                           │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              DATABASE (themes table)                         │
│              → Filter: is_available = true                    │
│              → Sort: is_featured DESC, name ASC              │
│              → Return: JSON array                            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         ThemeService.fetchThemes()                           │
│         → Decode JSON → [Theme]                              │
│         → Return themes array                                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         HomeViewModel.loadData()                              │
│         → allThemes = fetchedThemes                         │
│         → featuredThemes = fetchedThemes.filter(isFeatured)│
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              HomeView Renders                                │
│              → Featured carousel (featuredThemes)            │
│              → All themes grid (allThemes)                   │
└─────────────────────────────────────────────────────────────┘
```

### Remote Update Flow

```
┌─────────────────────────────────────────────────────────────┐
│              ADMIN UPDATES DATABASE                          │
│              (Supabase Dashboard or SQL)                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         UPDATE themes                                        │
│         SET is_featured = true                              │
│         WHERE id = 'xxx'                                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              DATABASE UPDATED                                │
│              (Change persists immediately)                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         USER REOPENS APP                                     │
│         (or pull-to-refresh)                                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         APP FETCHES NEW DATA                                │
│         → Gets updated theme with is_featured = true        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│         UI UPDATES                                           │
│         → Theme appears in featured carousel                │
└─────────────────────────────────────────────────────────────┘
```

---

## 💻 Code Examples

### Complete Swift Implementation

#### 1. Service Layer

```swift
import Foundation

protocol ThemeServiceProtocol {
    func fetchThemes() async throws -> [Theme]
    func fetchThemeDetail(id: String) async throws -> Theme
}

class ThemeService: ThemeServiceProtocol {
    static let shared = ThemeService()
    
    private var baseURL: String { AppConfig.supabaseURL }
    private var anonKey: String { AppConfig.supabaseAnonKey }
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func fetchThemes() async throws -> [Theme] {
        // Build query URL
        let queryParams = [
            "is_available=eq.true",
            "select=id,name,description,thumbnail_url,prompt,is_featured,is_available,default_settings,created_at",
            "order=is_featured.desc,name.asc"
        ].joined(separator: "&")
        
        guard let url = URL(string: "\(baseURL)/rest/v1/themes?\(queryParams)") else {
            throw AppError.invalidResponse
        }
        
        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Execute request
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ ThemeService: Backend error: \(errorString)")
            }
            throw AppError.networkFailure
        }
        
        // Decode JSON
        let decoder = JSONDecoder()
        do {
            let themes = try decoder.decode([Theme].self, from: data)
            return themes
        } catch {
            print("❌ ThemeService: Failed to decode themes: \(error)")
            throw AppError.invalidResponse
        }
    }
    
    func fetchThemeDetail(id: String) async throws -> Theme {
        let queryParams = [
            "id=eq.\(id)",
            "is_available=eq.true",
            "select=id,name,description,thumbnail_url,prompt,is_featured,is_available,default_settings,created_at"
        ].joined(separator: "&")
        
        guard let url = URL(string: "\(baseURL)/rest/v1/themes?\(queryParams)") else {
            throw AppError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppError.networkFailure
        }
        
        let decoder = JSONDecoder()
        let themes = try decoder.decode([Theme].self, from: data)
        guard let theme = themes.first else {
            throw AppError.invalidResponse
        }
        
        return theme
    }
}
```

#### 2. ViewModel Layer

```swift
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {
    @Published var creditsRemaining: Int = 0
    @Published var searchQuery: String = ""
    @Published var featuredThemes: [Theme] = []
    @Published var allThemes: [Theme] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingErrorAlert: Bool = false
    
    private let themeService: ThemeServiceProtocol
    private let creditService: CreditServiceProtocol
    
    init(
        themeService: ThemeServiceProtocol = ThemeService.shared,
        creditService: CreditServiceProtocol = CreditService.shared
    ) {
        self.themeService = themeService
        self.creditService = creditService
    }
    
    var filteredThemes: [Theme] {
        if searchQuery.isEmpty {
            return allThemes
        }
        return allThemes.filter { theme in
            theme.name.localizedCaseInsensitiveContains(searchQuery) ||
            (theme.description?.localizedCaseInsensitiveContains(searchQuery) ?? false)
        }
    }
    
    func loadData() {
        Task {
            isLoading = true
            do {
                // Fetch themes (critical - must succeed)
                let fetchedThemes = try await themeService.fetchThemes()
                
                // Update themes state immediately
                allThemes = fetchedThemes
                featuredThemes = fetchedThemes.filter { $0.isFeatured }
                
                // Fetch credits separately (non-critical - can fail gracefully)
                do {
                    let fetchedCredits = try await creditService.fetchCredits()
                    creditsRemaining = fetchedCredits
                } catch {
                    print("⚠️ HomeViewModel: Failed to fetch credits: \(error)")
                    creditsRemaining = 0
                }
                
            } catch {
                handleError(error)
            }
            isLoading = false
        }
    }
    
    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            errorMessage = appError.errorDescription
        } else {
            errorMessage = "error.general.unexpected"
        }
        showingErrorAlert = true
    }
}
```

#### 3. Model Layer (with JSONB support)

```swift
import Foundation

struct Theme: Identifiable, Codable {
    let id: String
    let name: String
    let description: String?
    let thumbnailURL: URL?
    let prompt: String
    let isFeatured: Bool
    let isAvailable: Bool
    let defaultSettings: [String: Any]?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case thumbnailURL = "thumbnail_url"
        case prompt
        case isFeatured = "is_featured"
        case isAvailable = "is_available"
        case defaultSettings = "default_settings"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        if let urlString = try container.decodeIfPresent(String.self, forKey: .thumbnailURL) {
            thumbnailURL = URL(string: urlString)
        } else {
            thumbnailURL = nil
        }
        
        prompt = try container.decode(String.self, forKey: .prompt)
        isFeatured = try container.decode(Bool.self, forKey: .isFeatured)
        isAvailable = try container.decode(Bool.self, forKey: .isAvailable)
        
        if let settingsData = try container.decodeIfPresent([String: AnyCodable].self, forKey: .defaultSettings) {
            defaultSettings = settingsData.mapValues { $0.value }
        } else {
            defaultSettings = nil
        }
        
        let dateString = try container.decode(String.self, forKey: .createdAt)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            createdAt = date
        } else {
            formatter.formatOptions = [.withInternetDateTime]
            createdAt = formatter.date(from: dateString) ?? Date()
        }
    }
}

// Helper for JSONB decoding
private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDict = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}
```

### SQL Examples

#### Insert New Theme

```sql
INSERT INTO themes (
    name,
    description,
    thumbnail_url,
    prompt,
    is_featured,
    is_available,
    default_settings
) VALUES (
    'New Year Celebration',
    'Ring in the new year with style',
    'https://example.com/newyear.jpg',
    'A festive New Year celebration with fireworks, confetti, and cheering crowds',
    true,
    true,
    '{"duration": 8, "aspect_ratio": "16:9"}'::jsonb
);
```

#### Update Theme

```sql
UPDATE themes 
SET 
    prompt = 'Updated prompt text',
    is_featured = true,
    default_settings = '{"duration": 12, "aspect_ratio": "9:16"}'::jsonb
WHERE id = '550e8400-e29b-41d4-a716-446655440000';
```

#### Bulk Operations

```sql
-- Feature all holiday themes
UPDATE themes 
SET is_featured = true 
WHERE name ILIKE '%christmas%' 
   OR name ILIKE '%holiday%' 
   OR name ILIKE '%new year%';

-- Hide all themes with specific category
UPDATE themes 
SET is_available = false 
WHERE description ILIKE '%deprecated%';
```

---

## ✅ Best Practices

### 1. Database Design

✅ **DO:**
- Use partial indexes for filtered queries
- Set appropriate defaults (`is_available = true`)
- Use JSONB for flexible settings
- Add `created_at` for audit trail

❌ **DON'T:**
- Don't store sensitive data in themes table
- Don't allow user INSERT/UPDATE/DELETE
- Don't forget RLS policies

### 2. API Design

✅ **DO:**
- Filter at database level (`is_available=eq.true`)
- Sort in query (`order=is_featured.desc`)
- Use proper HTTP headers
- Handle errors gracefully

❌ **DON'T:**
- Don't fetch all data and filter in app
- Don't ignore error responses
- Don't expose service_role key to frontend

### 3. Frontend Design

✅ **DO:**
- Separate concerns (Service, ViewModel, View)
- Use async/await for API calls
- Handle loading and error states
- Cache data when appropriate

❌ **DON'T:**
- Don't block UI thread
- Don't ignore network errors
- Don't hardcode content

### 4. Security

✅ **DO:**
- Enable RLS on all tables
- Use anon key for read operations
- Use service_role only on backend
- Validate all inputs

❌ **DON'T:**
- Don't expose service_role key
- Don't allow user modifications
- Don't skip RLS policies

### 5. Performance

✅ **DO:**
- Use partial indexes
- Filter at database level
- Implement caching (ETag, etc.)
- Limit query results if needed

❌ **DON'T:**
- Don't fetch unnecessary fields
- Don't query on every render
- Don't ignore database indexes

---

## 🔧 Troubleshooting

### Issue 1: Themes Not Appearing

**Symptoms:** Themes don't show in app

**Checklist:**
1. ✅ Verify `is_available = true` in database
2. ✅ Check RLS policy is enabled
3. ✅ Verify API key is correct
4. ✅ Check network connectivity
5. ✅ Review app logs for errors

**Solution:**
```sql
-- Check theme availability
SELECT id, name, is_available, is_featured 
FROM themes 
WHERE id = 'your-theme-id';

-- If is_available is false, update it:
UPDATE themes 
SET is_available = true 
WHERE id = 'your-theme-id';
```

### Issue 2: Featured Themes Not in Carousel

**Symptoms:** Themes with `is_featured = true` don't appear in carousel

**Checklist:**
1. ✅ Verify `is_featured = true` in database
2. ✅ Check ViewModel filtering logic
3. ✅ Verify UI rendering logic
4. ✅ Check for empty array handling

**Solution:**
```swift
// In HomeViewModel, ensure filtering is correct:
featuredThemes = fetchedThemes.filter { $0.isFeatured }

// In HomeView, check if array is empty:
if !viewModel.featuredThemes.isEmpty {
    featuredThemesSection
}
```

### Issue 3: API Errors

**Symptoms:** Network errors or 401/403 responses

**Checklist:**
1. ✅ Verify API key is correct
2. ✅ Check RLS policy allows SELECT
3. ✅ Verify URL is correct
4. ✅ Check request headers

**Solution:**
```swift
// Verify headers are set correctly:
request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
request.setValue(anonKey, forHTTPHeaderField: "apikey")

// Check RLS policy:
-- Should allow SELECT for is_available = true
CREATE POLICY "Anyone can view available themes"
ON themes FOR SELECT
USING (is_available = true);
```

### Issue 4: JSON Decoding Errors

**Symptoms:** App crashes on theme fetch

**Checklist:**
1. ✅ Verify JSON structure matches model
2. ✅ Check date format (ISO8601)
3. ✅ Verify JSONB decoding for settings
4. ✅ Check for null values

**Solution:**
```swift
// Add error handling:
do {
    let themes = try decoder.decode([Theme].self, from: data)
    return themes
} catch {
    print("❌ Decoding error: \(error)")
    // Log the raw JSON for debugging
    if let jsonString = String(data: data, encoding: .utf8) {
        print("Raw JSON: \(jsonString)")
    }
    throw AppError.invalidResponse
}
```

### Issue 5: Slow Performance

**Symptoms:** App takes long to load themes

**Checklist:**
1. ✅ Verify indexes are created
2. ✅ Check query is using indexes
3. ✅ Limit number of fields in SELECT
4. ✅ Implement caching

**Solution:**
```sql
-- Verify indexes exist:
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'themes';

-- Add missing indexes:
CREATE INDEX IF NOT EXISTS idx_themes_featured 
ON themes(is_featured) 
WHERE is_featured = true;

CREATE INDEX IF NOT EXISTS idx_themes_available 
ON themes(is_available) 
WHERE is_available = true;
```

---

## 🚀 Future Enhancements

### 1. Caching Layer

**Implementation:**
- Add ETag support for conditional requests
- Cache themes locally (UserDefaults/CoreData)
- Implement cache invalidation strategy

**Benefits:**
- Faster app startup
- Reduced API calls
- Offline support

### 2. Pull-to-Refresh

**Implementation:**
```swift
ScrollView {
    // Content
}
.refreshable {
    await viewModel.loadData()
}
```

**Benefits:**
- User can manually refresh
- Better UX

### 3. Admin Panel

**Implementation:**
- Build web interface for theme management
- Add bulk operations
- Include analytics dashboard

**Benefits:**
- Easier content management
- No SQL knowledge required
- Visual interface

### 4. Analytics Integration

**Implementation:**
- Track theme views
- Track theme selections
- Track featured carousel interactions

**Benefits:**
- Data-driven decisions
- A/B testing support
- Performance insights

### 5. Versioning System

**Implementation:**
- Add `version` field to themes
- Track prompt changes
- Rollback capability

**Benefits:**
- Audit trail
- Easy rollback
- Change tracking

### 6. Scheduled Updates

**Implementation:**
- Add `featured_until` timestamp
- Auto-unfeature after date
- Scheduled campaigns

**Benefits:**
- Automated campaigns
- No manual intervention
- Time-based promotions

### 7. Multi-Language Support

**Implementation:**
- Add `translations` JSONB field
- Store name/description in multiple languages
- App selects based on user locale

**Benefits:**
- Internationalization
- Single table for all languages
- Easy translation updates

---

## 📝 Summary

### Key Takeaways

1. **Database-Driven:** Content lives in database, not code
2. **RLS Security:** Row-level security protects data
3. **Dynamic Updates:** Change content without app updates
4. **Two Flags:** `is_available` (visibility) and `is_featured` (promotion)
5. **Three Layers:** Database → API → Frontend
6. **No App Updates:** All content changes happen remotely

### Implementation Checklist

- [ ] Create `themes` table with all fields
- [ ] Add partial indexes for performance
- [ ] Enable RLS and create SELECT policy
- [ ] Implement Service layer (API calls)
- [ ] Implement ViewModel layer (state management)
- [ ] Implement Model layer (data structures)
- [ ] Implement View layer (UI)
- [ ] Test all remote control scenarios
- [ ] Add error handling
- [ ] Add loading states
- [ ] Document admin operations

### Quick Start

1. **Database:**
   ```sql
   -- Run migration to create themes table
   ```

2. **Backend:**
   ```swift
   // Implement ThemeService
   ```

3. **Frontend:**
   ```swift
   // Implement HomeViewModel and HomeView
   ```

4. **Test:**
   ```sql
   -- Insert test themes
   -- Verify they appear in app
   ```

---

## 📚 Additional Resources

- [Supabase RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [PostgreSQL JSONB Guide](https://www.postgresql.org/docs/current/datatype-json.html)
- [Swift Codable Guide](https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types)

---

**Document Version:** 1.0  
**Last Updated:** 2025-01-XX  
**Maintained By:** Rendio AI Team

