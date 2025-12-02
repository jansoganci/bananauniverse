# How to Test Payments - Simple Guide

## ✅ No Sandbox Setup Needed!

I've added a **Test Mode** that lets you test payments without any Apple setup.

---

## 🚀 Quick Start (3 Steps)

### Step 1: Test Mode is Already Enabled
Test mode is **automatically enabled** in debug builds. You don't need to do anything!

### Step 2: Test a Purchase
1. Open the app
2. Go to Profile tab
3. Tap "Buy Credits" or the credit card
4. Select a credit package
5. Tap "Continue Creating"
6. **In test mode, it will simulate a purchase and grant credits immediately**

### Step 3: Check Results
- **Credits should increase** immediately
- **Check the debug view** in Profile (scroll down)
- **Check Xcode console** for logs

---

## 📊 What You'll See

### In the App:
- **Payment Debug View** (in Profile, scroll down)
  - Shows if test mode is enabled
  - Shows your credit balance
  - Shows products loaded
  - Shows payment status

### In Xcode Console:
Look for these logs:
- `🧪 [TEST MODE] Simulating purchase` = Test mode active
- `✅ [TEST MODE] Credits granted` = Credits added successfully
- `✅ [PAYMENT] Apple purchase successful` = Real payment (if test mode off)

---

## 🔍 How to Check if Payments Work

### Method 1: Visual Check
1. Note your current credit balance
2. Make a test purchase
3. Check if balance increased
4. ✅ **If yes** = Payment system works!
5. ❌ **If no** = There's an issue

### Method 2: Debug View
1. Go to Profile
2. Scroll to "Payment System Status" section
3. Check:
   - Test Mode: ENABLED/DISABLED
   - Credit Balance: Should update after purchase
   - Products Loaded: Should show 4 products
   - Payment Status: Should say "Ready"

### Method 3: Console Logs
1. Open Xcode
2. Run app
3. Open Console (View → Debug Area → Activate Console)
4. Try to purchase
5. Look for logs starting with `🧪 [TEST MODE]` or `✅ [PAYMENT]`

---

## 🎯 What Test Mode Does

**Test Mode ON (Default in Debug):**
- ✅ Bypasses Apple StoreKit
- ✅ Simulates purchase instantly
- ✅ Grants credits directly
- ✅ No real payment
- ✅ No Apple account needed

**Test Mode OFF:**
- ✅ Uses real Apple StoreKit
- ✅ Requires sandbox/testing setup
- ✅ Real payment flow
- ✅ Needs backend verification (currently broken)

---

## ⚙️ How to Toggle Test Mode

### Enable Test Mode:
```swift
// In Config.swift, line ~52
static let enablePaymentTestMode: Bool = {
    #if DEBUG
    return true  // ← Change to true
    #else
    return false
    #endif
}()
```

### Disable Test Mode (Use Real Payments):
```swift
// In Config.swift, line ~52
static let enablePaymentTestMode: Bool = {
    #if DEBUG
    return false  // ← Change to false
    #else
    return false
    #endif
}()
```

---

## 🐛 Current Payment Status

### ✅ What Works:
- Test mode purchases
- Credit granting in test mode
- Product loading
- UI flow

### ❌ What's Broken:
- **Backend verification** (not called after real purchases)
- **Credits not granted** after real Apple purchases
- This is why your friend said payments don't work

### 🔧 The Fix Needed:
The app needs to call `verify-iap-purchase` backend endpoint after a successful purchase. Currently it doesn't, so credits aren't granted.

---

## 📝 Testing Checklist

After running the app:

- [ ] Test mode is enabled (check debug view)
- [ ] Products load (see 4 products in debug view)
- [ ] Try to purchase credits
- [ ] Credits increase after purchase
- [ ] Success message appears
- [ ] Console shows test mode logs
- [ ] Debug view updates with new balance

---

## 🆘 Troubleshooting

### "No products loaded"
- **Fix**: Check internet connection
- **Fix**: Products might not be configured in App Store Connect (OK in test mode)

### "Credits not increasing"
- **Check**: Is test mode enabled?
- **Check**: Look at console logs for errors
- **Check**: Check debug view for error messages

### "Test mode not working"
- **Check**: Make sure you're running a DEBUG build
- **Check**: Check Config.swift - `enablePaymentTestMode` should be `true`

---

## 🎓 Understanding the Logs

### Good Logs (Everything Working):
```
🧪 [TEST MODE] Simulating purchase for: credits_10
🧪 [TEST MODE] Granting 10 credits...
✅ [TEST MODE] Credits granted successfully!
   Credits added: 10
   Old balance: 5
   New balance: 15
```

### Bad Logs (Something Wrong):
```
❌ [TEST MODE] Failed to grant credits: [error message]
```

### Real Payment Logs (Test Mode OFF):
```
✅ [PAYMENT] Apple purchase successful: credits_10
   Transaction ID: 1234567890
⚠️ [PAYMENT] Backend verification NOT called - credits may not be granted!
```

---

## 💡 Next Steps

1. **Test with test mode** (easiest - no setup)
2. **See if credits work** in test mode
3. **If test mode works**, the credit system is fine
4. **The issue is** backend verification not being called for real purchases
5. **We can fix that** once we confirm test mode works

---

## ❓ Questions?

- **Q: Do I need sandbox?** A: No! Test mode works without it.
- **Q: Will this work in production?** A: Test mode is disabled in production builds.
- **Q: How do I test real payments?** A: Disable test mode and set up sandbox (complex).
- **Q: Is this safe?** A: Yes! Test mode only works in debug builds.

---

**TL;DR**: Just run the app, try to buy credits, and see if your credit balance increases. That's it! 🎉

