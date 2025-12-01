//
//  GooglePhotosService.swift
//  Kilroy
//
//  Integrates with Google Photos API to fetch geotagged media.
//  Complements Apple Photos for users with cross-platform libraries.
//

import Foundation
import CoreLocation
import GoogleSignIn

/// A photo from Google Photos with location metadata
struct GooglePhotoMemory: Identifiable {
    let id: String
    let baseUrl: String
    let thumbnailUrl: String
    let coordinate: CLLocationCoordinate2D
    let captureDate: Date
    let width: Int
    let height: Int
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

@MainActor
final class GooglePhotosService: ObservableObject {
    
    // MARK: - Published
    
    @Published var isSignedIn: Bool = false
    @Published var isIndexing: Bool = false
    @Published var indexedCount: Int = 0
    @Published var userEmail: String?
    
    // MARK: - Private
    
    /// Spatial grid: hash -> photo IDs
    private var spatialGrid: [String: Set<String>] = [:]
    
    /// Photo cache: ID -> GooglePhotoMemory data
    private var photoCache: [String: (coordinate: CLLocationCoordinate2D, date: Date, baseUrl: String, width: Int, height: Int)] = [:]
    
    /// Grid resolution (~50m cells)
    private let gridResolution: Double = 0.0005
    
    /// Google Photos API base URL
    private let apiBaseUrl = "https://photoslibrary.googleapis.com/v1"
    
    /// Required OAuth scopes
    private let scopes = ["https://www.googleapis.com/auth/photoslibrary.readonly"]
    
    // MARK: - Init
    
    init() {
        // Check if already signed in
        if let user = GIDSignIn.sharedInstance.currentUser,
           user.grantedScopes?.contains(scopes[0]) == true {
            isSignedIn = true
            userEmail = user.profile?.email
        }
    }
    
    // MARK: - Authentication
    
    /// Sign in with Google and request Photos access
    func signIn() async throws {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            throw GooglePhotosError.noRootViewController
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: rootVC,
            hint: nil,
            additionalScopes: scopes
        )
        
        // Log granted scopes for debugging
        let grantedScopes = result.user.grantedScopes ?? []
        print("GooglePhotosService: Requested scopes: \(scopes)")
        print("GooglePhotosService: Granted scopes: \(grantedScopes)")
        
        // Check if Photos scope was granted
        let hasPhotosScope = grantedScopes.contains(scopes[0])
        print("GooglePhotosService: Photos scope granted: \(hasPhotosScope)")
        
        isSignedIn = true
        userEmail = result.user.profile?.email
        
        print("GooglePhotosService: Signed in as \(userEmail ?? "unknown")")
    }
    
    /// Sign out and clear cached data
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        GIDSignIn.sharedInstance.disconnect() // Force revoke tokens
        isSignedIn = false
        userEmail = nil
        spatialGrid.removeAll()
        photoCache.removeAll()
        indexedCount = 0
        
        print("GooglePhotosService: Signed out and disconnected")
    }
    
    /// Restore previous sign-in session
    func restorePreviousSignIn() async -> Bool {
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            
            // Check if we have the photos scope
            if user.grantedScopes?.contains(scopes[0]) == true {
                isSignedIn = true
                userEmail = user.profile?.email
                return true
            } else {
                // Need to request additional scope
                return false
            }
        } catch {
            print("GooglePhotosService: No previous sign-in to restore")
            return false
        }
    }
    
    // MARK: - Indexing
    
    /// Build spatial index from Google Photos library
    func buildIndex() async {
        guard isSignedIn else { return }
        
        isIndexing = true
        defer { isIndexing = false }
        
        spatialGrid.removeAll()
        photoCache.removeAll()
        indexedCount = 0
        
        do {
            var pageToken: String? = nil
            var totalIndexed = 0
            let maxPhotos = 5000
            
            repeat {
                let (items, nextToken) = try await fetchMediaItems(pageToken: pageToken)
                
                for item in items {
                    if totalIndexed >= maxPhotos { break }
                    
                    if let memory = parseMediaItem(item) {
                        indexPhoto(memory)
                        totalIndexed += 1
                    }
                }
                
                pageToken = nextToken
                indexedCount = totalIndexed
                
            } while pageToken != nil && totalIndexed < maxPhotos
            
            print("GooglePhotosService: Indexed \(totalIndexed) geotagged photos")
            
        } catch {
            print("GooglePhotosService: Error building index: \(error)")
        }
    }
    
    // MARK: - Query
    
    /// Find Google Photos near a location
    func findMemories(near location: CLLocation, radius: CLLocationDistance = 50) -> [GooglePhotoMemory] {
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
        
        var memories: [GooglePhotoMemory] = []
        
        for id in candidateIds {
            guard let cached = photoCache[id] else { continue }
            
            let photoLocation = CLLocation(latitude: cached.coordinate.latitude, longitude: cached.coordinate.longitude)
            let distance = location.distance(from: photoLocation)
            
            if distance <= radius {
                memories.append(GooglePhotoMemory(
                    id: id,
                    baseUrl: cached.baseUrl,
                    thumbnailUrl: "\(cached.baseUrl)=w400-h400-c",
                    coordinate: cached.coordinate,
                    captureDate: cached.date,
                    width: cached.width,
                    height: cached.height,
                    distanceMeters: distance
                ))
            }
        }
        
        return memories.sorted { ($0.distanceMeters ?? 0) < ($1.distanceMeters ?? 0) }
    }
    
    // MARK: - Private API
    
    private func fetchMediaItems(pageToken: String? = nil) async throws -> (items: [[String: Any]], nextPageToken: String?) {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GooglePhotosError.notSignedIn
        }
        
        // Force refresh token to get latest scopes
        do {
            try await user.refreshTokensIfNeeded()
        } catch {
            print("GooglePhotosService: Token refresh failed: \(error)")
        }
        
        let accessToken = user.accessToken.tokenString
        print("GooglePhotosService: Using token (first 20 chars): \(String(accessToken.prefix(20)))...")
        
        var urlString = "\(apiBaseUrl)/mediaItems?pageSize=100"
        if let token = pageToken {
            urlString += "&pageToken=\(token)"
        }
        
        guard let url = URL(string: urlString) else {
            throw GooglePhotosError.invalidUrl
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GooglePhotosError.apiError
        }
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            print("GooglePhotosService: API Error \(httpResponse.statusCode): \(errorBody)")
            throw GooglePhotosError.apiError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GooglePhotosError.parseError
        }
        
        let items = json["mediaItems"] as? [[String: Any]] ?? []
        let nextToken = json["nextPageToken"] as? String
        
        return (items, nextToken)
    }
    
    private func parseMediaItem(_ item: [String: Any]) -> GooglePhotoMemory? {
        guard let id = item["id"] as? String,
              let baseUrl = item["baseUrl"] as? String,
              let metadata = item["mediaMetadata"] as? [String: Any],
              let creationTime = metadata["creationTime"] as? String else {
            return nil
        }
        
        // Parse location if available
        guard let photo = metadata["photo"] as? [String: Any],
              let location = photo["gpsLocation"] as? [String: Any],
              let lat = location["latitude"] as? Double,
              let lon = location["longitude"] as? Double else {
            // No location data
            return nil
        }
        
        // Parse dimensions
        let width = Int(item["mediaMetadata.width"] as? String ?? "0") ?? 
                    (metadata["width"] as? String).flatMap { Int($0) } ?? 0
        let height = Int(item["mediaMetadata.height"] as? String ?? "0") ?? 
                     (metadata["height"] as? String).flatMap { Int($0) } ?? 0
        
        // Parse date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: creationTime) ?? Date()
        
        return GooglePhotoMemory(
            id: id,
            baseUrl: baseUrl,
            thumbnailUrl: "\(baseUrl)=w400-h400-c",
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            captureDate: date,
            width: width,
            height: height,
            distanceMeters: nil
        )
    }
    
    private func indexPhoto(_ photo: GooglePhotoMemory) {
        let key = gridKey(lat: photo.coordinate.latitude, lon: photo.coordinate.longitude)
        
        if spatialGrid[key] == nil {
            spatialGrid[key] = []
        }
        spatialGrid[key]?.insert(photo.id)
        
        photoCache[photo.id] = (
            coordinate: photo.coordinate,
            date: photo.captureDate,
            baseUrl: photo.baseUrl,
            width: photo.width,
            height: photo.height
        )
    }
    
    private func gridKey(lat: Double, lon: Double) -> String {
        let latCell = Int(floor(lat / gridResolution))
        let lonCell = Int(floor(lon / gridResolution))
        return "g_\(latCell)_\(lonCell)"
    }
}

// MARK: - Errors

enum GooglePhotosError: Error, LocalizedError {
    case noRootViewController
    case notSignedIn
    case noAccessToken
    case invalidUrl
    case apiError
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .noRootViewController: return "Cannot present sign-in"
        case .notSignedIn: return "Not signed in to Google"
        case .noAccessToken: return "No access token available"
        case .invalidUrl: return "Invalid API URL"
        case .apiError: return "Google Photos API error"
        case .parseError: return "Failed to parse response"
        }
    }
}
