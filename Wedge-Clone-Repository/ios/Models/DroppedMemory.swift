//
//  DroppedMemory.swift
//  Kilroy
//
//  A memory the user has captured and dropped at a location.
//  In v2, these will sync to cloud and be visible to ALL users.
//

import Foundation
import CoreLocation
import UIKit

/// A locally-stored memory dropped by the user
struct DroppedMemory: Identifiable, Codable, Equatable {
    let id: UUID
    let coordinate: CodableCoordinate
    let capturedAt: Date
    let imageFilename: String
    let comment: String?
    let placeName: String?
    let placeAddress: String?
    
    // Geofence radius in meters — tight so they know exactly where
    static let geofenceRadius: Double = 10.0
    
    var location: CLLocation {
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
    
    /// Alias for capturedAt for consistency
    var timestamp: Date { capturedAt }
    
    // MARK: - Image Loading
    
    /// Load image data from disk
    var imageData: Data? {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsDirectory.appendingPathComponent("MemoryImages", isDirectory: true)
        let url = imagesDirectory.appendingPathComponent(imageFilename)
        return try? Data(contentsOf: url)
    }
    
    // MARK: - Computed
    
    var age: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: capturedAt, relativeTo: Date())
    }
    
    var yearsAgo: Int {
        Calendar.current.dateComponents([.year], from: capturedAt, to: Date()).year ?? 0
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: capturedAt)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: DroppedMemory, rhs: DroppedMemory) -> Bool {
        lhs.id == rhs.id
    }
}

/// Codable wrapper for CLLocationCoordinate2D
struct CodableCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
