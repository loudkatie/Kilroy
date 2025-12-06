//
//  AdminConfig.swift
//  Kilroy
//
//  Admin configuration for Loud Labs founders.
//  Only whitelisted deviceIds can seed Kilroys.
//

import Foundation

/// Admin configuration - only Loud Labs founders can seed Kilroys
struct AdminConfig {
    
    // MARK: - Whitelisted Device IDs
    // Add deviceIds here to grant admin access
    // Get your deviceId from Settings > Developer > Device ID (tap copy icon)
    
    private static let adminDeviceIds: Set<String> = [
        // Katie's devices - ADD YOUR DEVICE ID HERE
        // Example: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
        
        // Wedge's devices
        // Derek's devices
        // Adam's devices
        // Sam's devices
    ]
    
    // MARK: - Admin Check
    
    /// Check if a device is an admin
    static func isAdmin(deviceId: String) -> Bool {
        return adminDeviceIds.contains(deviceId)
    }
    
    // MARK: - Seeded Kilroy Features
    
    /// Seeded Kilroys are pre-placed by admins for discovery
    /// They show up for everyone but are marked specially in the database
    static let seededKilroyFlag = "isSeeded"
}
