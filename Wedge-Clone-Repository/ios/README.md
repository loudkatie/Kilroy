# Kilroy iOS App (SwiftUI)

This is the native iOS version of Kilroy, built using SwiftUI.  
It is the frontend for the geospatial memory app, now fully connected to Firebase for real-time, location-aware memory drops.

## Features

- Drop memories tied to real-world locations
- View your own and others’ memories as you move
- Firebase Firestore + Anonymous Auth integration
- Optional Google Photos connection
- All on-device privacy-first logic

## Project Structure

- `App/` – App launch and lifecycle
- `Models/` – Core data models (KilroyMemory, DroppedMemory)
- `Views/` – SwiftUI interface: map, onboarding, memory detail, capture
- `Services/` – Location tracking, memory store, Firebase bridge, haptics
- `Resources/` – Assets and `.plist` files

## How to Run

1. Open `Kilroy.xcodeproj`
2. Select a real iOS device (iOS 17+ recommended)
3. Press ⌘R (Run)

**Note:** `GoogleService-Info.plist` is already included for Firebase.

## Built & Maintained By

- iOS App: [@loudkatie](https://github.com/loudkatie)
- Original Backend: [@wedgemartin](https://github.com/wedgemartin)

---

This iOS build was added as a full front-end for Kilroy and is ready to demo and pair with the backend.
