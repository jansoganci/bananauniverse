# BananaUniverse 🍌✨

**Professional AI Image Processing Suite for iOS**

BananaUniverse is a comprehensive iOS app that transforms your photos using 19+ cutting-edge AI models. Built with the Steve Jobs philosophy of "Simplicity is the ultimate sophistication," it delivers professional-grade image enhancement through a fast, elegant interface powered by Supabase Edge Functions.

**Current Version: 1.0.1** - Latest release with enhanced quota system, improved security, and bug fixes.

## ✨ Features

### 🎨 **19 AI-Powered Tools Across 3 Categories:**

**Main Tools (7 Free Tools):**
- Remove Object from Image
- Remove Background  
- Put Items on Models
- Add Objects to Images
- Change Image Perspectives
- Generate Image Series
- Style Transfers

**Pro Looks (10 Premium Tools):**
- LinkedIn Headshot Generator
- Passport Photo Creator
- Twitter/X Avatar Maker
- Resume Photo Generator
- YouTube Thumbnail Creator
- Professional Headshots
- And 4 more professional tools

**Restoration (2 Tools):**
- Image Upscaler (2x-4x)
- Historical Photo Restore

### 🚀 **Core Capabilities:**
- **Instant Processing**: < 35 seconds total processing time
- **Smart Credit System**: 10 free requests/day, 100 for premium users
- **Real-time Rate Limiting**: Built-in usage tracking and limits
- **Local History**: Offline storage of processed images
- **Dark Theme**: Beautiful iOS-optimized interface
- **Steve Jobs Architecture**: Single edge function, direct processing, no polling

## 🏗️ Tech Stack

### **Frontend (iOS)**
- **Language**: Swift 5.9+ + SwiftUI (iOS 15.0+)
- **Architecture**: Feature-based MVVM with Combine
- **Libraries**: 
  - Supabase Swift SDK (auth + storage)
  - Adapty iOS (subscription management)
  - Kingfisher (image loading/caching)
  - FalClient (AI model integration)

### **Backend (Serverless)**
- **Runtime**: Supabase Edge Functions (Deno 1.x + TypeScript)
- **AI Provider**: fal.ai (19+ production models)
- **Database**: Supabase PostgreSQL with RLS policies
- **Storage**: Supabase Storage with organized file structure
- **Rate Limiting**: Database-driven daily counters

### **Key Libraries**
| Library | Purpose | Integration |
|---------|---------|-------------|
| **Supabase-Swift** | Auth + database + storage | SPM |
| **Adapty-iOS** | Subscription management | SPM |
| **Kingfisher** | Image loading/caching | SPM |
| **FalClient** | AI model integration | SPM |

## 🚀 Getting Started

### Prerequisites

- **Xcode 15.0+** with iOS 15.0+ target
- **Supabase account** with project created
- **Adapty account** (for subscription management)
- **fal.ai account** with API access

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/jansoganci/banana.universe.git
cd BananaUniverse
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

4. **Configure Adapty:**
   - Create Adapty project and get API key
   - Update `Config.swift` with Adapty public key

5. **Configure fal.ai:**
   - Get API key from fal.ai dashboard
   - Update Edge Function environment variables

6. **Build and run:**
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
├── Core/                   # Core components and services
│   ├── Components/         # Reusable UI components
│   ├── Design/            # Design system and tokens
│   ├── Models/            # Data models
│   ├── Services/          # Business logic services
│   └── Networking/        # API communication
├── Features/              # Feature-specific modules
│   ├── Authentication/    # User auth flows
│   ├── Chat/             # AI processing interface
│   ├── Home/             # Main dashboard
│   ├── Library/          # Image history
│   ├── Profile/          # User settings
│   └── Paywall/          # Subscription management
└── supabase/             # Backend functions and migrations
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
   - Create `bananauniverse-images-prod` bucket
   - Set up RLS policies for user access

### Environment Configuration

**iOS App (`Config.swift`):**
```swift
struct Config {
    static let supabaseURL = "your-supabase-url"
    static let supabaseAnonKey = "your-anon-key"
    static let adaptyPublicKey = "your-adapty-key"
}
```

**Edge Function (Environment Variables):**
```bash
supabase secrets set FAL_KEY=your-fal-ai-key
```

### Rate Limiting & Credits

- **Free Users**: 10 requests/day
- **Premium Users**: 100 requests/day  
- **Reset**: Daily at midnight UTC
- **Storage**: `daily_request_counts` table

## 🎯 Performance & Architecture

### **Steve Jobs Philosophy**
Built following the principle: *"Simplicity is the ultimate sophistication"*

- **Single Edge Function**: One function handles all AI processing
- **Direct Processing**: No polling, immediate results
- **Local Credit Management**: Instant credit checks, no server calls
- **Clean Separation**: iOS handles UI, Edge Function handles AI

### **Performance Metrics**
- **Processing Time**: < 35 seconds total
- **Cold Start**: < 200ms
- **Success Rate**: 99%+
- **Offline Support**: Local storage and sync
- **Quota System**: Robust daily tracking with 99.9% accuracy
- **Security**: Enterprise-grade RLS policies and data protection

## 📄 License

This project is private and proprietary. All rights reserved.

## 🤝 Contributing

This is a private project. For questions or support, contact the development team.

## 📚 Documentation

- **Design System**: `docs/design/` - Complete UI/UX documentation
- **Tech Stack**: `docs/tech_stack.md` - Detailed technical architecture  
- **Master Plan**: `STEVE_JOBS_MASTER_PLAN.md` - Development philosophy and goals
- **Changelog**: `CHANGELOG.md` - Version history and release notes
- **Quota System**: `QUOTA_SYSTEM_VALIDATION_SCENARIOS.md` - Comprehensive test documentation

---

**Built with ❤️ using the Steve Jobs philosophy: "Simplicity is the ultimate sophistication"**
