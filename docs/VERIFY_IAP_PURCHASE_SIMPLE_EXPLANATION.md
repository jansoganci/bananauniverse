# What Does "verify-iap-purchase" Do? (Simple Explanation)

## 🎯 **Main Purpose**

This code **verifies that someone actually paid Apple** for credits, and then **gives them the credits** in your app.

Think of it like a cashier checking your receipt before giving you what you bought.

---

## 📋 **Step-by-Step: What Happens When Someone Buys Credits**

### **Step 1: Check Who You Are** (Lines 24-71)

**What it does:**
- Checks if you're logged in (signed in user) OR using the app without an account (anonymous)
- Gets your user ID or device ID

**Why:**
- So it knows WHO to give credits to

**Simple example:**
- Like asking "Who are you?" before giving you your purchase

---

### **Step 2: Get Purchase Information** (Lines 73-97)

**What it does:**
- Reads the purchase details from your phone
- Gets: transaction ID (receipt number) and product ID (what they bought - like "credits_10")

**Why:**
- Needs to know WHAT was purchased and the RECEIPT NUMBER

**Simple example:**
- Like reading the receipt to see what was bought

---

### **Step 3: Ask Apple "Did This Person Really Pay?"** (Lines 99-150)

**What it does:**
- Calls Apple's servers and asks: "Did this person really pay for this?"
- Apple says "Yes, they paid" or "No, this is fake"

**Why:**
- Prevents fraud - makes sure people can't fake purchases

**Simple example:**
- Like calling the store to verify your receipt is real

**Two ways it can verify:**
- **Method A:** Uses transaction ID (newer way - StoreKit 2)
- **Method B:** Uses JWT token (older way - StoreKit 1)

---

### **Step 4: Check If Already Processed** (Lines 152-175)

**What it does:**
- Checks: "Did we already give credits for this purchase?"
- If yes → Returns the same result (doesn't give credits twice)
- If no → Continues

**Why:**
- Prevents giving credits twice if the app calls this function multiple times

**Simple example:**
- Like checking "Did I already give you this?" before giving it again

---

### **Step 5: Look Up What They Bought** (Lines 177-209)

**What it does:**
- Checks the database: "What is credits_10? How many credits does it give?"
- Finds: Base credits (10) + Bonus credits (0) = Total (10 credits)

**Why:**
- Needs to know HOW MANY credits to give

**Simple example:**
- Like looking at the menu to see what "credits_10" includes

---

### **Step 6: Give Credits** (Lines 211-240)

**What it does:**
- Adds credits to the user's account
- Updates their balance (e.g., 5 credits → 15 credits after buying 10)

**Why:**
- This is the MAIN GOAL - giving them what they paid for!

**Simple example:**
- Like putting money in your account after you paid

---

### **Step 7: Save Purchase Record** (Lines 242-264)

**What it does:**
- Saves the purchase in the database
- Records: who bought, what they bought, when, transaction ID

**Why:**
- For records/accounting - so you can see purchase history

**Simple example:**
- Like keeping a receipt in a filing cabinet

---

### **Step 8: Send Telegram Message** (Lines 266-291) ✅ **YES, IT SENDS TELEGRAM!**

**What it does:**
- Sends a message to YOUR Telegram (if configured)
- Message includes:
  - Who bought (user ID or device ID)
  - What they bought (product name)
  - How much they paid
  - How many credits they got
  - Their new balance

**Why:**
- So YOU get notified when someone buys credits
- Helps you track sales

**Simple example:**
- Like getting a text message every time someone buys something

**⚠️ Important:** 
- Only sends if you set up `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`
- If not set up, it silently skips (doesn't crash)

---

### **Step 9: Return Success** (Lines 293-315)

**What it does:**
- Tells the app: "Everything worked! Credits given!"
- Returns: success message, credits granted, new balance

**Why:**
- So the app knows to show "Purchase successful!" to the user

**Simple example:**
- Like giving a confirmation receipt

---

## 🔧 **Helper Functions (The Workers Behind the Scenes)**

### **Function 1: verifyAppleTransactionById** (Lines 331-417)

**What it does:**
- Takes a transaction ID
- Calls Apple's API to get the full transaction details
- Verifies it's real

**When used:**
- When using StoreKit 2 (newer iOS payment system)

---

### **Function 2: verifyAppleTransaction** (Lines 419-515)

**What it does:**
- Takes a JWT token (like a digital receipt)
- Decodes it and verifies with Apple
- Checks if it's real

**When used:**
- When using StoreKit 1 (older iOS payment system) or direct JWT

---

### **Function 3: sendTelegramPurchaseNotification** (Lines 521-592)

**What it does:**
- Creates a nice formatted message
- Sends it to your Telegram chat
- Includes all purchase details

**Message includes:**
- 👤 User info (who bought)
- 💰 Product details (what they bought, price)
- 🎁 Credits info (base + bonus = total)
- 📊 Account balance (before and after)
- 🔢 Transaction IDs (receipt numbers)
- ⏰ Time of purchase

**Example message:**
```
💰 **NEW PURCHASE!**

👤 User: `69DE3EC6...`

**Package:**
   • Product: `credits_10`
   • Price: **$8.99**
   • Base Credits: 10
   • **Total: 10 credits**

**Account:**
   • Balance After: **20 credits**
   • Credits Used: 10 (before purchase)

**Transaction:**
   • ID: `1234567890...`
   • Original: `0987654321...`
   • Time: Dec 2, 01:15 UTC
```

---

## ✅ **Telegram Notification - YES or NO?**

### **YES, it sends Telegram messages!** ✅

**When:**
- After EVERY successful credit purchase
- Only if Telegram is configured (bot token + chat ID set up)

**What you get:**
- Instant notification on your phone
- All purchase details
- User info
- Transaction numbers

**If not configured:**
- Silently skips (doesn't crash)
- Purchase still works, just no notification

---

## 🎯 **Summary: The Whole Process**

1. **Check identity** → Who is buying?
2. **Get purchase info** → What did they buy?
3. **Verify with Apple** → Did they really pay?
4. **Check duplicates** → Already processed?
5. **Look up product** → How many credits?
6. **Give credits** → Add to account ✅
7. **Save record** → Keep receipt
8. **Send Telegram** → Notify you ✅
9. **Return success** → Tell app it worked

---

## 💡 **Key Points**

- **Main job:** Verify payment → Give credits
- **Telegram:** YES, sends notifications (if configured)
- **Safety:** Checks with Apple to prevent fraud
- **Duplicate protection:** Won't give credits twice
- **Works for:** Both logged-in users and anonymous users

---

## 🚨 **What Can Go Wrong?**

- ❌ Apple says "payment fake" → Credits NOT given
- ❌ Product not found in database → Credits NOT given
- ❌ Already processed → Returns cached result (no duplicate credits)
- ❌ Telegram fails → Purchase still works, just no notification

---

**Bottom line:** This code is like a smart cashier that checks receipts with Apple, gives credits, saves records, and texts you every time someone buys! 🎉

