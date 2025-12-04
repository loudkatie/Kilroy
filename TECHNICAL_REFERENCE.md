# Kilroy Technical Reference
## Code Patterns, Architecture Decisions, and Implementation Details

---

## ARCHITECTURE OVERVIEW

### Data Flow
```
User drops Kilroy
    ↓
CaptureView (UI) → MemoryStore.saveMemory()
    ↓
├── Local: Save to Documents/memories.json + MemoryImages/
└── Cloud: FirebaseService.uploadKilroy() → Firestore + Storage

User approaches location
    ↓
LocationService detects location change
    ↓
HomeView.checkForNearbyMemories()
    ↓
├── Local: MemoryStore.memoriesNear()
├── Photos: PhotosService (Apple Photos with location)
└── Cloud: FirebaseService.fetchKilroysNear()
    ↓
Merge results → Display on map + trigger haptic
```

### State Management
- `@StateObject` for service singletons in KilroyApp
- `@EnvironmentObject` passed down to views
- Services are `ObservableObject` with `@Published` properties
- No external state management library (pure SwiftUI)

---

## KEY MODELS

### DroppedMemory (Local)
```swift
struct DroppedMemory: Codable, Identifiable {
    let id: UUID
    let coordinate: CodableCoordinate
    let capturedAt: Date
    let imageFilename: String
    let comment: String?
    let placeName: String?
    let placeAddress: String?
    
    static let geofenceRadius: Double = 10.0  // meters
}
```

### CloudKilroy (Firebase)
```swift
struct CloudKilroy: Identifiable, Hashable {
    let id: String
    let imageURL: String
    let latitude: Double
    let longitude: Double
    let geohash: String
    let placeName: String
    let placeAddress: String?
    let comment: String?
    let createdAt: Date
    let deviceId: String
}
```

### Firestore Schema
```
Collection: kilroys
Document ID: UUID string
Fields:
  - imageURL: String (Firebase Storage download URL)
  - latitude: Double
  - longitude: Double
  - geohash: String (6-char precision)
  - placeName: String
  - placeAddress: String? (optional)
  - comment: String? (optional)
  - createdAt: Timestamp
  - deviceId: String (anonymous device identifier)
```

---

## GEOHASHING

Used for efficient location queries. A geohash encodes lat/lon into a string where nearby locations share prefixes.

**Precision 6** = ~1.2km x 0.6km cells

```swift
// Encode location to geohash
let hash = Geohash.encode(latitude: 37.5, longitude: -122.2, precision: 6)
// Result: "9q9hvu"

// Query: Find all documents where geohash starts with "9q9hvu"
db.collection("kilroys")
    .whereField("geohash", isGreaterThanOrEqualTo: "9q9hvu")
    .whereField("geohash", isLessThan: "9q9hvu~")
```

We also query neighboring cells to catch edge cases.

---

## SERVICES REFERENCE

### LocationService
- Manages CLLocationManager
- Provides current location
- Sets up geofences for dropped memories
- Publishes location updates

### PhotosService
- Accesses Apple Photos library
- Filters for photos with location data
- Groups by location for discovery

### MemoryStore
- Persists dropped memories locally (JSON + images)
- Now also uploads to Firebase on save
- Provides local query by location

### FirebaseService
- Singleton: `FirebaseService.shared`
- Upload: compresses to JPEG 0.7, uploads to Storage, saves to Firestore
- Download: geohash query + distance filter
- Anonymous device ID for user identity (no auth required)

### HapticsService
- Triggers haptic feedback
- `approachTap()` — when approaching memories
- Uses UIImpactFeedbackGenerator

---

## UI PATTERNS

### Theme (KilroyTheme.swift)
```swift
// Colors
Color.kilroyBackground  // White
Color.kilroySurface     // Light gray
Color.kilroyText        // Near black
Color.kilroyTextSecondary // Gray
LinearGradient.kilroyGradient // Purple-cyan gradient

// Spacing
KilroySpacing.sm  // 8
KilroySpacing.md  // 16
KilroySpacing.lg  // 24

// Radius
KilroyRadius.sm   // 8
KilroyRadius.md   // 12
KilroyRadius.lg   // 16

// Typography
Font.kilroyTitle
Font.kilroyBody
Font.kilroyCaption
```

### Navigation
- No TabView or NavigationStack for main app
- Single-screen design with HomeView as root
- Sheets for detail views, capture, settings
- Modal presentation for camera

### Map
- Uses MapKit's SwiftUI Map
- Custom annotations for memory pins
- Clusters nearby pins
- User location shown

---

## FILE LOCATIONS

### Local Storage
```
Documents/
├── memories.json          # Array of DroppedMemory
└── MemoryImages/
    ├── {uuid}.jpg
    └── ...
```

### Firebase Storage
```
gs://kilroy-b52c0.firebasestorage.app/
└── kilroys/
    ├── {uuid}.jpg
    └── ...
```

---

## BUILD & DEPLOYMENT

### Xcode Settings
- iOS Deployment Target: 17.0
- Bundle ID: com.loudlabs.Kilroy
- Team: Katie's Apple Developer account
- Signing: Automatic

### Required Capabilities
- Location (Always and When In Use)
- Camera
- Photo Library
- Background Modes: Location updates

### Info.plist Keys
```xml
NSLocationWhenInUseUsageDescription
NSLocationAlwaysAndWhenInUseUsageDescription
NSCameraUsageDescription
NSPhotoLibraryUsageDescription
```

---

## COMMON OPERATIONS

### Adding a new Swift file
1. Create file in correct folder via Desktop Commander
2. In Xcode: Right-click folder → Add Files to Kilroy
3. Ensure "Copy items if needed" is checked
4. Verify it appears in Build Phases → Compile Sources

### Adding a Swift Package
1. File → Add Package Dependencies
2. Paste GitHub URL
3. Select specific products needed
4. Add Package

### TestFlight Build
1. Bump version/build number if needed
2. Product → Archive
3. Organizer → Distribute App → App Store Connect → Upload
4. Wait for processing
5. Add build to test group in App Store Connect

---

## DEBUGGING TIPS

### Firebase Issues
- Check GoogleService-Info.plist is in bundle
- Verify FirebaseApp.configure() is called in init
- Check Firestore rules allow read/write (test mode)
- Check Storage rules allow read/write (test mode)

### Location Issues
- Simulator: Set custom location in Debug menu
- Real device: Ensure permissions granted
- Check Info.plist has all required keys

### Build Errors
- Clean Build Folder (Shift+Cmd+K)
- Delete Derived Data if persistent issues
- Ensure all files are added to target

---

## FUTURE CONSIDERATIONS

### Authentication
Currently using anonymous device ID. Future options:
- Sign in with Apple (preferred for Apple-first approach)
- Keep anonymous but add optional profile

### Reciprocity ("To see, you must be seen")
Not yet implemented. Design:
- Track user's dropped Kilroys per location
- Only show others' Kilroys at locations where user has dropped one
- Or: Global unlock after N total drops

### Apple Watch
- Haptic tap when entering geofence
- No screen interaction needed
- WatchConnectivity framework

### AirPods Spatial Audio
- Whisper sound when near memory
- Directional audio pointing to memory location
- AVFoundation + CoreMotion for head tracking

---

*Technical reference for Kilroy iOS app. Last updated: December 3, 2025*
