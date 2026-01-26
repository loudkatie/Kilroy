# KILROY & CONTEXTUAL — COMPLETE CTO HANDOFF
## For Claude Instance Continuity
## Last Updated: January 25, 2026, 9:30 PM PST

---

# CRITICAL: READ THIS ENTIRE FILE BEFORE RESPONDING

You are the technical cofounder and CTO of Loud Labs. Katie is CEO. This is a partnership, not a client relationship. You make engineering decisions autonomously, push back on bad ideas, and champion simplicity.

---

# PART 1: THE VISION

## What We're Building

### Contextual (The Platform)
A spatial intelligence platform where your personal AI agent navigates the world FOR you:

1. **User creates account** → An AI "twin" is born
2. **AI learns everything** about the user over time (preferences, behavior, permissions)
3. **AI runs in background** constantly scanning user's location for relevant content
4. **Haptic tap** notifies user when they enter a geofenced zone with content they qualify for
5. **User opens app** → sees AI chat explaining what's here
6. **Content revealed** inline in the chat thread

The AI is PROACTIVE. It works while you're NOT looking at your screen. The value prop:

> "Tell me what I want/love/need/qualify for right here, right now."

### Kilroy (The First Product)
An iOS app for dropping geotagged media (photos, audio, text) at precise locations. Others discover these "hidden layers" when physically at the same spot.

Think: **secret club of easter eggs layered on the real world**.

### B2B Vision
Brands/orgs license Contextual to reach qualified users:
- Walgreens taps you in the parking lot with a coupon
- United taps Platinum members at the gate with a Starbucks code  
- Heavenly Resort taps skiers about restaurant deals
- National Parks alert visitors about wildfire emergencies

---

# PART 2: CURRENT STATE (January 25, 2026)

## Repository
- **Path**: `/Users/katiemacair-2025/04_Developer/Kilroy/`
- **GitHub**: https://github.com/loudkatie/Kilroy.git
- **Bundle ID**: `com.loudlabs.Kilroy`

## Firebase
- **Project ID**: kilroy-b52c0
- **Console**: https://console.firebase.google.com/project/kilroy-b52c0
- **Firestore**: Enabled (nam5, US)
- **Storage**: gs://kilroy-b52c0.firebasestorage.app
- **Plan**: Blaze (pay-as-you-go, but staying in free tier)

## Version
- **Current**: v1.1 in development
- **TestFlight**: Build 1.0.0 (1) — outdated, needs new build

## What Works
- Firebase backend (upload/download Kilroys)
- Photo capture and drop
- Discovery of nearby Kilroys (all users see all content)
- Haptic feedback on zone entry
- Admin seeding for pre-populating content

## What's New in v1.1 (Just Built)
- Multi-media support: photos, audio, text
- Altitude/floor detection for multi-story buildings
- Tighter geofence: 15m radius
- AI Agent foundation (AIAgentService.swift)
- Audio recording service (AudioRecordingService.swift)
- Memory fix: Photo indexing limited to 500 recent photos

---

# PART 3: THE UI VISION (NEXT TO BUILD)

## CRITICAL: Katie hates the current map-based UI

The new design:
- **NO MAP** — kill it entirely
- **Chat thread interface** — feels exactly like iMessage
- **One persistent conversation** with your AI guide
- **Inline media** — photos/audio appear in the chat
- **Minimal chrome** — just settings gear

### The Flow
```
1. AMBIENT: AI says "I'm watching for hidden memories..."
2. DISCOVERY: Haptic tap → User opens app → AI says "Found something!"
3. REVEAL: User taps "Yes" → Content appears inline in thread
4. ENGAGE: User taps content for full-screen view
5. RECIPROCATE: AI asks "Want to leave something here too?"
6. CREATE: User taps "Drop Here" → Camera/audio/text picker
```

### UI Mockup
```
┌─────────────────────────────────────────┐
│  ○ Kilroy                          ⚙️   │
├─────────────────────────────────────────┤
│                                         │
│  [AI bubble: "Found something!          │
│   Someone left a memory here            │
│   3 months ago. Want to see it?"]       │
│                                         │
│      [Yes]          [Not now]           │
│                                         │
│  [Inline photo with caption]            │
│                                         │
│  [AI bubble: "Want to leave             │
│   something here too?"]                 │
│                                         │
├─────────────────────────────────────────┤
│  [Message input...]              📷     │
│           [📍 Drop Here]                │
└─────────────────────────────────────────┘
```

---

# PART 4: FILE INVENTORY

## Active Files

### /Kilroy/App/
- `KilroyApp.swift` — App entry, Firebase init, service injection

### /Kilroy/Services/
- `FirebaseService.swift` — Cloud sync, CloudKilroy model (v1.1 updated)
- `LocationService.swift` — GPS, altitude, floor estimation (v1.1 updated)
- `AIAgentService.swift` — Proactive AI assistant (NEW v1.1)
- `AudioRecordingService.swift` — Mic capture (NEW v1.1)
- `MemoryStore.swift` — Local persistence
- `PhotosService.swift` — Apple Photos integration (memory fix applied)
- `HapticsService.swift` — Haptic feedback
- `AdminConfig.swift` — Admin whitelist
- `WhisperService.swift` — TTS (dormant, not connected)

### /Kilroy/Views/
- `HomeView.swift` — Current main view (TO BE REPLACED with AgentChatView)
- `CaptureView.swift` — Camera capture flow
- `AdminSeedView.swift` — Admin seeding tool
- `OnboardingView.swift` — First-time flow
- `MemoriesSheet.swift`, `MemoryDetailView.swift`, `SettingsView.swift`, `SplashView.swift`

### /Kilroy/Views/Components/
- `CameraView.swift`, `CaptureButton.swift`, `CircleSelector.swift`, `MemoryCard.swift`, `PulseRing.swift`

### Legacy (Don't Use)
- `GooglePhotosService.swift` — Google deprecated the API

---

# PART 5: DATA MODEL

## CloudKilroy (v1.1)
```swift
struct CloudKilroy: Identifiable, Hashable, Codable {
    let id: String
    let mediaType: KilroyMediaType  // .photo, .audio, .text
    let mediaURL: String            // Firebase Storage URL
    let textContent: String?        // For text-only Kilroys
    let latitude: Double
    let longitude: Double
    let altitude: Double?           // Height in meters (altimeter)
    let floor: Int?                 // Estimated floor number
    let geohash: String             // Precision 8 (room-level)
    let placeName: String
    let placeAddress: String?
    let placeId: String?            // Apple Maps identifier
    let comment: String?            // Caption/description
    let createdAt: Date
    let deviceId: String
    let isSeeded: Bool
}

enum KilroyMediaType: String, Codable {
    case photo
    case audio
    case text
}
```

## Firebase Storage Structure
```
kilroys/
  photos/{uuid}.jpg
  audio/{uuid}.m4a
```

## Geohash Explained
Encodes lat/long to string. Nearby locations share prefixes.
- Precision 8 = ~40m × 20m cells (room-level)
- Discovery radius: 15m (can go tighter: 10m)
- Altitude tolerance: ±3-4m (one floor)

---

# PART 6: KNOWN ISSUES & FIXES

## Memory Crash (FIXED)
**Symptom**: App killed by OS for using too much memory
**Cause**: PhotosService was indexing entire photo library (1,690+ photos)
**Fix**: Added `fetchLimit = 500` to only index recent photos

## GPS Drift
**Issue**: GPS is ±5-10m accurate, worse indoors
**Mitigation**: Use geohash precision 8 + 10-15m discovery radius

## Altitude Calibration
**Issue**: Floor calculation assumes ground = 0m altitude
**Solution**: Katie will calibrate at Frontier Tower this week

---

# PART 7: IMMEDIATE NEXT STEPS

## 1. Build AgentChatView (Priority #1)
Replace HomeView with chat-based interface:
- No map
- AI conversation thread
- Inline media reveal
- "Drop Here" button

## 2. Wire Up Services
- Connect AIAgentService to new view
- Trigger notifyDiscovery() when location changes
- Handle Yes/No responses

## 3. Add Media Capture Options
- Photo (existing CameraView)
- Audio (AudioRecordingService ready)
- Text (simple text input)

## 4. Test at Frontier Tower (Jan 9)
- Calibrate altitude
- Seed content on multiple floors
- Verify floor detection
- New TestFlight build

---

# PART 8: DESIGN PRINCIPLES

1. **Dead simple** — One screen, one conversation
2. **Proactive AI** — It works for you, not the other way around
3. **Screens DOWN** — Get people back to real life
4. **Easter eggs** — Tight geofences, hidden layers of meaning
5. **No social clutter** — No comments, no likes, no engagement metrics

---

# PART 9: SESSION STARTUP CHECKLIST

When starting a new Claude session:

1. ✅ Read this file completely
2. ✅ Run `cd /Users/katiemacair-2025/04_Developer/Kilroy && git status`
3. ✅ Run `git log --oneline -5` to see recent commits
4. ✅ Check `CODEBASE_AUDIT.md` for file inventory
5. ✅ Verify build: `xcodebuild -project Kilroy.xcodeproj -scheme Kilroy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|BUILD)"`

---

# PART 10: KATIE'S PREFERENCES

- **Direct communication** — No fluff, short responses
- **Autonomous decisions** — Don't ask permission for technical choices
- **Push back** — If something won't work, say so
- **Screenshots** — She prefers them for UI issues
- **GitHub always updated** — Commit and push before session ends

---

# CONTACT & RESOURCES

- **GitHub**: https://github.com/loudkatie/Kilroy
- **Firebase**: https://console.firebase.google.com/project/kilroy-b52c0
- **Loud Labs**: https://loudlabs.xyz

---

*This document is the source of truth for Kilroy development continuity.*
