# BananaUniverse 🍌✨

**Professional AI Image Processing Suite for iOS**

BananaUniverse is a comprehensive iOS app that transforms your photos using 27+ cutting-edge AI models. Built with the Steve Jobs philosophy of "Simplicity is the ultimate sophistication," it delivers professional-grade image enhancement through a fast, elegant WhatsApp-style chat interface powered by Supabase Edge Functions.

**Current Version: 1.0.1** - Latest release with enhanced quota system, improved security, and bug fixes.

## ✨ Features

### 🎨 **27 AI-Powered Tools Across 4 Categories:**

**Photo Editor (7 Tools):**
- Remove Object from Image
- Remove Background  
- Put Items on Models
- Add Objects to Images
- Change Image Perspectives
- Generate Image Series
- Style Transfers

**Pro Photos (10 Tools):**
- LinkedIn Headshot Generator
- Passport Photo Creator
- Twitter/X Avatar Maker
- Gradient Headshot
- Resume Photo Generator
- Slide Background Maker
- YouTube Thumbnail Creator
- CV/Portfolio Portrait
- Profile Banner Generator
- Designer-Style ID Photo

**Enhancer (2 Tools):**
- Image Upscaler (2x-4x)
- Historical Photo Restore

**Seasonal (8 Tools):**
- Thanksgiving Magic Edit
- Thanksgiving Family Portrait
- Autumn Color Enhancer
- Christmas Magic Edit
- Holiday Portrait
- Winter Wonderland
- Santa Hat Overlay
- New Year Glamour
- Confetti Celebration

### 🚀 **Core Capabilities:**
- **WhatsApp-Style Chat Interface**: Modern, intuitive messaging UI for AI interactions
- **Instant Processing**: < 35 seconds total processing time
- **Smart Credit System**: Credit-based access to AI processing
- **Real-time Rate Limiting**: Built-in usage tracking and limits
- **Image Library**: Complete history of processed images with save/share functionality
- **Search & Discovery**: Quick search across all 27 tools
- **Theme Support**: Light, Dark, and Auto modes
- **Credit Purchases**: Buy credits to process AI images (no subscription required)
- **Steve Jobs Architecture**: Single edge function, direct processing, no polling

## 🏗️ Tech Stack

### **Frontend (iOS)**
- **Language**: Swift 5.9+ + SwiftUI (iOS 15.0+)
- **Architecture**: Feature-based MVVM with Combine
- **UI Framework**: SwiftUI with custom design system
- **Libraries**: 
  - Supabase Swift SDK (auth + database + storage)
  - StoreKit 2 (native credit purchases)
  - Kingfisher (image loading/caching)
  - FalClient (AI model integration)

### **Backend (Serverless)**
- **Runtime**: Supabase Edge Functions (Deno 1.x + TypeScript)
- **AI Provider**: fal.ai (27+ production models)
- **Database**: Supabase PostgreSQL with RLS policies
- **Storage**: Supabase Storage with organized file structure
- **Rate Limiting**: Database-driven daily quota tracking

### **Key Libraries**
| Library | Purpose | Integration |
|---------|---------|-------------|
| **Supabase-Swift** | Auth + database + storage | SPM |
| **StoreKit 2** | Native Apple credit purchases | Native |
| **Kingfisher** | Image loading/caching | SPM |
| **FalClient** | AI model integration | SPM |

## 🚀 Getting Started

### Prerequisites

- **Xcode 15.0+** with iOS 15.0+ target
- **Supabase account** with project created
- **fal.ai account** with API access
- **App Store Connect** account (for credit purchases)

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/jansoganci/banana.universe.git
cd banana.universe
```

2. **Open the project:**
```bash
open BananaUniverse.xcodeproj
```

3. **Configure Supabase:**
   - Create a new Supabase project
   - Run migrations: `supabase db reset`
   - Deploy Edge Function: `supabase functions deploy process-image`
   - Update `Config.swift` with your Supabase URL and keys

4. **Configure Storage Bucket:**
   - Create `noname-banana-images-prod` bucket in Supabase
   - Set up RLS policies for user access

5. **Configure fal.ai:**
   - Get API key from fal.ai dashboard
   - Update Edge Function environment variables:
   ```bash
   supabase secrets set FAL_KEY=your-fal-ai-key
   ```

7. **Build and run:**
```bash
# Clean build folder
Cmd + Shift + K

# Build and run
Cmd + R
```

## 📱 App Structure

```
BananaUniverse/
├── App/                    # Main app entry point
│   ├── BananaUniverseApp.swift
│   ├── AppDelegate.swift
│   └── ContentView.swift   # Tab navigation
├── Core/                   # Core components and services
│   ├── Components/        # Reusable UI components
│   ├── Config/            # App configuration
│   ├── Design/            # Design system and tokens
│   ├── Models/            # Data models
│   ├── Services/          # Business logic services
│   └── Utils/             # Utility functions
├── Features/              # Feature-specific modules
│   ├── Authentication/    # User auth flows
│   ├── Chat/             # WhatsApp-style AI processing interface
│   ├── Home/             # Main dashboard with search & categories
│   ├── Library/          # Image history with save/share
│   ├── Profile/          # User settings & account management
│   └── Paywall/          # Credit purchase UI
└── supabase/             # Backend functions and migrations
    ├── functions/        # Edge Functions
    └── migrations/       # Database migrations
```

## 🔧 Configuration

### Supabase Setup

1. **Create Supabase Project:**
```bash
supabase init
supabase start
```

2. **Run Database Migrations:**
```bash
supabase db reset
# This runs all migrations in supabase/migrations/
```

3. **Deploy Edge Function:**
```bash
supabase functions deploy process-image
```

4. **Configure Storage Bucket:**
   - Create `noname-banana-images-prod` bucket
   - Set up RLS policies for user access

### Environment Configuration

**iOS App (`Config.swift`):**
```swift
struct Config {
    static let supabaseURL = "your-supabase-url"
    static let supabaseAnonKey = "your-anon-key"
    static let supabaseBucket = "noname-banana-images-prod"
    static let edgeFunctionURL = "your-edge-function-url"
}
```

**Edge Function (Environment Variables):**
```bash
supabase secrets set FAL_KEY=your-fal-ai-key
```

### Credit System

- **Credit-Based Access**: Purchase credits to process AI images
- **No Subscriptions**: Pay-as-you-go model
- **Storage**: Credit balance tracked per user with idempotency protection

## 🎯 Performance & Architecture

### **Steve Jobs Philosophy**
Built following the principle: *"Simplicity is the ultimate sophistication"*

- **Single Edge Function**: One function handles all AI processing
- **Direct Processing**: No polling, immediate results via WebSocket-style updates
- **WhatsApp-Style UI**: Familiar chat interface for natural interaction
- **Local Quota Management**: Instant quota checks, server validation on processing
- **Clean Separation**: iOS handles UI, Edge Function handles AI

### **Performance Metrics**
- **Processing Time**: < 35 seconds total
- **Cold Start**: < 200ms
- **Success Rate**: 99%+
- **Offline Support**: Local storage and sync
- **Quota System**: Robust daily tracking with idempotency protection
- **Security**: Enterprise-grade RLS policies and data protection

### **UI/UX Features**
- **Modern Design System**: Consistent tokens for colors, spacing, typography
- **Theme Support**: Light/Dark/Auto with smooth transitions
- **Search Functionality**: Quick tool discovery across all categories
- **Image Management**: Save to Photos, share, full-screen viewing
- **Quota Warnings**: Smart notifications when approaching daily limit

## 📄 License

This project is private and proprietary. All rights reserved.

## 🤝 Contributing

This is a private project. For questions or support, contact the development team.

## 📚 Documentation

- **Design System**: `docs/design/` - Complete UI/UX documentation
- **Tech Stack**: `docs/tech_stack.md` - Detailed technical architecture  
- **Master Plan**: `STEVE_JOBS_MASTER_PLAN.md` - Development philosophy and goals
- **Changelog**: `CHANGELOG.md` - Version history and release notes
- **Quota System**: Database migrations include comprehensive quota tracking

---
