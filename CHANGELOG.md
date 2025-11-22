# BananaUniverse - Changelog

## Version 1.2.0 - Database-Driven Content & Credit System Overhaul (November 2025)

### 🎯 Major System Changes

#### **Credit System Transformation** 🔄
- **Migration from Daily Quota → Persistent Credits**
  - Changed from renewable daily quota to persistent credit model
  - Default: 10 credits per user (one-time, not daily reset)
  - 1 credit = 1 image generation
  - Credit purchase via IAP (10, 25, 50, 100 packs)
  - Architecture: CreditManager + QuotaService + QuotaCache
  - Atomic credit operations with stored procedures
  - Lifetime credit tracking (credits_total + credits_remaining)

#### **Database-Driven Content System** 📚
- **Dynamic Themes & Categories** (85+ migrations)
  - All 103 tools moved from hardcoded Swift to Supabase database
  - Remote content management (no app update needed for new tools)
  - `themes` table with RLS policies
  - `categories` table with display ordering
  - ThemeService with 5-minute caching
  - CategoryService for dynamic category management

#### **Massive Category Expansion** 🚀
- **103 AI Tools** (up from 27 in v1.1.0)
  - Main Tools: 7
  - Pro Looks: 10
  - Restoration: 2
  - Seasonal: 9
  - **Animated Vehicles: 10** (NEW - with thumbnails ✅)
  - **Anime Styles: 15** (NEW - viral potential 🔥)
  - **Retro Aesthetic: 10** (NEW - nostalgia factor 🔥)
  - **Toy Style: 10** (NEW)
  - **Meme Magic: 12** (NEW - social media optimized 🔥)
  - Thanksgiving: 8 (expanded from 3)
  - Christmas: 10 (expanded from 4)

### 🎨 New Features

#### **nano-banana & nano-banana-pro Integration**
- Dual model support (standard + pro)
- Multi-image upload (1-2 images per generation)
- User-selectable aspect ratios: 1:1, 16:9, 9:16, 4:3
- Output format selection: JPEG, PNG, WEBP
- Resolution control (Pro model only): 1K, 2K, 4K
- Dynamic credit cost calculation based on model/resolution
- Enhanced ChatView with collapsible settings panel

#### **Thumbnail System**
- Theme thumbnails via Supabase Storage (`theme-thumbnails` bucket)
- AsyncImage loading with SF Symbol fallback
- 120x120px display, 240x240px Retina @2x
- Animated Vehicles category: 10 thumbnails ✅
- 93 remaining themes ready for thumbnail generation
- Documentation: `theme-thumbnails-docs/` folder with generation guide

#### **Realtime Updates**
- Supabase Realtime enabled on `processed_images` table
- Live job status updates without polling
- RealtimeService for WebSocket connection management
- Automatic UI refresh on job completion
- Better UX for async AI generation

#### **IAP Credit Purchases**
- StoreKit 2 integration for credit packs
- Products stored in database (`iap_products` table)
- Server-side purchase verification
- Credit purchase packs: 10, 25, 50, 100 credits
- Transaction history tracking
- Purchase restoration support

### 🔧 Technical Improvements

#### **Database Architecture** (94+ migrations)
- **New Tables:**
  - `themes` - AI tools/effects (103 entries)
  - `categories` - Dynamic category system
  - `iap_products` - StoreKit product configurations
  - `iap_transactions` - Purchase history with Apple transaction IDs
  - `credit_transactions` - Audit log with balance snapshots
  - `image_storage` - Storage bucket references
  - `rate_limits` - API rate limiting
  - `error_logs` - Error tracking

- **Stored Procedures:**
  - `submit_job_atomic()` - Atomic job creation + credit deduction
  - `add_credits()` - Credit addition with transaction logging
  - `deduct_credits()` - Credit deduction with rollback support
  - `get_credits()` - Unified credit balance lookup (device_id + user_id)

- **RLS Policies:**
  - Row-Level Security on all user-facing tables
  - Device-based + user-based access control
  - Public read access for themes/categories

#### **Backend Services**
- **Edge Functions (12 total):**
  - `submit-job` - Job submission with nano-banana support
  - `get-result` - Result polling
  - `webhook-handler` - fal.ai webhook processing
  - `verify-iap-purchase` - Server-side IAP verification
  - `iap-webhook` - Apple server notifications
  - `cleanup-db`, `cleanup-images`, `cleanup-logs` - Maintenance
  - `health-check`, `log-alert`, `log-monitor` - Monitoring

- **Idempotency & Reliability:**
  - Client request ID tracking
  - Duplicate detection via `client_request_id`
  - Rollback on failure (refund credits automatically)
  - Race condition protection (webhook vs. job update)

#### **iOS Architecture**
- **Services:**
  - `CreditManager` - UI orchestration (@MainActor)
  - `QuotaService` - Network operations (actor)
  - `QuotaCache` - Local persistence (UserDefaults)
  - `ThemeService` - Theme fetching with 5-min cache
  - `CategoryService` - Category management
  - `RealtimeService` - Supabase Realtime connections
  - `StorageService` - User data persistence
  - `NetworkMonitor` - Connectivity tracking
  - `SeasonalManager` - Dynamic seasonal content

- **Models:**
  - `Theme` - Codable model with snake_case mapping
  - `Category` - Dynamic categories from database
  - `CreditInfo` - Credit balance + transaction history
  - `AspectRatio`, `ModelType`, `OutputFormat`, `Resolution` - nano-banana enums

### 🐛 Bug Fixes & Improvements

#### **Credit System Fixes**
- Fixed device_id unique constraint issues (migrations 092-093)
- Resolved get_credits() table reference bugs
- Enhanced credit balance synchronization
- Improved anonymous user credit tracking
- Added lifetime credit tracking (total vs. remaining)

#### **Database Optimizations**
- Category display ordering improvements (migration 085)
- Duplicate theme cleanup (migration 079)
- Old category deletion (migration 082)
- Enhanced indexes for performance
- Optimized RLS policy checks

#### **Security Enhancements**
- **CRITICAL:** Removed exposed Supabase Service Role Key (commit 2f1fa33)
- Added security remediation guide
- Key rotation procedures documented
- Enhanced authentication checks
- Improved error logging without sensitive data

#### **Performance Improvements**
- Parallel signed URL loading in LibraryView
- ThemeService caching (5-minute TTL)
- CategoryService caching (5-minute TTL)
- Reduced unnecessary database calls
- Optimized image loading with AsyncImage

### 📱 User Experience Enhancements

#### **Content Discovery**
- Database-driven tool browsing
- Dynamic category loading
- Featured carousel with remote content
- Search across 103 AI tools
- Category-based organization
- Thumbnail previews (Animated Vehicles complete)

#### **Credit Management**
- Persistent credit balance display
- Purchase history in profile
- Low credit warnings (≤1 remaining)
- IAP credit purchase flow
- Transaction audit trail
- Lifetime usage statistics

#### **Image Processing**
- Multi-image upload support (nano-banana)
- Aspect ratio selection UI
- Output format selection
- Resolution control (Pro model)
- Real-time job status updates
- Better error messaging

### 📊 Statistics

- **Database Migrations:** 94+ (from 60 in v1.1.0)
- **AI Tools:** 103 (from 27 in v1.1.0) - **281% increase**
- **Categories:** 11 (from 4 in v1.1.0)
- **Edge Functions:** 12 (production-ready)
- **Stored Procedures:** 8 (atomic operations)
- **Tables:** 15+ (comprehensive data model)

### 🚀 What's Next

#### **Pending Features**
- Complete thumbnail generation for 93 remaining themes
  - Documentation ready in `theme-thumbnails-docs/`
  - Midjourney/DALL-E prompts prepared
  - Estimated: 4-5 hours, $10-30 cost
- Video generation support (nano-banana video models)
- Advanced image editing controls
- User-created prompt library
- Social sharing features

---

## Version 1.1.0 - Major UI/UX Redesign & New Features (October 2025)

### 🎨 UI/UX Major Changes
• **Complete Chat Interface Redesign**: Rebuilt with WhatsApp-style messaging interface
  - Modern chat bubbles with gradient styling
  - Smooth animations and transitions
  - Full-screen image viewer with zoom and pan gestures
  - Toast notifications for user feedback
  - Empty state with upload prompts
  - Processing indicators with progress tracking

• **Unified Header Bar**: New consistent header component across all screens
  - App logo integration
  - Quota display badges (compact and detailed)
  - Premium user unlimited badge
  - Get PRO button with premium styling
  - Theme-aware design

• **Home Screen Redesign**: Complete overhaul with modern navigation
  - Featured carousel showcasing tools from all categories
  - Category-based horizontal scroll rows (Amazon-style)
  - Real-time search functionality with debouncing
  - Search results filtering across all 27 tools
  - Quota warning banner for low quota users
  - Empty state for search with no results

• **Library Screen Enhancement**: Redesigned history management
  - Recent Activity section with horizontal card scroll
  - Grouped history items by date
  - Pull-to-refresh functionality
  - Image detail view with full-screen preview
  - Save to Photos library integration
  - Share sheet integration
  - Delete confirmation dialogs
  - Empty state with helpful messaging

• **Profile Screen Improvements**: Enhanced user settings and account management
  - Premium card with subscription status
  - Subscription renewal date display
  - Account section with email display
  - Theme selector (Light/Dark/Auto)
  - Language settings placeholder
  - Notification toggle
  - Account deletion with confirmation
  - AI Service Disclosure view
  - Support links integration

• **Paywall Redesign**: Modern premium subscription interface
  - Premium animated gradient background
  - Hero section with crown icon
  - Benefit cards with icons and descriptions
  - Premium product cards with trial badges
  - Best value highlighting for yearly plan
  - Loading and error states
  - Restore purchases functionality

### ✨ New Features
• **27 AI Tools**: Expanded from 19 to 27 tools across 4 categories
  - Added 8 seasonal tools (Thanksgiving, Christmas, New Year)
  - Organized into Photo Editor, Pro Photos, Enhancer, and Seasonal categories

• **Search Functionality**: Quick tool discovery
  - Real-time search across all tools
  - Searches tool names, prompts, and categories
  - Debounced input for performance
  - Empty state handling

• **Theme System**: Complete theme management
  - Light mode support
  - Dark mode support
  - Auto theme (follows system)
  - Persistent user preference
  - Smooth theme transitions
  - Theme-aware design tokens

• **Image Management**: Enhanced image handling
  - Save processed images to Photos library
  - Share images via native share sheet
  - Full-screen image viewer with zoom
  - Permission handling for Photos access
  - Image detail view with metadata

• **StoreKit 2 Integration**: Native Apple subscription management
  - Weekly subscription ($4.99/week with 3-day trial)
  - Yearly subscription ($79.99/year with 3-day trial)
  - Transaction verification and sync
  - Subscription status tracking
  - Supabase subscription sync
  - Purchase restoration
  - Transaction listener for real-time updates

• **Seasonal Tools System**: Dynamic seasonal content
  - Thanksgiving tools (3 tools)
  - Christmas tools (4 tools)
  - New Year tools (2 tools)
  - SeasonalManager for event detection
  - Featured tool rotation by season

• **Quota Warning System**: User-friendly quota management
  - Warning banner when quota is low (≤1 remaining)
  - Real-time quota display in header
  - Unlimited badge for premium users
  - Quota display in profile with detailed info

### 🔧 Technical Improvements
• **Hybrid Credit Manager**: Enhanced quota system
  - Premium status checking via StoreKit
  - Background subscription refresh
  - Automatic quota initialization
  - Backend quota sync
  - Idempotency protection

• **Supabase Integration**: Improved backend sync
  - Subscription sync function
  - User/device-based quota tracking
  - Premium status checking in database
  - Subscription expiration handling

• **Design System**: Comprehensive design tokens
  - Color system with light/dark variants
  - Typography scale
  - Spacing system (8pt grid)
  - Shadow system
  - Corner radius system
  - Gradient system
  - Semantic colors (success, error, warning)

• **Component Architecture**: Reusable UI components
  - UnifiedHeaderBar component
  - QuotaDisplayView (compact & detailed)
  - FeaturedCarouselView
  - CategoryRow component
  - ToolCard component
  - MessageBubbleView with WhatsApp styling
  - PremiumProductCard
  - PremiumBenefitCard

• **Error Handling**: Improved error management
  - Specific error messages for different scenarios
  - Network error handling
  - Purchase error handling
  - Retry mechanisms
  - User-friendly error messages

### 📱 User Experience Enhancements
• **Haptic Feedback**: Contextual haptic responses
  - Light impact for selections
  - Medium impact for important actions
  - Selection changed feedback

• **Animations**: Smooth UI transitions
  - Spring animations for interactions
  - Fade transitions for content changes
  - Scale animations for selections
  - Smooth scrolling in chat

• **Accessibility**: Improved app accessibility
  - VoiceOver labels and hints
  - Proper accessibility traits
  - Dynamic type support
  - Color contrast compliance

• **Loading States**: Better loading indicators
  - Progress views for uploads
  - Processing bubbles in chat
  - Loading states in paywall
  - Skeleton loading where appropriate

### 🔒 Security Enhancements
• **Subscription Verification**: Secure subscription handling
  - StoreKit 2 transaction verification
  - Server-side subscription sync
  - Premium status validation
  - Subscription expiration checking

• **User Data Protection**: Enhanced privacy
  - Account deletion functionality
  - AI Service Disclosure
  - Privacy policy integration
  - Terms of service links

---

## Version 1.0.1 - Bug Fixes & Improvements

### 🐛 Bug Fixes
• Fixed quota system validation issues
• Resolved anonymous user credit management
• Improved authentication error handling
• Enhanced database security policies
• Fixed quota exceeded logic and validation

### ⚡ Performance Improvements
• Optimized image processing pipeline
• Improved quota tracking accuracy
• Enhanced error logging and monitoring
• Streamlined database queries

### 🔒 Security Enhancements
• Updated database access policies (RLS)
• Improved user data protection
• Enhanced quota validation logic
• Fixed unique constraint issues

### 📱 User Experience
• Better error messages for users
• Improved quota display accuracy
• Enhanced system stability
• More reliable image processing

### 🔧 Technical Improvements
• Database schema optimizations
• Enhanced monitoring and logging
• Improved edge case handling
• Better error recovery mechanisms

---

## Version 1.0.0 - Initial Release

### 🎉 Features
• AI-powered image upscaling
• Chat functionality with AI
• User authentication system
• Quota management system
• Library for managing processed images
• Premium subscription integration
• Modern iOS interface design

---

## Release Notes for App Store Connect

### Version 1.2.0 - What's New

🚀 **Massive Content Expansion + New Credit System!**

**🎨 103 AI Tools** (from 27!)
• 76 NEW tools across 7 brand new categories
• Anime Styles - Transform into Studio Ghibli, Makoto Shinkai, and more
• Animated Vehicles - Pixar-style car transformations
• Retro Aesthetic - VHS, 80s, 90s nostalgia filters
• Meme Magic - Social media optimized effects
• Toy Style - Toy-themed transformations
• Plus: Expanded Thanksgiving & Christmas collections

**💳 New Credit System**
• Purchase credit packs (10, 25, 50, 100 credits)
• 1 credit = 1 image generation
• No more daily limits - credits never expire!
• Start with 10 free credits
• Track lifetime usage and purchases

**🎯 Enhanced AI Processing**
• Multi-image editing (up to 2 images)
• Choose aspect ratios: Square, Widescreen, Portrait
• Select output formats: JPEG, PNG, WEBP
• Pro model with 4K resolution support
• Real-time processing updates

**📸 Better Discovery**
• All tools now database-driven
• Instant content updates (no app update needed)
• Thumbnail previews for easier browsing
• Improved search across 103 tools

**⚡ Performance & Reliability**
• Faster tool loading with smart caching
• Real-time job status updates
• Optimized image loading
• Better error handling and recovery

Thank you for using BananaUniverse! This is our biggest update yet with 281% more AI tools!

---

### Version 1.1.0 - What's New

We've completely redesigned BananaUniverse to make it more intuitive and powerful!

**🎨 Beautiful New Interface**
• WhatsApp-style chat for natural AI interactions
• Modern design with smooth animations
• Light, Dark, and Auto theme support

**🔍 Discover Tools Easily**
• Search across all 27 AI tools instantly
• Browse by categories with horizontal scrolling
• Featured carousel showcasing best tools

**📸 Better Image Management**
• Save processed images directly to Photos
• Share your creations easily
• Full-screen viewing with zoom

**👑 Premium Experience**
• Beautiful new paywall design
• Weekly ($4.99/week) and Yearly ($79.99/year) plans
• 3-day free trial on yearly plan
• Unlimited access to all tools

**🎁 Seasonal Tools**
• Thanksgiving, Christmas, and New Year special effects
• New tools added for each season
• Automatic seasonal content rotation

**⚡ Performance & Reliability**
• Faster loading and smoother animations
• Better error handling and recovery
• Improved subscription management

Thank you for using BananaUniverse! We're constantly working to make your experience better.

---

### Version 1.0.1 - What's New

We've been working hard to improve BananaUniverse! This update includes:

**Bug Fixes & Stability**
• Fixed issues with quota system validation
• Improved user authentication reliability
• Enhanced overall app stability

**Performance Improvements**
• Faster image processing
• More accurate quota tracking
• Better error handling

**Security Updates**
• Enhanced user data protection
• Improved system security

Thank you for using BananaUniverse! We're constantly working to make your experience better.

---

## TestFlight Release Notes

### Version 1.2.0 - Beta Testing

🔥 **MASSIVE UPDATE - 281% More AI Tools!**

**🎨 New Content (76 new tools!)**
• Anime Styles (15 tools) - Ghibli, Makoto Shinkai, Cyberpunk, etc.
• Animated Vehicles (10 tools) - Pixar-style car transformations
• Retro Aesthetic (10 tools) - VHS, 80s, 90s filters
• Meme Magic (12 tools) - Viral social media effects
• Toy Style (10 tools) - Toy-themed transformations
• Expanded Thanksgiving (8 tools) & Christmas (10 tools)

**💳 New Credit System**
• Changed from daily quota to persistent credits
• Purchase credit packs via IAP
• Credits never expire
• Start with 10 free credits
• Track lifetime usage

**🎯 nano-banana Integration**
• Multi-image editing (1-2 images)
• Aspect ratio selection
• Output format selection
• 4K resolution (Pro model)
• Real-time status updates

**📱 Technical Highlights**
• Database-driven content (remote updates!)
• Thumbnail system for visual browsing
• Realtime job status via WebSocket
• Atomic credit operations
• Enhanced IAP verification

**🧪 Testing Focus Areas:**
1. Credit purchase flow (IAP)
2. Theme loading & caching
3. Multi-image upload
4. Aspect ratio/format selection
5. Real-time job updates
6. Thumbnail display
7. Category browsing (11 categories)

Please test thoroughly! This is our biggest update with major backend changes.

---

### Version 1.1.0 - Beta Testing

This major update brings a completely redesigned interface and powerful new features!

**🎨 New Design**
• WhatsApp-style chat interface
• Modern, clean UI throughout
• Theme support (Light/Dark/Auto)

**🔍 New Features**
• Search functionality for all tools
• Seasonal tools (Thanksgiving, Christmas, New Year)
• Image save and share capabilities
• Enhanced library with recent activity

**👑 Premium**
• Redesigned paywall
• StoreKit 2 integration
• Weekly and yearly subscriptions

**📸 Image Management**
• Save to Photos library
• Full-screen image viewer
• Better sharing options

Please test thoroughly and report any issues you encounter. Your feedback helps us improve the app before the official release!

---

### Version 1.0.1 - Beta Testing

This beta version includes several important fixes and improvements:

**Key Fixes:**
• Resolved quota validation issues
• Fixed authentication error handling
• Improved database security policies

**Improvements:**
• Better performance in image processing
• Enhanced quota tracking accuracy
• More reliable error recovery

Please test thoroughly and report any issues you encounter. Your feedback helps us improve the app before the official release!

---

*Last updated: November 21, 2025*
