//
//  CaptureView.swift
//  Kilroy
//
//  Full-screen capture flow: camera → preview → story → drop.
//  Story field is ABOVE the fold — it's the soul of a Kilroy.
//

import SwiftUI
import MapKit

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var memoryStore: MemoryStore
    @EnvironmentObject var hapticsService: HapticsService
    
    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var comment = ""
    @State private var placeName: String?
    @State private var placeAddress: String?
    @State private var isSaving = false
    @State private var mapRegion: MKCoordinateRegion?
    
    var body: some View {
        ZStack {
            if showCamera {
                CameraView(capturedImage: $capturedImage)
                    .ignoresSafeArea()
                    .onChange(of: capturedImage) { _, newImage in
                        if newImage != nil {
                            showCamera = false
                            reverseGeocode()
                            setupMapRegion()
                            hapticsService.success()
                        }
                    }
                
                // Close and cancel buttons
                VStack {
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding()
                    Spacer()
                }
            } else if let image = capturedImage {
                CapturePreviewView(
                    image: image,
                    comment: $comment,
                    placeName: placeName,
                    placeAddress: placeAddress,
                    mapRegion: mapRegion,
                    coordinate: locationService.currentLocation?.coordinate,
                    isSaving: isSaving,
                    onRetake: {
                        capturedImage = nil
                        showCamera = true
                    },
                    onDrop: dropMemory
                )
            }
        }
        .background(Color.black)
    }
    
    private func setupMapRegion() {
        guard let coord = locationService.currentLocation?.coordinate else { return }
        mapRegion = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
        )
    }
    
    private func reverseGeocode() {
        guard let location = locationService.currentLocation else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                Task { @MainActor in
                    self.placeName = placemark.name ?? placemark.thoroughfare
                    self.placeAddress = [
                        placemark.thoroughfare,
                        placemark.locality,
                        placemark.administrativeArea
                    ].compactMap { $0 }.joined(separator: ", ")
                }
            }
        }
    }
    
    private func dropMemory() {
        guard let image = capturedImage,
              let coordinate = locationService.currentLocation?.coordinate else { return }
        
        isSaving = true
        hapticsService.approachTap()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let _ = memoryStore.saveMemory(
                image: image,
                coordinate: coordinate,
                comment: comment.isEmpty ? nil : comment,
                placeName: placeName,
                placeAddress: placeAddress
            )
            
            hapticsService.success()
            dismiss()
        }
    }
}

// MARK: - Preview View

struct CapturePreviewView: View {
    let image: UIImage
    @Binding var comment: String
    let placeName: String?
    let placeAddress: String?
    let mapRegion: MKCoordinateRegion?
    let coordinate: CLLocationCoordinate2D?
    let isSaving: Bool
    let onRetake: () -> Void
    let onDrop: () -> Void
    
    @FocusState private var isCommentFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.kilroyBackground.ignoresSafeArea()
                
                // Everything scrollable
                ScrollView {
                    VStack(spacing: KilroySpacing.lg) {
                        
                        // Photo — full width, scrollable
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                            .clipped()
                        
                        // STORY FIELD
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What's the story?")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.kilroyText)
                            
                            TextField("Leave a note for whoever finds this...", text: $comment, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.system(size: 17))
                                .padding(KilroySpacing.md)
                                .frame(minHeight: 100, alignment: .topLeading)
                                .background(Color.kilroySurface)
                                .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
                                .focused($isCommentFocused)
                                .lineLimit(4...8)
                        }
                        .padding(.horizontal, KilroySpacing.lg)
                        
                        // Location card
                        VStack(alignment: .leading, spacing: KilroySpacing.sm) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(LinearGradient.kilroyGradient)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(placeName ?? "Pinning location...")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.kilroyText)
                                    
                                    if let address = placeAddress {
                                        Text(address)
                                            .font(.kilroyCaption)
                                            .foregroundColor(.kilroyTextSecondary)
                                    }
                                }
                                Spacer()
                                
                                // Edit hint
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.kilroyTextSecondary)
                            }
                            
                            // Mini map
                            if let region = mapRegion, let coord = coordinate {
                                Map(initialPosition: .region(region)) {
                                    Marker("", coordinate: coord)
                                        .tint(.purple)
                                }
                                .frame(height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
                                .disabled(true)
                            }
                            
                            // Geofence note
                            HStack(spacing: 6) {
                                Image(systemName: "scope")
                                    .font(.caption)
                                Text("\(Int(DroppedMemory.geofenceRadius))m radius — they'll need to be right here")
                                    .font(.kilroyCaption)
                            }
                            .foregroundColor(.kilroyTextSecondary)
                        }
                        .padding(KilroySpacing.md)
                        .background(Color.kilroySurface)
                        .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.lg))
                        .padding(.horizontal, KilroySpacing.lg)
                        
                        Spacer(minLength: 100)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isCommentFocused = false
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isCommentFocused = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Action buttons — always visible
                HStack(spacing: KilroySpacing.md) {
                    Button(action: onRetake) {
                        Text("Retake")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.kilroyText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, KilroySpacing.md)
                            .background(Color.kilroySurface)
                            .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
                    }
                    
                    Button(action: onDrop) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "mappin.and.ellipse")
                                Text("Drop Kilroy")
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KilroySpacing.md)
                        .background(LinearGradient.kilroyGradient)
                        .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
                    }
                    .disabled(isSaving)
                }
                .padding(KilroySpacing.lg)
                .background(Color.kilroyBackground)
            }
        }
    }
}
