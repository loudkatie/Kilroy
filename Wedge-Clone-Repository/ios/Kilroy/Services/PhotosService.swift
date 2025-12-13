//
//  PhotosService.swift
//  Kilroy
//
//  Scans user's Photos library and builds spatial index for proximity queries.
//  Your own memories, surfaced at the places you took them.
//

import Foundation
import Photos
import CoreLocation
import os.log

private let logger = Logger(subsystem: "com.loudlabs.kilroy", category: "PhotosService")

/// Metadata for a geotagged photo from user's library
struct LocalMemory: Identifiable {
    let id: String
    let asset: PHAsset
    let coordinate: CLLocationCoordinate2D
    let captureDate: Date
    let distanceMeters: Double?
    
    var age: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: captureDate, relativeTo: Date())
    }
    
    var yearsAgo: Int {
        Calendar.current.dateComponents([.year], from: captureDate, to: Date()).year ?? 0
    }
}

/// Lightweight struct for map pins (doesn't hold PHAsset reference)
struct MemoryPin: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let captureDate: Date
    
    var yearsAgo: Int {
        Calendar.current.dateComponents([.year], from: captureDate, to: Date()).year ?? 0
    }
    
    // MARK: - Hashable & Equatable (hash and compare by stable id)
    static func == (lhs: MemoryPin, rhs: MemoryPin) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@MainActor
final class PhotosService: ObservableObject {
    
    // MARK: - Published
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isIndexing: Bool = false
    @Published var indexedCount: Int = 0
    @Published var indexingProgress: String = ""
    
    /// All memory pins for map display
    @Published var allMemoryPins: [MemoryPin] = []
    
    // MARK: - Private
    
    /// Spatial grid: hash -> asset IDs
    private var spatialGrid: [String: Set<String>] = [:]
    
    /// Asset cache: ID -> (coordinate, date)
    private var assetCache: [String: (CLLocationCoordinate2D, Date)] = [:]
    
    /// Grid resolution (~50m cells)
    private let gridResolution: Double = 0.0005
    
    // MARK: - Init
    
    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status
    }
    
    // MARK: - Indexing
    
    func buildIndex() async {
        print("🚀 PhotosService.buildIndex() CALLED")
        logger.info("buildIndex() called")
        
        // Re-check authorization status before indexing
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authorizationStatus = currentStatus
        
        guard currentStatus == .authorized || currentStatus == .limited else {
            logger.error("Not authorized. Status: \(currentStatus.rawValue)")
            print("❌ PhotosService: Not authorized. Status: \(currentStatus.rawValue)")
            return
        }
        
        isIndexing = true
        indexingProgress = "Starting..."
        
        logger.info("Starting index build...")
        print("🔍 PhotosService: Starting index build...")
        
        // Clear existing
        spatialGrid.removeAll()
        assetCache.removeAll()
        allMemoryPins.removeAll()
        indexedCount = 0
        
        // Fetch ALL photos (no limit)
        let photoOptions = PHFetchOptions()
        photoOptions.predicate = NSPredicate(format: "mediaSubtype != %d", PHAssetMediaSubtype.photoScreenshot.rawValue)
        photoOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let photos = PHAsset.fetchAssets(with: .image, options: photoOptions)
        let videos = PHAsset.fetchAssets(with: .video, options: nil)
        
        let totalAssets = photos.count + videos.count
        indexingProgress = "Scanning \(totalAssets) items..."
        
        print("PhotosService: Found \(photos.count) photos, \(videos.count) videos")
        
        var count = 0
        var pins: [MemoryPin] = []
        
        // Index photos with location
        photos.enumerateObjects { [weak self] asset, index, _ in
            guard let self = self else { return }
            
            if let location = asset.location, let date = asset.creationDate {
                self.indexAssetData(
                    id: asset.localIdentifier,
                    coordinate: location.coordinate,
                    date: date
                )
                pins.append(MemoryPin(
                    id: asset.localIdentifier,
                    coordinate: location.coordinate,
                    captureDate: date
                ))
                count += 1
            }
            
            // Update progress every 500 items
            if index % 500 == 0 {
                Task { @MainActor in
                    self.indexingProgress = "Photos: \(index)/\(photos.count)..."
                }
            }
        }
        
        indexingProgress = "Scanning videos..."
        
        // Index videos with location
        videos.enumerateObjects { [weak self] asset, index, _ in
            guard let self = self else { return }
            
            if let location = asset.location, let date = asset.creationDate {
                self.indexAssetData(
                    id: asset.localIdentifier,
                    coordinate: location.coordinate,
                    date: date
                )
                pins.append(MemoryPin(
                    id: asset.localIdentifier,
                    coordinate: location.coordinate,
                    captureDate: date
                ))
                count += 1
            }
        }
        
        // Update on main thread
        indexedCount = count
        allMemoryPins = pins
        isIndexing = false
        indexingProgress = ""
        
        print("PhotosService: Indexed \(count) geotagged assets. Total pins: \(pins.count)")
    }
    
    // MARK: - Query
    
    func findMemories(near location: CLLocation, radius: CLLocationDistance = 50) -> [LocalMemory] {
        let radiusDegrees = radius / 111_000
        let cellsToSearch = Int(ceil(radiusDegrees / gridResolution)) + 1
        
        var candidateIds = Set<String>()
        
        for latOffset in -cellsToSearch...cellsToSearch {
            for lonOffset in -cellsToSearch...cellsToSearch {
                let lat = location.coordinate.latitude + Double(latOffset) * gridResolution
                let lon = location.coordinate.longitude + Double(lonOffset) * gridResolution
                let key = gridKey(lat: lat, lon: lon)
                
                if let ids = spatialGrid[key] {
                    candidateIds.formUnion(ids)
                }
            }
        }
        
        var memories: [LocalMemory] = []
        
        for id in candidateIds {
            guard let (coord, date) = assetCache[id] else { continue }
            
            let assetLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = location.distance(from: assetLocation)
            
            if distance <= radius {
                if let asset = fetchAsset(id: id) {
                    memories.append(LocalMemory(
                        id: id,
                        asset: asset,
                        coordinate: coord,
                        captureDate: date,
                        distanceMeters: distance
                    ))
                }
            }
        }
        
        return memories.sorted { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }
    }
    
    func memoryCount(near location: CLLocation, radius: CLLocationDistance = 50) -> Int {
        findMemories(near: location, radius: radius).count
    }
    
    // MARK: - Private
    
    private func indexAssetData(id: String, coordinate: CLLocationCoordinate2D, date: Date) {
        let key = gridKey(lat: coordinate.latitude, lon: coordinate.longitude)
        
        if spatialGrid[key] == nil {
            spatialGrid[key] = []
        }
        spatialGrid[key]?.insert(id)
        assetCache[id] = (coordinate, date)
    }
    
    private func gridKey(lat: Double, lon: Double) -> String {
        let latCell = Int(floor(lat / gridResolution))
        let lonCell = Int(floor(lon / gridResolution))
        return "\(latCell)_\(lonCell)"
    }
    
    private func fetchAsset(id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }
}
