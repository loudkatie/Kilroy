# Kilroy Codebase Audit — January 25, 2026
## Pre-v1.1 Development Sprint

---

## CURRENT STATE SUMMARY

### ✅ What Works
1. **Firebase Backend** — Firestore + Storage configured at `kilroy-b52c0`
2. **Photo Capture** — Camera → Preview → Drop flow
3. **Cloud Sync** — Kilroys upload to Firebase on drop
4. **Discovery** — Fetches ALL nearby Kilroys (no deviceId filtering)
5. **Haptic Feedback** — Taps when entering a zone with content
6. **Admin Seeding** — Whitelisted deviceIds can plant historical content
7. **Geohash Queries** — Efficient spatial lookups
8. **Build Compiles** — Verified on iPhone 17 Pro simulator

### ❌ What's Missing for v1.1
1. **Height/Altitude** — No floor detection yet
2. **Audio Recording** — No mic capture
3. **Text Notes** — No text-only Kilroys
4. **AI Agent Interface** — No ChatGPT integration
5. **Tighter Geofence** — Currently 50m, need 10-15m default

### 🗑️ Legacy/Unused Code
1. **GooglePhotosService.swift** — Google deprecated the API scope we needed. Keep file but it's inactive.
2. **WhisperService.swift** — Audio whispers planned but not connected to UI yet.

---

## FILE INVENTORY

### /Kilroy/App/
| File | Status | Purpose |
|------|--------|---------|
| KilroyApp.swift | ✅ Active | App entry, Firebase init, service injection |

### /Kilroy/Models/
| File | Status | Purpose |
|------|--------|---------|
| AppState.swift | ✅ Active | Global app state |
| DroppedMemory.swift | ✅ Active | Local Kilroy model (photo only) |
| KilroyMemory.swift | ⚠️ Review | May be duplicate of DroppedMemory |
| PrivacyCircle.swift | ✅ Active | UI component model |

### /Kilroy/Services/
| File | Status | Purpose |
|------|--------|---------|
| AdminConfig.swift | ✅ Active | Admin deviceId whitelist |
| FirebaseService.swift | ✅ Active | Cloud upload/download, CloudKilroy model |
| GooglePhotosService.swift | 🗑️ Legacy | Google deprecated API — keep but inactive |
| HapticsService.swift | ✅ Active | Haptic feedback on Apple Watch/iPhone |
| LocationService.swift | ✅ Active | GPS, geofencing |
| MemoryStore.swift | ✅ Active | Local persistence + Firebase upload |
| PhotosService.swift | ✅ Active | Apple Photos library scanning |
| WhisperService.swift | 💤 Dormant | Audio TTS — not connected to UI yet |

### /Kilroy/Views/
| File | Status | Purpose |
|------|--------|---------|
| AdminSeedView.swift | ✅ Active | Admin tool for planting content |
| CaptureView.swift | ✅ Active | Camera → Preview → Drop flow |
| HomeView.swift | ✅ Active | Main screen, map, discovery |
| MemoriesSheet.swift | ✅ Active | List of memories at location |
| MemoryDetailView.swift | ✅ Active | Single memory view |
| MemoryMapView.swift | ✅ Active | Map component |
| OnboardingView.swift | ✅ Active | First-time user flow |
| SettingsView.swift | ✅ Active | Settings screen |
| SplashView.swift | ✅ Active | Launch screen |

### /Kilroy/Views/Components/
| File | Status | Purpose |
|------|--------|---------|
| CameraView.swift | ✅ Active | AVFoundation camera capture |
| CaptureButton.swift | ✅ Active | Shutter button UI |
| CircleSelector.swift | ✅ Active | UI component |
| MemoryCard.swift | ✅ Active | Memory display card |
| PulseRing.swift | ✅ Active | Animation component |

### /Kilroy/Design/
| File | Status | Purpose |
|------|--------|---------|
| KilroyTheme.swift | ✅ Active | Colors, fonts, spacing tokens |

### /Kilroy/Resources/
| Folder | Status | Purpose |
|--------|--------|---------|
| Assets.xcassets | ✅ Active | App icons, image assets |
| Gfx/ | 📦 Archive | Source graphics files |
| Images/ | ✅ Active | Images referenced by Xcode project |
| Info.plist | ✅ Active | App permissions, config |

---

## DATA MODELS

### CloudKilroy (Firebase)
```swift
struct CloudKilroy {
    let id: String
    let imageURL: String       // Firebase Storage URL
    let latitude: Double
    let longitude: Double
    let geohash: String        // Precision 6
    let placeName: String
    let placeAddress: String?
    let comment: String?
    let createdAt: Date
    let deviceId: String
    let isSeeded: Bool
}
```

### PROPOSED: CloudKilroy v1.1
```swift
struct CloudKilroy {
    let id: String
    let mediaType: MediaType   // NEW: .photo, .audio, .text
    let mediaURL: String       // Firebase Storage URL
    let latitude: Double
    let longitude: Double
    let altitude: Double?      // NEW: Height in meters
    let floor: Int?            // NEW: Estimated floor number
    let geohash: String
    let placeName: String
    let placeAddress: String?
    let placeId: String?       // NEW: Apple Maps place identifier
    let comment: String?
    let createdAt: Date
    let deviceId: String
    let isSeeded: Bool
}

enum MediaType: String, Codable {
    case photo
    case audio
    case text
}
```

---

## FIREBASE STRUCTURE

### Current
```
Firestore: kilroys/{documentId}
Storage: kilroys/{uuid}.jpg
```

### Proposed v1.1
```
Firestore: kilroys/{documentId}
Storage: 
  - kilroys/photos/{uuid}.jpg
  - kilroys/audio/{uuid}.m4a
  - kilroys/text/{uuid}.txt
```

---

## GEOFENCE CONFIGURATION

### Current
- Discovery radius: 50 meters (FirebaseService.swift line 29)
- Geofence radius: 10 meters (DroppedMemory.swift line 24)

### Proposed v1.1
- Discovery radius: 15 meters (tighter "easter egg" feel)
- Geofence radius: 10 meters (keep)
- Height tolerance: ±4 meters (~1 floor)

---

## BUILD CONFIGURATION

- **Bundle ID**: com.loudlabs.Kilroy
- **iOS Target**: 17.0+
- **Firebase Project**: kilroy-b52c0
- **TestFlight**: Build 1.0.0 (1) deployed

---

## V1.1 DEVELOPMENT PLAN

### Phase 1: Data Model Updates
1. Add `altitude`, `floor`, `mediaType`, `placeId` to CloudKilroy
2. Update Firestore schema
3. Backward compatibility for existing photo-only Kilroys

### Phase 2: Height/Floor Detection
1. Capture `CLLocation.altitude` on drop
2. Calculate floor from altitude (configurable floor height)
3. Filter discovery by altitude tolerance

### Phase 3: Audio Recording
1. Add AudioRecordingService
2. New capture flow for audio
3. Upload .m4a to Firebase Storage

### Phase 4: Text Notes
1. Text-only Kilroy creation UI
2. Upload text content to Firebase

### Phase 5: AI Agent Interface
1. Add OpenAI API integration
2. Persistent conversation thread per user
3. Proactive AI that "taps" you when content is nearby
4. Chat interface as primary navigation

### Phase 6: Tighten Geofence
1. Reduce discovery radius to 15m
2. Test at Frontier Tower

---

## CLEANUP TASKS

1. [x] Move misc files to Kilroy-Misc (done, gitignored)
2. [x] Restore Images folder for Xcode refs (done)
3. [ ] Archive GooglePhotosService.swift (keep but mark deprecated)
4. [ ] Remove duplicate image files in Gfx/ vs Images/
5. [ ] Update HANDOFF_CONTEXT.md with current state

---

*Audit completed: January 25, 2026*
