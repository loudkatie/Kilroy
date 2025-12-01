//
//  KilroyMemory.swift
//  Kilroy
//
//  A Kilroy is a geo-pinned memory — a moment left in place.
//

import Foundation
import CoreLocation
import CloudKit

/// A Kilroy memory pinned to a location
struct KilroyMemory: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let createdAt: Date
    let creatorID: String
    let circle: PrivacyCircle
    
    // Content
    let imageURL: URL?
    let videoURL: URL?
    let caption: String?
    
    // Metadata
    let placeName: String?
    
    // Computed
    var age: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var yearsAgo: Int {
        Calendar.current.dateComponents([.year], from: createdAt, to: Date()).year ?? 0
    }
    
    // MARK: - Equatable (CLLocationCoordinate2D doesn't conform by default)
    
    static func == (lhs: KilroyMemory, rhs: KilroyMemory) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CloudKit Integration

extension KilroyMemory {
    
    static let recordType = "KilroyMemory"
    
    /// Create from CloudKit record
    init?(record: CKRecord) {
        guard
            let location = record["location"] as? CLLocation,
            let createdAt = record["createdAt"] as? Date,
            let creatorID = record["creatorID"] as? String,
            let circleRaw = record["circle"] as? String,
            let circle = PrivacyCircle(rawValue: circleRaw)
        else {
            return nil
        }
        
        self.id = record.recordID.recordName
        self.coordinate = location.coordinate
        self.createdAt = createdAt
        self.creatorID = creatorID
        self.circle = circle
        
        // Optional fields
        if let asset = record["image"] as? CKAsset {
            self.imageURL = asset.fileURL
        } else {
            self.imageURL = nil
        }
        
        if let asset = record["video"] as? CKAsset {
            self.videoURL = asset.fileURL
        } else {
            self.videoURL = nil
        }
        
        self.caption = record["caption"] as? String
        self.placeName = record["placeName"] as? String
    }
    
    /// Convert to CloudKit record
    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType)
        
        record["location"] = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        record["createdAt"] = createdAt
        record["creatorID"] = creatorID
        record["circle"] = circle.rawValue
        record["caption"] = caption
        record["placeName"] = placeName
        
        // Assets handled separately during save
        
        return record
    }
}
