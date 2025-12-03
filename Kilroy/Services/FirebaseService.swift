//
//  FirebaseService.swift
//  Kilroy
//
//  Created by Loud Labs
//

import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseStorage
import CoreLocation
import UIKit

/// Handles all Firebase operations for Kilroy
/// - Uploads Kilroys (image + metadata) when dropped
/// - Downloads nearby Kilroys when user is at a location
/// - Uses geohashing for efficient location queries
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    // Collection name in Firestore
    private let kilroysCollection = "kilroys"
    
    // How close you need to be to see a Kilroy (meters)
    private let discoveryRadius: Double = 50.0
    
    @Published var nearbyKilroys: [CloudKilroy] = []
    @Published var isLoading = false
    
    private init() {}
    
    /// Call this after FirebaseApp.configure() in the app init
    func configure() {
        print("🔥 FirebaseService configured")
    }
    
    // MARK: - Upload a Kilroy
    
    /// Uploads a new Kilroy to Firebase
    /// - Parameters:
    ///   - image: The photo to upload
    ///   - location: Where it was dropped
    ///   - placeName: Human-readable place name
    ///   - comment: Optional message
    /// - Returns: The created CloudKilroy
    func uploadKilroy(
        image: UIImage,
        location: CLLocationCoordinate2D,
        placeName: String,
        placeAddress: String?,
        comment: String?
    ) async throws -> CloudKilroy {
        
        // 1. Compress image to save bandwidth/storage
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw FirebaseError.imageCompressionFailed
        }
        
        // 2. Generate unique ID
        let kilroyId = UUID().uuidString
        
        // 3. Upload image to Storage
        let imageRef = storage.reference().child("kilroys/\(kilroyId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
        let imageURL = try await imageRef.downloadURL().absoluteString
        
        // 4. Create Firestore document
        let kilroy = CloudKilroy(
            id: kilroyId,
            imageURL: imageURL,
            latitude: location.latitude,
            longitude: location.longitude,
            geohash: Geohash.encode(latitude: location.latitude, longitude: location.longitude, precision: 6),
            placeName: placeName,
            placeAddress: placeAddress,
            comment: comment,
            createdAt: Date(),
            deviceId: getDeviceId()
        )
        
        // 5. Save to Firestore
        try db.collection(kilroysCollection).document(kilroyId).setData(kilroy.toDictionary())
        
        print("✅ Kilroy uploaded: \(kilroyId) at \(placeName)")
        return kilroy
    }
    
    // MARK: - Fetch Nearby Kilroys
    
    /// Fetches all Kilroys near a location (alias for HomeView compatibility)
    func fetchKilroysNear(coordinate: CLLocationCoordinate2D, radiusMeters: Double = 50) async throws -> [CloudKilroy] {
        return try await fetchNearbyKilroys(location: coordinate, radius: radiusMeters)
    }
    
    /// Fetches all Kilroys near a location
    func fetchNearbyKilroys(location: CLLocationCoordinate2D, radius: Double = 50.0) async throws -> [CloudKilroy] {
        isLoading = true
        defer { isLoading = false }
        
        // Get geohash neighbors for efficient query
        let centerHash = Geohash.encode(latitude: location.latitude, longitude: location.longitude, precision: 6)
        let neighbors = Geohash.neighbors(of: centerHash)
        let searchHashes = [centerHash] + neighbors
        
        var allKilroys: [CloudKilroy] = []
        
        // Query each geohash area
        for hash in searchHashes {
            let snapshot = try await db.collection(kilroysCollection)
                .whereField("geohash", isGreaterThanOrEqualTo: hash)
                .whereField("geohash", isLessThan: hash + "~")
                .getDocuments()
            
            let kilroys = snapshot.documents.compactMap { doc -> CloudKilroy? in
                CloudKilroy(from: doc.data(), id: doc.documentID)
            }
            allKilroys.append(contentsOf: kilroys)
        }
        
        // Filter by actual distance (geohash is approximate)
        let nearby = allKilroys.filter { kilroy in
            let kilroyLocation = CLLocation(latitude: kilroy.latitude, longitude: kilroy.longitude)
            let userLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            return kilroyLocation.distance(from: userLocation) <= radius
        }
        
        // Remove duplicates and sort by date
        let unique = Array(Set(nearby)).sorted { $0.createdAt > $1.createdAt }
        
        await MainActor.run {
            self.nearbyKilroys = unique
        }
        
        print("📍 Found \(unique.count) Kilroys near (\(location.latitude), \(location.longitude))")
        return unique
    }
    
    // MARK: - Fetch All Kilroys (for map view)
    
    /// Fetches all Kilroys (for testing/map view)
    func fetchAllKilroys() async throws -> [CloudKilroy] {
        let snapshot = try await db.collection(kilroysCollection)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        
        return snapshot.documents.compactMap { doc in
            CloudKilroy(from: doc.data(), id: doc.documentID)
        }
    }
    
    // MARK: - Device ID (anonymous user identity)
    
    private func getDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: "kilroy_device_id") {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "kilroy_device_id")
        return newId
    }
}

// MARK: - Cloud Kilroy Model

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
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "imageURL": imageURL,
            "latitude": latitude,
            "longitude": longitude,
            "geohash": geohash,
            "placeName": placeName,
            "createdAt": Timestamp(date: createdAt),
            "deviceId": deviceId
        ]
        if let address = placeAddress { dict["placeAddress"] = address }
        if let comment = comment { dict["comment"] = comment }
        return dict
    }
    
    init(id: String, imageURL: String, latitude: Double, longitude: Double, geohash: String, placeName: String, placeAddress: String?, comment: String?, createdAt: Date, deviceId: String) {
        self.id = id
        self.imageURL = imageURL
        self.latitude = latitude
        self.longitude = longitude
        self.geohash = geohash
        self.placeName = placeName
        self.placeAddress = placeAddress
        self.comment = comment
        self.createdAt = createdAt
        self.deviceId = deviceId
    }
    
    init?(from dict: [String: Any], id: String) {
        guard let imageURL = dict["imageURL"] as? String,
              let latitude = dict["latitude"] as? Double,
              let longitude = dict["longitude"] as? Double,
              let geohash = dict["geohash"] as? String,
              let placeName = dict["placeName"] as? String,
              let timestamp = dict["createdAt"] as? Timestamp,
              let deviceId = dict["deviceId"] as? String
        else { return nil }
        
        self.id = id
        self.imageURL = imageURL
        self.latitude = latitude
        self.longitude = longitude
        self.geohash = geohash
        self.placeName = placeName
        self.placeAddress = dict["placeAddress"] as? String
        self.comment = dict["comment"] as? String
        self.createdAt = timestamp.dateValue()
        self.deviceId = deviceId
    }
}

// MARK: - Errors

enum FirebaseError: Error, LocalizedError {
    case imageCompressionFailed
    case uploadFailed
    case fetchFailed
    
    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed: return "Failed to compress image"
        case .uploadFailed: return "Failed to upload Kilroy"
        case .fetchFailed: return "Failed to fetch Kilroys"
        }
    }
}

// MARK: - Geohash Helper

/// Simple geohash implementation for location-based queries
struct Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")
    
    static func encode(latitude: Double, longitude: Double, precision: Int = 6) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var bit = 0
        var ch = 0
        var isEven = true
        
        while hash.count < precision {
            if isEven {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    ch |= (1 << (4 - bit))
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    ch |= (1 << (4 - bit))
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }
            isEven.toggle()
            
            if bit < 4 {
                bit += 1
            } else {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }
        return hash
    }
    
    static func neighbors(of hash: String) -> [String] {
        // Simplified: return adjacent geohash cells
        // For production, implement proper neighbor calculation
        guard let lastChar = hash.last,
              let index = base32.firstIndex(of: lastChar) else { return [] }
        
        var neighbors: [String] = []
        let prefix = String(hash.dropLast())
        
        // Get adjacent characters in base32
        if index > 0 {
            neighbors.append(prefix + String(base32[index - 1]))
        }
        if index < base32.count - 1 {
            neighbors.append(prefix + String(base32[index + 1]))
        }
        
        return neighbors
    }
}
