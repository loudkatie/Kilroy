//
//  AdminSeedView.swift
//  Kilroy
//
//  Admin-only view for seeding Kilroys at any location with any date.
//  Used to pre-populate locations with historical/institutional content.
//

import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

struct AdminSeedView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var hapticsService: HapticsService
    
    // Photo selection
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
    // Location
    @State private var searchText = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var selectedPlaceName: String = ""
    @State private var selectedPlaceAddress: String = ""
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5, longitude: -122.2),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    
    // Content
    @State private var comment = ""
    @State private var memoryDate = Date()
    
    // State
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var canSeed: Bool {
        selectedImage != nil && selectedLocation != nil && !selectedPlaceName.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Photo Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Photo", systemImage: "photo.fill")
                            .font(.headline)
                            .foregroundStyle(LinearGradient.kilroyGradient)
                        
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.kilroySurface)
                                    .frame(height: 200)
                                    .overlay {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.largeTitle)
                                                .foregroundColor(.kilroyTextSecondary)
                                            Text("Tap to select photo")
                                                .font(.subheadline)
                                                .foregroundColor(.kilroyTextSecondary)
                                        }
                                    }
                            }
                        }
                        .onChange(of: selectedItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Location Search
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Location", systemImage: "mappin.circle.fill")
                            .font(.headline)
                            .foregroundStyle(LinearGradient.kilroyGradient)
                        
                        // Search field
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.kilroyTextSecondary)
                            TextField("Search for a place...", text: $searchText)
                                .textFieldStyle(.plain)
                                .onSubmit {
                                    searchLocation()
                                }
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                    searchResults = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.kilroyTextSecondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color.kilroySurface)
                        .cornerRadius(10)
                        
                        // Search results
                        if !searchResults.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(searchResults, id: \.self) { item in
                                    Button {
                                        selectPlace(item)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.name ?? "Unknown")
                                                    .font(.subheadline)
                                                    .foregroundColor(.kilroyText)
                                                if let address = item.placemark.title {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(.kilroyTextSecondary)
                                                        .lineLimit(1)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.right.circle")
                                                .foregroundColor(.kilroyActive)
                                        }
                                        .padding(.vertical, 10)
                                        .padding(.horizontal, 12)
                                    }
                                    Divider()
                                }
                            }
                            .background(Color.kilroySurface)
                            .cornerRadius(10)
                        }
                        
                        // Selected location display
                        if selectedLocation != nil {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(selectedPlaceName)
                                        .font(.subheadline.bold())
                                }
                                if !selectedPlaceAddress.isEmpty {
                                    Text(selectedPlaceAddress)
                                        .font(.caption)
                                        .foregroundColor(.kilroyTextSecondary)
                                }
                                
                                // Mini map preview
                                Map(coordinateRegion: .constant(MKCoordinateRegion(
                                    center: selectedLocation!,
                                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                )), annotationItems: [MapPin(coordinate: selectedLocation!)]) { pin in
                                    MapMarker(coordinate: pin.coordinate, tint: .purple)
                                }
                                .frame(height: 120)
                                .cornerRadius(8)
                                .disabled(true)
                            }
                            .padding()
                            .background(Color.kilroySurface)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Date Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Memory Date", systemImage: "calendar")
                            .font(.headline)
                            .foregroundStyle(LinearGradient.kilroyGradient)
                        
                        DatePicker(
                            "When was this memory?",
                            selection: $memoryDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.compact)
                        .padding()
                        .background(Color.kilroySurface)
                        .cornerRadius(10)
                        
                        Text("Set to a historical date for archival content")
                            .font(.caption)
                            .foregroundColor(.kilroyTextSecondary)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - Comment
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Story", systemImage: "text.quote")
                            .font(.headline)
                            .foregroundStyle(LinearGradient.kilroyGradient)
                        
                        TextField("What's the story behind this memory?", text: $comment, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                            .padding()
                            .background(Color.kilroySurface)
                            .cornerRadius(10)
                            .foregroundColor(.kilroyText)
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .background(Color.kilroyBackground)
            .navigationTitle("Seed Kilroy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.kilroyTextSecondary)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        seedKilroy()
                    } label: {
                        HStack(spacing: 4) {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "leaf.fill")
                            }
                            Text("Seed")
                        }
                        .fontWeight(.semibold)
                    }
                    .disabled(!canSeed || isSaving)
                    .foregroundStyle(canSeed ? LinearGradient.kilroyGradient : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Search Location
    
    private func searchLocation() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            isSearching = false
            if let response = response {
                searchResults = Array(response.mapItems.prefix(5))
            }
        }
    }
    
    private func selectPlace(_ item: MKMapItem) {
        selectedLocation = item.placemark.coordinate
        selectedPlaceName = item.name ?? "Unknown Location"
        selectedPlaceAddress = [
            item.placemark.thoroughfare,
            item.placemark.locality,
            item.placemark.administrativeArea
        ].compactMap { $0 }.joined(separator: ", ")
        
        searchResults = []
        searchText = ""
        
        hapticsService.success()
    }
    
    // MARK: - Seed Kilroy
    
    private func seedKilroy() {
        guard let image = selectedImage,
              let location = selectedLocation else { return }
        
        isSaving = true
        hapticsService.approachTap()
        
        Task {
            do {
                let _ = try await firebaseService.seedKilroy(
                    image: image,
                    location: location,
                    placeName: selectedPlaceName,
                    placeAddress: selectedPlaceAddress.isEmpty ? nil : selectedPlaceAddress,
                    comment: comment.isEmpty ? nil : comment,
                    memoryDate: memoryDate
                )
                
                await MainActor.run {
                    hapticsService.success()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// Helper for map annotation
struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    AdminSeedView()
}
