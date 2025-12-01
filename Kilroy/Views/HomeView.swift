//
//  HomeView.swift
//  Kilroy
//
//  One screen. The map. Full bleed.
//  Walk, feel the tap, discover.
//

import SwiftUI
import MapKit
import CoreLocation

struct HomeView: View {
    
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var photosService: PhotosService
    @EnvironmentObject var googlePhotosService: GooglePhotosService
    @EnvironmentObject var memoryStore: MemoryStore
    @EnvironmentObject var hapticsService: HapticsService
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var nearbyPhotoMemories: [LocalMemory] = []
    @State private var nearbyGoogleMemories: [GooglePhotoMemory] = []
    @State private var nearbyDroppedMemories: [DroppedMemory] = []
    @State private var showingMemoryCard = false
    @State private var showingCapture = false
    @State private var showingCollection = false
    @State private var showingProfile = false
    @State private var lastCheckLocation: CLLocation?
    @State private var hasTriggeredHaptic = false
    @State private var showingAllMemories = false
    
    private var totalNearbyCount: Int {
        nearbyPhotoMemories.count + nearbyGoogleMemories.count + nearbyDroppedMemories.count
    }
    
    private var allKilroyPins: [DroppedMemory] {
        memoryStore.memories
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // White header bar
            headerBar
            
            // Map in frame
            ZStack {
                mapView
                
                // Memory count badge (top right of map)
                VStack {
                    HStack {
                        Spacer()
                        if totalNearbyCount > 0 {
                            memoryBadge
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                }
                
                // Bottom controls
                VStack {
                    Spacer()
                    bottomOverlay
                }
                
                // Memory card rises when nearby
                if showingMemoryCard && totalNearbyCount > 0 {
                    memoryCardOverlay
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Color.kilroyBackground)
        .sheet(isPresented: $showingCollection) {
            CollectionSheet()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileSheet()
        }
        .sheet(isPresented: $showingAllMemories) {
            AllMemoriesSheet(
                photoMemories: nearbyPhotoMemories,
                googleMemories: nearbyGoogleMemories,
                droppedMemories: nearbyDroppedMemories
            )
        }
        .fullScreenCover(isPresented: $showingCapture) {
            CaptureView()
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            checkForMemories(at: newLocation)
        }
        .onChange(of: memoryStore.memories) { _, _ in
            if let location = locationService.currentLocation {
                checkForMemories(at: location, force: true)
            }
        }
        .onAppear {
            locationService.startUpdating()
            if let location = locationService.currentLocation {
                checkForMemories(at: location)
            }
            
            Task {
                await googlePhotosService.restorePreviousSignIn()
            }
        }
    }
    
    // MARK: - Header Bar
    
    private var headerBar: some View {
        HStack(alignment: .center) {
            Button {
                showingProfile = true
            } label: {
                Image("kilroy_wordmark_large")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.kilroyBackground)
    }
    
    private var memoryBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.kilroyPurple)
                .frame(width: 8, height: 8)
                .scaleEffect(showingMemoryCard ? 1.0 : 1.3)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: showingMemoryCard)
            
            Text("\(totalNearbyCount)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.kilroyPurple)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.kilroyBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingMemoryCard.toggle()
            }
        }
    }
    
    // MARK: - Map
    
    private var mapView: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()
            
            // Show ALL dropped Kilroys on the map
            ForEach(allKilroyPins) { memory in
                Annotation("", coordinate: memory.coordinate.clCoordinate) {
                    KilroyMapPin(isNearby: isNearby(memory))
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { }
        .onLongPressGesture {
            hapticsService.memoryPulse()
            showingCapture = true
        }
    }
    
    // MARK: - Bottom
    
    private var bottomOverlay: some View {
        HStack {
            // Collection button - swipe up or tap
            Button {
                showingCollection = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 16))
                    Text("My Kilroys")
                        .font(.system(size: 15, weight: .medium))
                }
                .foregroundColor(.kilroyText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Capture button
            Button {
                hapticsService.memoryPulse()
                showingCapture = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient.kilroyGradient)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white)
                }
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Memory Card
    
    private var memoryCardOverlay: some View {
        VStack {
            Spacer()
            
            NearbyMemoryCard(
                photoMemories: nearbyPhotoMemories,
                googleMemories: nearbyGoogleMemories,
                droppedMemories: nearbyDroppedMemories,
                onDismiss: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingMemoryCard = false
                    }
                },
                onViewAll: {
                    showingAllMemories = true
                }
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .background(
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showingMemoryCard = false
                    }
                }
        )
    }
    
    // MARK: - Logic
    
    private func isNearby(_ memory: DroppedMemory) -> Bool {
        guard let location = locationService.currentLocation else { return false }
        let memoryLocation = CLLocation(
            latitude: memory.coordinate.latitude,
            longitude: memory.coordinate.longitude
        )
        return location.distance(from: memoryLocation) <= 50
    }
    
    private func checkForMemories(at location: CLLocation?, force: Bool = false) {
        guard let location = location else { return }
        
        if !force, let last = lastCheckLocation,
           location.distance(from: last) < 10 {
            return
        }
        
        lastCheckLocation = location
        
        let photoMemories = photosService.findMemories(near: location, radius: 50)
        let googleMemories = googlePhotosService.findMemories(near: location, radius: 50)
        let droppedMemories = memoryStore.memoriesNear(location, radius: 50)
        
        let previousCount = totalNearbyCount
        
        nearbyPhotoMemories = photoMemories
        nearbyGoogleMemories = googleMemories
        nearbyDroppedMemories = droppedMemories
        
        let newCount = photoMemories.count + googleMemories.count + droppedMemories.count
        
        // Trigger haptic and show card when entering a memory zone
        if newCount > 0 && previousCount == 0 && !hasTriggeredHaptic {
            hapticsService.approachTap()
            hasTriggeredHaptic = true
            
            // Auto-show the memory card
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showingMemoryCard = true
            }
        }
        
        // Reset haptic trigger when leaving zone
        if newCount == 0 {
            hasTriggeredHaptic = false
            showingMemoryCard = false
        }
    }
}

// MARK: - Kilroy Map Pin

struct KilroyMapPin: View {
    let isNearby: Bool
    
    var body: some View {
        ZStack {
            // Outer glow when nearby
            if isNearby {
                Circle()
                    .fill(Color.kilroyPurple.opacity(0.2))
                    .frame(width: 32, height: 32)
            }
            
            // Pin
            Circle()
                .fill(isNearby ? Color.kilroyPurple : Color.kilroyPurple.opacity(0.6))
                .frame(width: 16, height: 16)
            
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
    }
}

// MARK: - Nearby Memory Card (rises from bottom)

struct NearbyMemoryCard: View {
    let photoMemories: [LocalMemory]
    let googleMemories: [GooglePhotoMemory]
    let droppedMemories: [DroppedMemory]
    let onDismiss: () -> Void
    let onViewAll: () -> Void
    
    private var totalCount: Int {
        photoMemories.count + googleMemories.count + droppedMemories.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Handle
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.kilroySubtle)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
            
            // Title
            HStack {
                Text(totalCount == 1 ? "A memory is here" : "\(totalCount) memories here")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.kilroyText)
                
                Spacer()
                
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.kilroyTextSecondary)
                        .padding(8)
                        .background(Color.kilroySurface)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            
            // Preview thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(droppedMemories) { memory in
                        DroppedMemoryThumbnail(memory: memory)
                    }
                    
                    ForEach(photoMemories) { memory in
                        PhotoMemoryThumbnail(memory: memory)
                    }
                    
                    ForEach(googleMemories) { memory in
                        GoogleMemoryThumbnail(memory: memory)
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 120)
            
            // View all button
            Button {
                onViewAll()
            } label: {
                Text("View All")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.kilroyPurple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.kilroyPurple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color.kilroyBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: -5)
    }
}

// MARK: - Thumbnails

struct DroppedMemoryThumbnail: View {
    let memory: DroppedMemory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let imageData = memory.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            if let comment = memory.comment, !comment.isEmpty {
                Text(comment)
                    .font(.system(size: 11))
                    .foregroundColor(.kilroyTextSecondary)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
            }
        }
    }
}

struct PhotoMemoryThumbnail: View {
    let memory: LocalMemory
    @State private var image: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.kilroySurface)
                    .frame(width: 100, height: 80)
                    .onAppear { loadImage() }
            }
            
            Text(memory.age)
                .font(.system(size: 11))
                .foregroundColor(.kilroyTextSecondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
        }
    }
    
    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: memory.asset,
            targetSize: CGSize(width: 200, height: 200),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result = result {
                image = result
            }
        }
    }
}

struct GoogleMemoryThumbnail: View {
    let memory: GooglePhotoMemory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: memory.thumbnailUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.kilroySurface)
            }
            .frame(width: 100, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(memory.age)
                .font(.system(size: 11))
                .foregroundColor(.kilroyTextSecondary)
                .lineLimit(1)
                .frame(width: 100, alignment: .leading)
        }
    }
}

// MARK: - Collection Sheet (My Kilroys)

struct CollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var memoryStore: MemoryStore
    
    var body: some View {
        NavigationStack {
            Group {
                if memoryStore.memories.isEmpty {
                    emptyState
                } else {
                    memoryList
                }
            }
            .navigationTitle("My Kilroys")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LinearGradient.kilroyGradient)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundColor(.kilroySubtle)
            
            Text("No Kilroys yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.kilroyText)
            
            Text("Long press on the map or tap + to drop your first memory.")
                .font(.kilroyBody)
                .foregroundColor(.kilroyTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var memoryList: some View {
        List {
            ForEach(memoryStore.memories) { memory in
                HStack(spacing: 12) {
                    if let imageData = memory.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.placeName ?? "Unknown location")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.kilroyText)
                        
                        if let comment = memory.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.system(size: 13))
                                .foregroundColor(.kilroyTextSecondary)
                                .lineLimit(1)
                        }
                        
                        Text(memory.formattedDate)
                            .font(.system(size: 12))
                            .foregroundColor(.kilroyTextSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Profile Sheet

struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var photosService: PhotosService
    @EnvironmentObject var googlePhotosService: GooglePhotosService
    @EnvironmentObject var memoryStore: MemoryStore
    
    @State private var isConnectingGoogle = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                // Stats
                Section {
                    statRow(icon: "mappin.circle.fill", label: "Kilroys Dropped", value: "\(memoryStore.memories.count)")
                    statRow(icon: "photo.fill", label: "Apple Photos Indexed", value: "\(photosService.indexedCount)")
                    statRow(icon: "g.circle.fill", label: "Google Photos Indexed", value: "\(googlePhotosService.indexedCount)")
                } header: {
                    Text("Stats")
                }
                
                // Photo Sources
                Section {
                    // Apple Photos
                    HStack {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(LinearGradient.kilroyGradient)
                            .frame(width: 28)
                        
                        Text("Apple Photos")
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    
                    // Google Photos
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .foregroundColor(.red)
                            .frame(width: 28)
                        
                        Text("Google Photos")
                        
                        Spacer()
                        
                        if googlePhotosService.isSignedIn {
                            Menu {
                                Button {
                                    Task {
                                        await googlePhotosService.buildIndex()
                                    }
                                } label: {
                                    Label("Refresh", systemImage: "arrow.clockwise")
                                }
                                
                                Button(role: .destructive) {
                                    googlePhotosService.signOut()
                                } label: {
                                    Label("Disconnect", systemImage: "xmark.circle")
                                }
                            } label: {
                                Text(googlePhotosService.userEmail ?? "Connected")
                                    .font(.system(size: 13))
                                    .foregroundColor(.kilroyTextSecondary)
                            }
                        } else {
                            Button("Connect") {
                                connectGoogle()
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.kilroyPurple)
                        }
                    }
                } header: {
                    Text("Photo Sources")
                } footer: {
                    Text("Your photo libraries are scanned for location data to surface memories at the right places.")
                }
                
                // About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.kilroyTextSecondary)
                    }
                    
                    Link(destination: URL(string: "https://loudlabs.co")!) {
                        HStack {
                            Text("Loud Labs")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.kilroyTextSecondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LinearGradient.kilroyGradient)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(LinearGradient.kilroyGradient)
                .frame(width: 28)
            
            Text(label)
            
            Spacer()
            
            Text(value)
                .foregroundColor(.kilroyTextSecondary)
                .font(.system(size: 15, weight: .medium))
        }
    }
    
    private func connectGoogle() {
        isConnectingGoogle = true
        
        Task {
            do {
                try await googlePhotosService.signIn()
                await googlePhotosService.buildIndex()
                isConnectingGoogle = false
            } catch {
                isConnectingGoogle = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - All Memories Sheet

struct AllMemoriesSheet: View {
    let photoMemories: [LocalMemory]
    let googleMemories: [GooglePhotoMemory]
    let droppedMemories: [DroppedMemory]
    
    @Environment(\.dismiss) private var dismiss
    
    private var totalCount: Int {
        photoMemories.count + googleMemories.count + droppedMemories.count
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(droppedMemories) { memory in
                        DroppedMemoryGridItem(memory: memory)
                    }
                    
                    ForEach(photoMemories) { memory in
                        PhotoMemoryGridItem(memory: memory)
                    }
                    
                    ForEach(googleMemories) { memory in
                        GoogleMemoryGridItem(memory: memory)
                    }
                }
            }
            .navigationTitle("\(totalCount) memories here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DroppedMemoryGridItem: View {
    let memory: DroppedMemory
    
    var body: some View {
        if let imageData = memory.imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipped()
        }
    }
}

struct PhotoMemoryGridItem: View {
    let memory: LocalMemory
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.kilroySurface)
                    .aspectRatio(1, contentMode: .fill)
                    .onAppear { loadImage() }
            }
        }
    }
    
    private func loadImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: memory.asset,
            targetSize: CGSize(width: 300, height: 300),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result = result {
                DispatchQueue.main.async {
                    self.image = result
                }
            }
        }
    }
}

struct GoogleMemoryGridItem: View {
    let memory: GooglePhotoMemory
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.kilroySurface)
                    .aspectRatio(1, contentMode: .fill)
                    .onAppear { loadImage() }
            }
        }
    }
    
    private func loadImage() {
        guard let url = URL(string: "\(memory.baseUrl)=w300-h300-c") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = uiImage
                }
            }
        }.resume()
    }
}

// MARK: - PHImageManager Import
import Photos
