# SafeHer — Complete Setup & Changes Guide

## What Was Changed and Fixed

### 1. CHATBOT — Connection Issue Fixed ✅
**Problem:** "Connection issue" error showing for 2+ days
**Root Cause:** Stale Gemini chat session objects were reused across requests, causing them to become invalid
**Fix in `backend/services/enhanced_ai_service.py`:**
- Start a **fresh chat session** for every API call (no more stale sessions)
- Added exponential backoff retry (waits 1.5s → 3s → 6s before failing)
- Added robust offline fallback engine (works even without API)
- Added offline safety responses in Flutter chat page too

### 2. CHATBOT — Real-Time Safety Analysis ✅
The chatbot now:
- Extracts place names from user messages
- Queries OpenStreetMap via Overpass API for LIVE police stations and hospitals
- Provides time-specific advice (2 PM vs 10 PM vs 2 AM are different responses)
- Uses actual Tamil Nadu safety knowledge (15+ cities with detailed data)
- Handles "is it safe at 2 AM" with real current-time awareness

### 3. SOS — Twilio SMS Added ✅
**File:** `backend/services/notification_service.py`
- Full Twilio SMS integration for emergency alerts
- WhatsApp deep links for contacts (existing feature — maintained)
- SendGrid email alerts for emergency contacts
- Simulation mode when credentials not configured (for local development)

### 4. LOGO — Added to Login, Signup, Home, Splash ✅
- Logo placed in: `mobile/assets/images/safeher_logo.jpg`
- Shows on: Login page, Signup page, Dashboard header, Chat header, Splash screen
- Gracefully falls back to a shield icon if image fails to load

### 5. UI/UX — Complete Pink/Lavender Redesign ✅
**Color Palette:**
- Primary Pink: `#E91E8C`
- Accent Purple: `#9C27B0`
- Background: `#FFF0F8` (soft pink-white)
- Text: `#2D1B35` (dark plum)

**Pages Redesigned:**
- `login_page.dart` — Gradient background, card layout, pink fields
- `signup_page.dart` — Organized cards, gradient button, logo
- `dashboard_page.dart` — Custom sliver app bar, pink stats, SOS banner
- `chat_page.dart` — Pink AI bubble, gradient send button, suggestion chips
- `main.dart` — Full splash screen with logo, pink theme, styled nav bar

---

## Files Changed (Copy These)

```
mobile/lib/main.dart                              ← Splash + pink theme + nav
mobile/lib/pages/login_page.dart                 ← New pink/lavender login
mobile/lib/pages/signup_page.dart                ← New signup with logo
mobile/lib/pages/dashboard_page.dart             ← New dashboard
mobile/lib/pages/chat_page.dart                  ← Fixed chatbot + pink UI
mobile/assets/images/safeher_logo.jpg            ← YOUR LOGO (copy manually)
mobile/pubspec.yaml                              ← Added safeher_logo.jpg asset
backend/services/enhanced_ai_service.py          ← Fixed connection issue
backend/services/notification_service.py         ← Twilio SMS added
backend/.env.example                             ← All API key templates
```

---

## How to Set Up API Keys

### A. Gemini API Key (for Chatbot)
1. Go to: https://aistudio.google.com/app/apikey
2. Sign in with Google
3. Click **"Create API Key"**
4. Copy the key
5. Add to `backend/.env`: `GEMINI_API_KEY=AIzaSy...`

### B. Twilio API Keys (for SOS SMS)
1. Go to: https://www.twilio.com/try-twilio
2. Sign up (free trial = ~$15 credit)
3. Verify your phone number
4. Go to Console Dashboard: https://console.twilio.com
5. Copy **Account SID** and **Auth Token**
6. Buy a phone number: Console → Phone Numbers → Buy a Number
7. Add to `backend/.env`:
   ```
   TWILIO_ACCOUNT_SID=AC...
   TWILIO_AUTH_TOKEN=...
   TWILIO_PHONE_NUMBER=+1...
   ```

**Note for India SMS:** Twilio trial only sends to verified numbers.
For production India SMS, complete DLT registration at https://www.trai.gov.in/dlt

### C. Google Places API (for map features)
1. Go to: https://console.cloud.google.com
2. Create/select a project
3. Enable "Places API" and "Maps SDK for Android"
4. Create API credentials
5. Add: `GOOGLE_PLACES_API_KEY=AIza...`

---

## How to Run

### Backend
```bash
cd backend
cp .env.example .env
# Fill in your API keys in .env
pip install -r requirements.txt
python app.py
```

### Flutter App
```bash
cd mobile
flutter pub get
# Copy your safeher_logo.jpg to mobile/assets/images/
flutter run
```

---

## Testing the Chatbot Fix

Try asking the chatbot:
- "Hey, is it safe to visit Marina Beach at 2 AM?"
- "Nearest police station to me now"
- "I'm going alone to T Nagar tonight"
- "Is Mylapore safe for solo travel?"

The bot will:
1. Detect the place (Marina Beach, T Nagar, Mylapore...)
2. Check current time (2 AM = late night warning!)
3. Query nearby police/hospitals via OpenStreetMap
4. Give specific, real advice with phone numbers

---

## Features Summary

| Feature | Status |
|---------|--------|
| User Login/Signup | ✅ Working |
| JWT Authentication | ✅ Working |
| AI Chatbot (Gemini) | ✅ Fixed |
| Offline Chatbot Fallback | ✅ Added |
| Real-time location context | ✅ Working |
| SOS via WhatsApp | ✅ Working |
| SOS via SMS (Twilio) | ✅ Added |
| Nearest Police/Hospitals | ✅ Working |
| Map Page | ✅ Working |
| Community Posts | ✅ Working |
| Hotel Listings | ✅ Working |
| Pink/Lavender UI | ✅ Complete redesign |
| Logo Integration | ✅ All pages |
| Splash Screen | ✅ New animated splash |
