---
name: app-launch-helper
description: Simple helper for solo iOS developers launching on App Store. Helps with feature prioritization, launch planning, competitive research, and basic growth strategies - without enterprise overhead.
---

# App Launch Helper (Solo Developer Edition)

Simple, practical help for launching your iOS app on the App Store. No enterprise jargon, no complex frameworks - just what you actually need.

## When to Use This

Use this when you need help with:
- **Feature prioritization**: "What should I build next?"
- **Launch planning**: "Am I ready to submit to App Store?"
- **Competitive research**: "What do similar apps have?"
- **Pricing strategy**: "How should I price my IAP?"
- **Growth basics**: "How do I get my first 100 users?"
- **App Store Optimization**: "How do I write a good app description?"

## What This Helper Does

### 1. Feature Prioritization (Simple RICE)

When you ask "Should I build feature A or B?", I'll help you prioritize using:

**RICE Framework (simplified):**
- **Reach**: How many users will this help? (1-10)
- **Impact**: How much will it help them? (1-10)
- **Confidence**: How sure are you? (50%, 80%, 100%)
- **Effort**: How long will it take? (hours/days/weeks)

**Score = (Reach × Impact × Confidence) / Effort**

Example:
```
Feature A: Video Generation
- Reach: 8 (most users want this)
- Impact: 9 (major feature)
- Confidence: 70% (not sure about implementation)
- Effort: 3 weeks
Score: (8 × 9 × 0.7) / 3 = 16.8

Feature B: 10 New Themes
- Reach: 6 (some users)
- Impact: 5 (nice to have)
- Confidence: 100% (easy)
- Effort: 1 week
Score: (6 × 5 × 1.0) / 1 = 30

→ Build Feature B first! (Higher score)
```

### 2. App Store Launch Checklist

**Pre-Submission Checklist:**
- [ ] App tested on real device (not just simulator)
- [ ] All features work offline (if applicable)
- [ ] IAP tested in sandbox environment
- [ ] No crashes in core features
- [ ] Privacy Policy and Terms of Service URLs working
- [ ] App icon and screenshots ready (all sizes)
- [ ] App description written (focus on user benefits)
- [ ] Keywords researched (50-60 characters max)
- [ ] Pricing decided for all IAP products
- [ ] Support email/website set up
- [ ] TestFlight beta testing complete (optional but recommended)

**Post-Submission Checklist:**
- [ ] Monitor App Store Connect for review status
- [ ] Prepare for common rejections (privacy, IAP issues)
- [ ] Set up analytics (App Store Connect, Firebase, etc.)
- [ ] Plan launch announcement (social media, friends/family)
- [ ] Have update ready for quick fixes if needed

### 3. Competitive Research (Simple)

When researching competitors:

**Find Similar Apps:**
- Search App Store for your category
- Look at top 10 free and top 10 paid apps
- Check "Customers Also Downloaded" section

**Analyze Each Competitor:**
- What features do they have that you don't?
- What's their pricing model? (Free, freemium, paid, subscription)
- What do users complain about in reviews? (opportunity!)
- What do users love? (must-have features)
- How many reviews/ratings? (popularity indicator)

**Template:**
```
App Name: [Competitor]
Features I'm missing: [list]
Their pricing: [model]
User complaints: [top 3 from reviews]
User loves: [top 3 positives]
My advantage over them: [what makes you different/better]
```

### 4. Pricing Strategy (IAP for Credits)

**Credit Pack Pricing Psychology:**

**Bad Pricing (avoid this):**
```
10 credits: $0.99 ($0.099 per credit)
20 credits: $1.99 ($0.099 per credit) ❌ No bulk discount!
50 credits: $4.99 ($0.099 per credit) ❌ No incentive!
```

**Good Pricing (use this):**
```
10 credits: $2.99 ($0.30 per credit) - Starter pack
25 credits: $4.99 ($0.20 per credit) - 33% discount ✅ Popular!
50 credits: $7.99 ($0.16 per credit) - 47% discount
100 credits: $12.99 ($0.13 per credit) - 57% discount ✅ Best value!
```

**Pricing Rules:**
1. Make larger packs have clear value (30%+ discount)
2. Middle option should be "most popular" (anchor effect)
3. Test prices in TestFlight before launch
4. Check similar apps for market rates
5. Consider $0.99 trial pack for first-time buyers

### 5. Getting Your First 100 Users

**Free, Simple Strategies:**

**Week 1: Friends & Family (0-20 users)**
- Share on personal social media
- Ask friends to download and review (honestly!)
- Post in family WhatsApp/Telegram groups

**Week 2: Reddit & Communities (20-50 users)**
- r/SideProject - Share your launch story
- r/iOSBeta - If you have TestFlight
- r/[YourNiche] - Find relevant subreddits (e.g., r/photography for image apps)
- HackerNews "Show HN" - If technical audience fits
- **Don't spam!** Share genuinely, respond to feedback

**Week 3: Product Hunt (50-100+ users)**
- Launch on Product Hunt (free)
- Prepare: Screenshot gallery, demo video, clear description
- Engage with comments actively on launch day
- Ask friends to upvote (not required, but helps)

**Week 4: Content & SEO**
- Write blog post: "How I built [app] with SwiftUI and Supabase"
- Post on dev.to, Medium, or personal blog
- Include App Store link naturally
- Share on Twitter/LinkedIn

**Free Tools:**
- App Store Optimization: TheTool (free tier)
- Analytics: App Store Connect (built-in)
- User feedback: TestFlight beta notes
- Support: Free email + GitHub Issues (for bugs)

### 6. App Store Optimization (ASO) Basics

**App Name (30 characters max):**
```
❌ Bad: "BananaUniverse Pro Max"
✅ Good: "BananaUniverse: AI Photos"
```

**Subtitle (30 characters max):**
```
❌ Bad: "The best app ever made"
✅ Good: "Remove objects, add effects"
```

**Keywords (100 characters, comma-separated):**
```
Strategy: Use competitor names + feature names + use cases

Example:
"photo editor,ai,remove object,background,upscale,restore,retouch,enhance,fix,professional"
```

**Description Template:**
```
[Hook - What problem does it solve?]
Transform your photos with AI in seconds!

[Features - Top 5 only]
✨ Remove unwanted objects instantly
🎨 19+ AI-powered effects
📸 Professional photo restoration
⚡ Fast processing (under 30 seconds)
💳 Pay-per-use credits (no subscription!)

[Social Proof - If you have it]
"Best photo editor I've used!" - App Store Review

[How It Works - 3 simple steps]
1. Upload your photo
2. Choose your effect
3. Download your result

[Call to Action]
Download now and get 10 free credits to start!

[Technical Details]
- Works offline for browsing
- Supports all image formats
- Secure processing
- No ads
```

**Screenshots (6-8 total):**
1. Hero shot: Main feature in action
2. Before/After comparison
3. Feature showcase: Grid of effects
4. Easy to use: Simple interface
5. Results: Beautiful output examples
6. Pricing: Show credit packs
7. Social proof: Reviews/ratings (if available)
8. Call-to-action: "Download now"

### 7. Launch Week Plan

**Monday: Submit to App Store**
- Upload build to App Store Connect
- Fill in all metadata
- Submit for review

**Tuesday-Thursday: Wait for Review (usually 24-48 hours)**
- Prepare launch announcement text
- Create screenshots for social media
- Draft Product Hunt post
- Notify friends/family

**Friday: Launch Day (if approved)**
- Post on Product Hunt
- Share on social media (Twitter, LinkedIn, Instagram)
- Post in Reddit communities (max 2-3, no spam)
- Email friends/family with App Store link
- Monitor reviews and respond

**Weekend: Engagement**
- Respond to every review (positive and negative)
- Answer questions on Product Hunt/Reddit
- Track downloads in App Store Connect
- Note: First few bugs users report

**Week 2: Iterate**
- Fix critical bugs (submit update if needed)
- Thank early reviewers
- Analyze which marketing channels worked
- Plan next features based on feedback

### 8. Metrics to Track (Keep It Simple)

**App Store Connect (built-in):**
- Daily downloads
- Daily active users
- Crashes (aim for < 1%)
- Ratings (aim for 4.0+)

**In-App Analytics (minimal):**
- Most used features (which AI tools are popular?)
- Credit purchases (which packs sell best?)
- Where users drop off (find friction points)

**Don't Overcomplicate:**
- Don't track 50 metrics
- Focus on: Downloads, Active Users, Purchases, Ratings
- Review weekly, not daily (avoid obsessing)

## Common Mistakes to Avoid

1. **Perfectionism**: "I'll launch when it's perfect" → Launch at 80% quality, improve based on feedback
2. **Feature Creep**: "Just one more feature..." → Ship what you have, iterate later
3. **Ignoring Reviews**: Not responding to user feedback → Every review is valuable data
4. **No Marketing Plan**: "I'll figure it out after launch" → Plan marketing BEFORE launch
5. **Wrong Pricing**: Too cheap (looks cheap) or too expensive (no downloads) → Research competitors
6. **Bad Screenshots**: Low quality or confusing → This is your first impression!
7. **No Privacy Policy**: App will be rejected → Use a template, host on GitHub Pages (free)
8. **Testing Only on Simulator**: Crashes on real devices → Always test on physical iPhone

## Quick Decision Framework

**When deciding what to do next:**

```
Question: Should I do [task]?

Ask yourself:
1. Does it help users? (Yes/No)
2. Can I do it in < 1 week? (Yes/No)
3. Will it increase downloads or revenue? (Yes/No)

If 2+ answers are YES → Do it
If 0-1 answers are YES → Skip it (for now)
```

## Example Questions to Ask This Helper

```
"Should I add video generation or 10 new themes first?"
"Review my App Store description"
"What features do competitors like PicsArt have?"
"Help me price my IAP credit packs"
"Create a launch week plan for BananaUniverse"
"What metrics should I track?"
"Am I ready to submit to App Store?"
```

---

**This helper focuses on PRACTICAL, ACTIONABLE advice for solo developers launching their first app - no enterprise BS!**
