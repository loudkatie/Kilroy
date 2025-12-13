//
//  PrivacyCircle.swift
//  Kilroy
//
//  Privacy levels for Kilroy memories — who can see what you've left behind.
//

import SwiftUI

/// Privacy circle determines who can discover a Kilroy
enum PrivacyCircle: String, CaseIterable, Codable {
    case me = "Only Me"
    case family = "Family"
    case friends = "Friends"
    case `public` = "Public"
    case legacy = "Legacy"
    
    /// SF Symbol for the circle
    var icon: String {
        switch self {
        case .me: return "person.fill"
        case .family: return "house.fill"
        case .friends: return "person.2.fill"
        case .public: return "globe"
        case .legacy: return "clock.fill"
        }
    }
    
    /// Brand color for the circle
    var color: Color {
        switch self {
        case .me: return .circleMe
        case .family: return .circleFamily
        case .friends: return .circleFriends
        case .public: return .circlePublic
        case .legacy: return .circleLegacy
        }
    }
    
    /// Short description
    var description: String {
        switch self {
        case .me: return "Private to you"
        case .family: return "Your family circle"
        case .friends: return "Your friends"
        case .public: return "Anyone at this place"
        case .legacy: return "Future generations"
        }
    }
}
