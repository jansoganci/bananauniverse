---
name: developer-growth-simple
description: Analyzes your recent Claude Code chat history to identify coding patterns, development gaps, and areas for improvement. Creates a personalized growth report WITHOUT requiring Rube MCP or Slack integration.
---

# Developer Growth Analysis (Simple Version)

This skill provides personalized feedback on your recent coding work by analyzing your Claude Code chat interactions - **NO external tools required!**

## When to Use This Skill

Use this skill when you want to:
- Understand your development patterns from recent work
- Identify specific technical gaps or challenges
- Discover which topics would benefit from deeper study
- Get personalized recommendations based on actual work patterns
- Track improvement areas across your projects

Perfect for solo developers who want structured feedback without code reviews.

## What This Skill Does

This skill performs a four-step analysis:

1. **Reads Your Chat History**: Accesses your local Claude Code chat history from the past 24-48 hours
2. **Identifies Patterns**: Analyzes problems you're solving, technologies used, and challenges encountered
3. **Detects Improvement Areas**: Recognizes skill gaps, repeated struggles, and growth opportunities
4. **Generates Report**: Creates a comprehensive report with actionable recommendations

## How to Use

Simply ask Claude to analyze your recent work:

```
Analyze my developer growth from my recent chats
```

Or be specific about the time period:

```
Analyze my work from this week and suggest areas for improvement
```

## Instructions

When a user requests analysis of their developer growth:

### Step 1: Access Chat History

Read the chat history from `~/.claude/history.jsonl`. This file contains:
- `display`: The user's message/request
- `project`: The project being worked on
- `timestamp`: Unix timestamp (in milliseconds)
- `pastedContents`: Code or content pasted

Filter for entries from the past 24-48 hours based on current timestamp.

### Step 2: Analyze Work Patterns

Extract and analyze from filtered chats:

**Projects and Domains**
- What types of projects? (backend, frontend, iOS, database, etc.)
- What was the main focus?

**Technologies Used**
- Languages: Swift, TypeScript, SQL, etc.
- Frameworks: SwiftUI, Supabase, etc.
- Tools: Xcode, git, migrations, etc.

**Problem Types**
- Performance optimization
- Debugging and bug fixes
- Feature implementation
- Refactoring
- Setup/configuration
- Architecture decisions

**Challenges Encountered**
Look for:
- Repeated questions about similar topics
- Problems that took multiple attempts
- Questions indicating knowledge gaps
- Complex decisions that required guidance

**Approach Patterns**
How does the user solve problems?
- Methodical vs exploratory
- Asks for explanation vs jumps to solution
- Tests incrementally vs big changes

### Step 3: Identify Improvement Areas

Based on analysis, identify **3-5 specific areas** for improvement:

**Requirements:**
- **Specific** (not vague like "improve coding skills")
- **Evidence-based** (grounded in actual chat history)
- **Actionable** (practical improvements that can be made)
- **Prioritized** (most impactful first)

**Good Examples:**
- "Advanced Swift Concurrency (@MainActor, async/await, Task) - you struggled with threading issues in CreditManager"
- "SwiftUI state management - @Published properties not updating UI in 3 different views"
- "PostgreSQL migration patterns - created 10+ migrations with some conflicts"
- "Supabase Edge Function error handling - missing try-catch blocks in submit-job"
- "iOS MVVM architecture - putting too much logic in Views instead of ViewModels"

### Step 4: Generate Report

Create a comprehensive report with this structure:

```markdown
# Your Developer Growth Report 📊

**Report Period**: [Date Range]
**Generated**: [Current Date and Time]
**Project**: BananaUniverse (iOS + Supabase)

---

## 📝 Work Summary

[2-3 paragraphs summarizing:]
- What you worked on (features, bugs, refactoring)
- Projects touched and technologies used
- Overall focus areas and accomplishments
- Challenges overcome

**Example:**
"Over the past 48 hours, you focused on iOS development and Supabase backend work for BananaUniverse. You worked extensively with SwiftUI views, credit system refactoring, and database migrations. Your work involved debugging state management issues, optimizing Edge Functions, and preparing for an App Store update. You showed strong problem-solving skills while tackling both frontend and backend challenges."

---

## 🎯 Improvement Areas (Prioritized)

### 1. [Area Name]

**Why This Matters**
[Explanation of why this skill is important for your projects]

**What I Observed**
[Specific evidence from chat history - be concrete!]
- Example: "Asked about @MainActor 4 times"
- Example: "Rewrote database query 3 different ways"
- Example: "UI state not updating - took 6 messages to debug"

**How to Improve**
[Concrete steps to improve]
1. [Specific action item]
2. [Study resource or practice task]
3. [Application to current project]

**Time Investment**: [Realistic estimate: e.g., "4-6 hours" or "1-2 weeks of practice"]

**Priority**: 🔴 High | 🟡 Medium | 🟢 Low

---

### 2. [Next Area]

[Same structure as above]

---

### 3. [Next Area]

[Same structure as above]

---

[Continue for 3-5 total improvement areas]

---

## ✨ Strengths Observed

[List 3-5 things you're doing WELL - important for morale!]

- ✅ [Strength 1 with specific example]
- ✅ [Strength 2 with specific example]
- ✅ [Strength 3 with specific example]

---

## 📋 Action Items (Next 7 Days)

**Week 1 Focus**: [Main area to tackle first]

**Priority Tasks:**
1. 🔴 [Highest priority action from improvement area 1]
2. 🟡 [Medium priority action from improvement area 2]
3. 🟢 [Lower priority action from improvement area 3]

**Learning Goals:**
- [ ] [Specific learning objective 1]
- [ ] [Specific learning objective 2]
- [ ] [Specific learning objective 3]

**Practice Tasks:**
- [ ] Apply [skill] to [specific part of your project]
- [ ] Refactor [component] using [new pattern]
- [ ] Create [small practice project] to master [skill]

---

## 📚 Learning Resources (Suggested Topics)

Since this version doesn't auto-search HackerNews, here are **search queries** you can use:

### For [Improvement Area 1]:
**Recommended searches:**
- "Swift Concurrency best practices" (search on HackerNews, Swift Forums, or Apple Docs)
- "@MainActor SwiftUI patterns"
- "async await debugging Swift"

**Official Docs:**
- Apple Developer Documentation: [specific section]
- WWDC Sessions: [relevant session numbers]

### For [Improvement Area 2]:
**Recommended searches:**
- [Relevant search query 1]
- [Relevant search query 2]

**Official Docs:**
- [Relevant documentation links]

---

## 📊 Progress Tracking

**How to measure improvement:**
- [ ] Can implement [skill] without asking for help
- [ ] Debugging time reduced for [problem type]
- [ ] Code reviews show fewer issues in [area]
- [ ] Confident explaining [concept] to others

**Next Review**: Run this analysis again in 7 days to track progress

---

## 💡 Tips

- **Focus on ONE area at a time** - don't try to fix everything at once
- **Practice daily** - even 30 minutes makes a difference
- **Apply to real work** - use BananaUniverse as your practice ground
- **Track progress** - keep a dev journal of what you learn
- **Celebrate wins** - acknowledge improvements, even small ones

---

*This report is based on your actual work patterns from Claude Code chat history. The recommendations are personalized to YOUR specific challenges and projects.*
```

---

## Example Output

Here's what you'll see:

```markdown
# Your Developer Growth Report 📊

**Report Period**: Nov 20-22, 2025
**Generated**: Nov 22, 2025, 3:45 PM
**Project**: BananaUniverse (iOS + Supabase)

## 📝 Work Summary

Over the past 48 hours, you focused primarily on understanding your project architecture and cleaning up agent definitions. You worked with file organization, asked questions about chaos engineering and developer growth analysis, and showed curiosity about your development tools. Your approach is methodical - you ask detailed questions to understand concepts before implementing them.

## 🎯 Improvement Areas (Prioritized)

### 1. iOS Architecture Understanding (MVVM, Services, State Management)

**Why This Matters**
BananaUniverse uses MVVM architecture with @MainActor services and @Published state. Understanding this pattern is crucial for adding features without introducing bugs.

**What I Observed**
- You're still getting familiar with how CreditManager, SupabaseService, and ViewModels interact
- Questions about agent orchestration suggest you're learning the codebase structure
- This is normal - you're a self-described newbie learning a complex project

**How to Improve**
1. Read these reference files: `CreditManager.swift`, `DesignTokens.swift`
2. Study MVVM pattern specifically for SwiftUI
3. Create a simple test feature (like a "Hello World" button) following exact MVVM pattern
4. Trace one feature end-to-end: View → ViewModel → Service → Backend

**Time Investment**: 8-12 hours (spread over 1-2 weeks)

**Priority**: 🔴 High

---

### 2. Swift Concurrency Basics (@MainActor, async/await, Task)

**Why This Matters**
Your project heavily uses @MainActor and async/await. Without understanding these, you'll hit threading crashes.

**What I Observed**
- CLAUDE.md emphasizes @MainActor everywhere - you'll need to know why
- Credit system uses async calls that must run on main thread
- This is a common stumbling block for new Swift developers

**How to Improve**
1. Read Apple's "Meet async/await in Swift" (WWDC 2021)
2. Understand difference between @MainActor and Task
3. Practice: Create a simple async function and call it from SwiftUI
4. Study why CreditManager is marked @MainActor

**Time Investment**: 6-8 hours

**Priority**: 🔴 High

---

## ✨ Strengths Observed

- ✅ **Asks great questions** - You don't just accept answers, you dig deeper ("what is chaos engineering?")
- ✅ **Organized approach** - You're cleaning up files and understanding structure before coding
- ✅ **Curious mindset** - You want to understand WHY, not just HOW
- ✅ **Self-aware** - You identify as a newbie, which means you'll learn faster

---

## 📋 Action Items (Next 7 Days)

**Week 1 Focus**: Master MVVM pattern in SwiftUI

**Priority Tasks:**
1. 🔴 Read `CreditManager.swift` line by line - understand every @Published property
2. 🟡 Study Apple's SwiftUI State Management documentation
3. 🟢 Create a simple "Practice View" with ViewModel to test understanding

**Learning Goals:**
- [ ] Understand @StateObject vs @ObservedObject vs @Published
- [ ] Know when to use @MainActor and why
- [ ] Can create a basic View + ViewModel without help

**Practice Tasks:**
- [ ] Add a simple debug button to BananaUniverse that shows current credits
- [ ] Create a new ViewModel for a feature (even if you don't implement the feature yet)
- [ ] Read through one existing ViewModel and explain to yourself what each property does

---

## 📚 Learning Resources (Suggested Topics)

### For: MVVM in SwiftUI
**Recommended searches:**
- "SwiftUI MVVM architecture best practices" (YouTube, HackerNews)
- "ObservableObject StateObject difference"
- "SwiftUI state management patterns"

**Official Docs:**
- Apple Developer: "Managing Model Data in Your App"
- WWDC 2020: "Data Essentials in SwiftUI"

### For: Swift Concurrency
**Recommended searches:**
- "Swift async await tutorial for beginners"
- "@MainActor explained"
- "Swift concurrency crash course"

**Official Docs:**
- Swift.org: "Concurrency" documentation
- WWDC 2021: "Meet async/await in Swift"

---

## 📊 Progress Tracking

**How to measure improvement:**
- [ ] Can create a new View + ViewModel without help
- [ ] Understand why @MainActor is needed
- [ ] Can explain to someone else how CreditManager works
- [ ] Feel confident reading existing ViewModels

**Next Review**: Run this analysis again in 7 days

---

## 💡 Tips

- Start with READING existing code before writing new code
- Use Xcode's "Jump to Definition" constantly
- Build mental models: "View talks to ViewModel talks to Service"
- Don't try to understand everything at once - pick ONE service to master first

*Report based on chat history analysis*
```

---

## How This Version Works

### What Changed from Original:

| Feature | Original Version | Simple Version |
|---------|-----------------|----------------|
| Read chat history | ✅ Yes | ✅ Yes |
| Analyze patterns | ✅ Yes | ✅ Yes |
| Generate report | ✅ Yes | ✅ Yes |
| Auto-search HackerNews | ❌ Needs Rube MCP | ✅ Gives you search queries instead |
| Send to Slack | ❌ Needs Rube MCP | ✅ Just shows in terminal (copy/paste) |
| External dependencies | ❌ Requires setup | ✅ **NONE!** Works immediately |

---

## How to Use It

### Option 1: Use the Simple Version (Recommended for You)

Just ask Claude:
```
Use the developer-growth-simple skill to analyze my recent work
```

Or even simpler:
```
Analyze my coding patterns from this week
```

### Option 2: Manual Request (No skill file needed)

Just ask directly:
```
Read my Claude Code chat history and tell me:
- What I've been working on
- What patterns you notice
- Top 3 skills I should focus on
- How to improve in those areas
```

---

## My Recommendation

**Use the SIMPLE version I just created** because:

✅ Works RIGHT NOW with just Claude Code
✅ No Rube MCP setup needed
✅ No Slack integration needed
✅ You can copy/paste the report anywhere (Notes app, Notion, etc.)
✅ Gives you search queries to find resources yourself
✅ Perfect for solo developers learning

You can always upgrade to the full version later if you want automated HackerNews search and Slack integration!

---

Want me to **run the analysis RIGHT NOW** and show you what your personalized report looks like? 😊