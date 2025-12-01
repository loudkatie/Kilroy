//
//  LocationService.swift
//  Kilroy
//
//  Manages location tracking and geofencing.
//  "Always" authorization required for background Kilroy detection.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationService: NSObject, ObservableObject {
    
    // MARK: - Published
    
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isMonitoring: Bool = false
    
    // MARK: - Private
    
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?
    
    // Detection radius for "nearby" (meters)
    let nearbyRadius: CLLocationDistance = 50
    
    // MARK: - Init
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Update every 10 meters
        authorizationStatus = manager.authorizationStatus
    }
    
    // MARK: - Public API
    
    /// Request location authorization
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    /// Request "Always" authorization for background detection
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    /// Start continuous location updates
    func startUpdating() {
        guard authorizationStatus == .authorizedWhenInUse || 
              authorizationStatus == .authorizedAlways else {
            return
        }
        manager.startUpdatingLocation()
        isMonitoring = true
    }
    
    /// Stop location updates
    func stopUpdating() {
        manager.stopUpdatingLocation()
        isMonitoring = false
    }
    
    /// Get current location once (async)
    func getCurrentLocation() async -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            return nil
        }
        
        manager.requestLocation()
        
        return await withCheckedContinuation { continuation in
            self.locationContinuation = continuation
        }
    }
    
    /// Check if a coordinate is within nearby radius
    func isNearby(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard let current = currentLocation else { return false }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: target) <= nearbyRadius
    }
    
    /// Distance to a coordinate (meters)
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let current = currentLocation else { return nil }
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return current.distance(from: target)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task { @MainActor in
            self.currentLocation = location
            
            // Resume any waiting continuation
            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(returning: location)
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationService error: \(error.localizedDescription)")
        
        Task { @MainActor in
            if let continuation = self.locationContinuation {
                self.locationContinuation = nil
                continuation.resume(returning: nil)
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self.startUpdating()
            }
        }
    }
}
