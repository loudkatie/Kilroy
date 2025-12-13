//
//  MemoryMapView.swift
//  Kilroy
//
//  Full-screen map showing ALL your geotagged memories.
//  Your entire photo history, visualized geographically.
//

import SwiftUI
import MapKit
import Photos

struct MemoryMapView: View {
    
    @EnvironmentObject var photosService: PhotosService
    @EnvironmentObject var locationService: LocationService
    @Environment(\.dismiss) private var dismiss
    
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedPin: MemoryPin?
    @State private var mapStyle: MapStyleOption = .standard
    
    enum MapStyleOption: String, CaseIterable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map with all pins
                Map(position: $cameraPosition, selection: $selectedPin) {
                    // User location
                    UserAnnotation()
                    
                    // All memory pins
                    ForEach(photosService.allMemoryPins) { pin in
                        Marker(
                            "",
                            coordinate: pin.coordinate
                        )
                        .tint(pinColor(for: pin))
                        .tag(pin)
                    }
                }
                .mapStyle(currentMapStyle)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .ignoresSafeArea(edges: .bottom)
                
                // Stats overlay
                VStack {
                    Spacer()
                    statsBar
                }
            }
            .navigationTitle("Memory Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(MapStyleOption.allCases, id: \.self) { style in
                            Button {
                                mapStyle = style
                            } label: {
                                HStack {
                                    Text(style.rawValue)
                                    if mapStyle == style {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
            .sheet(item: $selectedPin) { pin in
                MemoryPinDetail(pin: pin)
                    .presentationDetents([.medium])
            }
            .onAppear {
                fitMapToAllPins()
            }
        }
    }
    
    private var currentMapStyle: MapStyle {
        switch mapStyle {
        case .standard:
            return .standard
        case .satellite:
            return .imagery
        case .hybrid:
            return .hybrid
        }
    }
    
    private var statsBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(photosService.allMemoryPins.count) memories")
                    .font(.kilroyHeadline)
                    .foregroundColor(.kilroyText)
                
                if let oldest = oldestMemory, let newest = newestMemory {
                    Text("\(formatYear(oldest.captureDate)) – \(formatYear(newest.captureDate))")
                        .font(.kilroyCaption)
                        .foregroundColor(.kilroyTextSecondary)
                }
            }
            
            Spacer()
            
            // Legend
            HStack(spacing: 12) {
                legendItem(color: .purple, label: "Recent")
                legendItem(color: .orange, label: "5+ yrs")
                legendItem(color: .cyan, label: "10+ yrs")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.kilroyCaption)
                .foregroundColor(.kilroyTextSecondary)
        }
    }
    
    private func pinColor(for pin: MemoryPin) -> Color {
        let years = pin.yearsAgo
        if years >= 10 {
            return .cyan
        } else if years >= 5 {
            return .orange
        } else {
            return .purple
        }
    }
    
    private var oldestMemory: MemoryPin? {
        photosService.allMemoryPins.min { $0.captureDate < $1.captureDate }
    }
    
    private var newestMemory: MemoryPin? {
        photosService.allMemoryPins.max { $0.captureDate < $1.captureDate }
    }
    
    private func formatYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: date)
    }
    
    private func fitMapToAllPins() {
        guard !photosService.allMemoryPins.isEmpty else { return }
        
        let coords = photosService.allMemoryPins.map { $0.coordinate }
        
        var minLat = coords[0].latitude
        var maxLat = coords[0].latitude
        var minLon = coords[0].longitude
        var maxLon = coords[0].longitude
        
        for coord in coords {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Pin Detail Sheet

struct MemoryPinDetail: View {
    let pin: MemoryPin
    
    @EnvironmentObject var photosService: PhotosService
    @State private var thumbnail: UIImage?
    
    var body: some View {
        VStack(spacing: KilroySpacing.md) {
            // Thumbnail
            if let image = thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.lg))
            } else {
                RoundedRectangle(cornerRadius: KilroyRadius.lg)
                    .fill(Color.kilroySurface)
                    .frame(height: 200)
                    .overlay {
                        ProgressView()
                    }
            }
            
            // Info
            VStack(spacing: KilroySpacing.sm) {
                Text(formattedDate)
                    .font(.kilroyHeadline)
                    .foregroundColor(.kilroyText)
                
                Text(timeAgo)
                    .font(.kilroyBody)
                    .foregroundColor(.kilroyTextSecondary)
                
                Text(coordinateString)
                    .font(.kilroyCaption)
                    .foregroundColor(.kilroyTextSecondary)
                    .monospacedDigit()
            }
            
            Spacer()
        }
        .padding()
        .task {
            await loadThumbnail()
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: pin.captureDate)
    }
    
    private var timeAgo: String {
        let years = pin.yearsAgo
        if years == 0 {
            return "This year"
        } else if years == 1 {
            return "1 year ago"
        } else {
            return "\(years) years ago"
        }
    }
    
    private var coordinateString: String {
        let lat = String(format: "%.5f", pin.coordinate.latitude)
        let lon = String(format: "%.5f", pin.coordinate.longitude)
        return "\(lat), \(lon)"
    }
    
    private func loadThumbnail() async {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [pin.id], options: nil)
        guard let asset = fetchResult.firstObject else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        let size = CGSize(width: 400, height: 400)
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            Task { @MainActor in
                self.thumbnail = image
            }
        }
    }
}
