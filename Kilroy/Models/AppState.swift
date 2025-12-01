//
//  AppState.swift
//  Kilroy
//
//  Global app state — what's happening right now.
//

import Foundation
import CoreLocation

/// The current moment state
enum MomentState: Equatable {
    case quiet                          // Nothing nearby, ambient
    case sensing                        // Actively checking location
    case nearbyKilroys(count: Int)      // Kilroys detected, awaiting reveal
    case viewing(KilroyMemory)          // Actively viewing a memory
    case capturing                      // Camera open, dropping a Kilroy
}

/// Global app state container
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Published State
    
    @Published var momentState: MomentState = .quiet
    @Published var currentLocation: CLLocation?
    @Published var nearbyMemories: [KilroyMemory] = []
    @Published var userPhotosNearby: Int = 0
    
    // MARK: - Permissions
    
    @Published var locationAuthorized: Bool = false
    @Published var photosAuthorized: Bool = false
    @Published var notificationsAuthorized: Bool = false
    
    // MARK: - User
    
    @Published var isAuthenticated: Bool = false
    @Published var userID: String?
    
    // MARK: - Computed
    
    var hasNearbyContent: Bool {
        !nearbyMemories.isEmpty || userPhotosNearby > 0
    }
    
    var totalNearbyCount: Int {
        nearbyMemories.count + userPhotosNearby
    }
}
