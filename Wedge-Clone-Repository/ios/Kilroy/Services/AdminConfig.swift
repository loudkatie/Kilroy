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
        // Katie's devices
        "53B8FED8-433E-4D26-A187-839D25C6AAAD",
        
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
