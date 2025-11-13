# Data Models Reference

Complete documentation of all data models, their properties, relationships, and usage patterns.

## Core Models

### Tool

Represents an AI processing tool available in the app.

```swift
struct Tool: Identifiable {
    let id: String                    // Unique tool identifier
    let title: LocalizedStringKey     // Display name (localized)
    let imageURL: URL?                // Optional tool icon/image
    let category: String              // Tool category (main_tools, pro_looks, restoration, seasonal)
    let requiresPro: Bool            // Whether premium subscription required
    let modelName: String            // fal.ai model identifier
    let placeholderIcon: String      // SF Symbol name for placeholder
    let prompt: String               // Default prompt for the tool
}
```

**Categories:**
- `main_tools`: Photo editing tools (7 tools)
- `pro_looks`: Professional photo tools (10 tools)
- `restoration`: Image enhancement tools (2 tools)
- `seasonal`: Seasonal/holiday tools (8 tools)

**Static Collections:**
- `Tool.mainTools`: Array of main photo editing tools
- `Tool.proLooksTools`: Array of professional photo tools
- `Tool.restorationTools`: Array of restoration/enhancement tools
- `Tool.seasonalTools`: Array of seasonal tools

**Example:**
```swift
Tool(
    id: "remove_object",
    title: "Remove Object from Image",
    imageURL: nil,
    category: "main_tools",
    requiresPro: false,
    modelName: "lama-cleaner",
    placeholderIcon: "eraser.fill",
    prompt: "Remove the selected object naturally..."
)
```

---

### UserState

Tracks user authentication and identification state.

```swift
struct UserState {
    var isAuthenticated: Bool
    var userId: String?
    var deviceId: String
    var identifier: String  // userId if authenticated, deviceId if anonymous
}
```

**Properties:**
- `isAuthenticated`: Whether user is logged in
- `userId`: Supabase user ID (if authenticated)
- `deviceId`: Unique device identifier (for anonymous users)
- `identifier`: Unified identifier (userId or deviceId)

**Usage:**
```swift
let userState = UserState(
    isAuthenticated: true,
    userId: "user-123",
    deviceId: "device-456",
    identifier: "user-123"  // Uses userId when authenticated
)
```

---

### ProcessedImage

Represents a processed image result from AI processing.

**Database Schema:**
```sql
CREATE TABLE processed_images (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    device_id TEXT,                    -- For anonymous users
    tool_id TEXT NOT NULL,
    original_image_url TEXT NOT NULL,
    processed_image_url TEXT NOT NULL,
    prompt TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Swift Model:**
```swift
struct ProcessedImage: Identifiable, Codable {
    let id: UUID
    let userId: String?
    let deviceId: String?
    let toolId: String
    let originalImageURL: String
    let processedImageURL: String
    let prompt: String?
    let createdAt: Date
    let updatedAt: Date
}
```

**Relationships:**
- Links to `users` table via `user_id` (if authenticated)
- Links to tool via `tool_id`
- Stored in Supabase Storage at `processed_image_url`

---

### QuotaInfo

Represents user's quota status and limits.

**Database Schema:**
```sql
CREATE TABLE daily_quota (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    device_id TEXT,                    -- For anonymous users
    date DATE NOT NULL,
    requests_made INTEGER DEFAULT 0,
    is_premium BOOLEAN DEFAULT false,
    UNIQUE(user_id, date),             -- For authenticated users
    UNIQUE(device_id, date)           -- For anonymous users
);
```

**Swift Model:**
```swift
struct QuotaInfo {
    let quotaUsed: Int
    let quotaLimit: Int
    let quotaRemaining: Int
    let isPremium: Bool
    let date: Date
}
```

**Quota Limits:**
- Free users: 5 requests/day
- Premium users: 3 requests/day (temporary)
- Reset: Midnight UTC daily

---

### Subscription

Represents user subscription status (server-side validation).

**Database Schema:**
```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    device_id TEXT,                    -- For anonymous premium users
    status TEXT CHECK (status IN ('active', 'expired', 'cancelled', 'grace_period')),
    product_id TEXT NOT NULL,          -- 'weekly_pro' or 'yearly_pro'
    expires_at TIMESTAMPTZ NOT NULL,
    original_transaction_id TEXT UNIQUE NOT NULL,  -- Apple StoreKit ID
    platform TEXT DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Swift Model:**
```swift
struct Subscription: Codable {
    let id: UUID
    let userId: String?
    let deviceId: String?
    let status: SubscriptionStatus
    let productId: String
    let expiresAt: Date
    let originalTransactionId: String
    let platform: String
}

enum SubscriptionStatus: String, Codable {
    case active
    case expired
    case cancelled
    case gracePeriod = "grace_period"
}
```

**Products:**
- `weekly_pro`: $4.99/week (3-day free trial)
- `yearly_pro`: $79.99/year (3-day free trial)

---

## Service Models

### AppState

Global application state managed as singleton.

```swift
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var userState: UserState
    @Published var isPremium: Bool
    @Published var quotaUsed: Int
    @Published var quotaLimit: Int
    @Published var seasonalMode: SeasonalMode
}
```

**Properties:**
- `userState`: Current user authentication state
- `isPremium`: Premium subscription status
- `quotaUsed`: Current quota usage
- `quotaLimit`: Daily quota limit
- `seasonalMode`: Current seasonal theme mode

---

### ChatMessage

Represents a message in the chat interface.

```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let imageURL: URL?
    let timestamp: Date
    let toolID: String?
    let status: MessageStatus
}

enum MessageStatus {
    case sending
    case processing
    case completed
    case failed
}
```

**Usage:**
- User messages: `isUser = true`
- AI responses: `isUser = false`, includes `processedImageURL`

---

## Database Relationships

### User → ProcessedImages
- **Type:** One-to-Many
- **Relationship:** `processed_images.user_id → auth.users.id`
- **RLS:** Users can only see their own images

### User → DailyQuota
- **Type:** One-to-Many (one per day)
- **Relationship:** `daily_quota.user_id → auth.users.id`
- **Constraint:** `UNIQUE(user_id, date)`

### User → Subscriptions
- **Type:** One-to-Many (can have multiple subscriptions over time)
- **Relationship:** `subscriptions.user_id → auth.users.id`
- **Active:** Only one active subscription per user at a time

### Device → DailyQuota (Anonymous)
- **Type:** One-to-Many (one per day)
- **Relationship:** `daily_quota.device_id` (no foreign key, tracked by string)
- **Constraint:** `UNIQUE(device_id, date)`

---

## Data Flow

### Image Processing Flow

1. **User selects tool** → `Tool` model
2. **User uploads image** → `UIImage` → `Data`
3. **Upload to Storage** → Returns `imageURL: String`
4. **Call Edge Function** → `ProcessImageRequest`
5. **Edge Function processes** → Returns `ProcessImageResponse`
6. **Save to Database** → `ProcessedImage` model
7. **Update Quota** → `DailyQuota` record
8. **Display in UI** → `ChatMessage` with processed image

### Quota Check Flow

1. **Get User State** → `UserState.identifier`
2. **Query Database** → `daily_quota` table
3. **Check Limit** → Compare `requests_made` vs `quota_limit`
4. **Return Status** → `QuotaInfo` model
5. **Update UI** → Show quota badge, paywall if exceeded

---

## Model Conventions

### Naming
- **Models:** PascalCase (e.g., `ProcessedImage`)
- **Properties:** camelCase (e.g., `processedImageURL`)
- **Database:** snake_case (e.g., `processed_image_url`)

### Codable
- All models that interact with API implement `Codable`
- Database models use `CodingKeys` for snake_case conversion

### Identifiable
- Models displayed in lists implement `Identifiable`
- Use `UUID` for `id` property

### Published
- ViewModels use `@Published` for reactive UI updates
- Models used in `@StateObject` or `@ObservedObject` should be `ObservableObject`

---

## Type Safety

### Enums for Status Values

```swift
enum SubscriptionStatus: String, Codable {
    case active
    case expired
    case cancelled
    case gracePeriod = "grace_period"
}

enum MessageStatus {
    case sending
    case processing
    case completed
    case failed
}
```

### Optionals
- Use optionals for nullable database fields
- Use optionals for values that may not exist yet
- Avoid force unwrapping, use `guard let` or `if let`

---

## Migration Notes

Models may change between migrations. Key changes:
- `daily_quota` table: Added `is_premium` field
- `subscriptions` table: Added `device_id` for anonymous premium users
- `processed_images`: Added `device_id` for anonymous users

Always check migration files in `supabase/migrations/` for schema changes.

