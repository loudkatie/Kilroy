//
//  KilroyTheme.swift
//  Kilroy
//
//  Design system for Kilroy — white-first, whisper-quiet, memories ARE the interface.
//  Inspired by Jony Ive's philosophy: remove until it breaks, then add back one thing.
//

import SwiftUI

// MARK: - Colors

extension Color {
    
    // Primary palette — white canvas, dark text
    static let kilroyBackground = Color.white
    static let kilroyText = Color(hex: "1A1A1A")
    static let kilroyTextSecondary = Color(hex: "8E8E93")
    
    // Surface colors
    static let kilroySurface = Color(hex: "F5F5F7")
    static let kilroySurfaceElevated = Color.white
    
    // Brand gradient
    static let kilroyPurple = Color(hex: "7B2FBE")
    static let kilroyCyan = Color(hex: "00D4FF")
    
    // Semantic colors
    static let kilroyActive = Color(hex: "7B2FBE")
    static let kilroySubtle = Color(hex: "E5E5EA")
    
    // Circle colors (privacy levels)
    static let circleMe = Color(hex: "8E8E93")
    static let circleFamily = Color(hex: "FF9500")
    static let circleFriends = Color(hex: "007AFF")
    static let circlePublic = Color(hex: "34C759")
    static let circleLegacy = Color(hex: "AF52DE")
}

// MARK: - Hex Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Gradients

extension LinearGradient {
    static let kilroyGradient = LinearGradient(
        colors: [.kilroyPurple, .kilroyCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let kilroyGradientVertical = LinearGradient(
        colors: [.kilroyPurple, .kilroyCyan],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let kilroyGradientSubtle = LinearGradient(
        colors: [.kilroyPurple.opacity(0.1), .kilroyCyan.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Typography

extension Font {
    
    // Display — for big moments
    static let kilroyLargeTitle = Font.system(size: 34, weight: .bold, design: .default)
    
    // Headlines
    static let kilroyHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    
    // Body text
    static let kilroyBody = Font.system(size: 17, weight: .regular, design: .default)
    
    // Secondary/metadata
    static let kilroyCaption = Font.system(size: 13, weight: .regular, design: .default)
    static let kilroyCaptionMedium = Font.system(size: 13, weight: .medium, design: .default)
    
    // Whisper text — slightly smaller, intimate
    static let kilroyWhisper = Font.system(size: 15, weight: .regular, design: .default)
    
    // Timestamp
    static let kilroyTimestamp = Font.system(size: 12, weight: .regular, design: .default)
}

// MARK: - Spacing

enum KilroySpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

enum KilroyRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Shadows

extension View {
    func kilroyShadow() -> some View {
        self.shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    func kilroyShadowSubtle() -> some View {
        self.shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Animation

extension Animation {
    static let kilroySpring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let kilroyGentle = Animation.easeInOut(duration: 0.3)
    static let kilroyQuick = Animation.easeOut(duration: 0.15)
}

// MARK: - KilroyTheme Namespace

/// Convenient namespace for accessing theme values
enum KilroyTheme {
    // Colors
    static let background = Color.kilroyBackground
    static let surface = Color.kilroySurface
    static let textPrimary = Color.kilroyText
    static let textSecondary = Color.kilroyTextSecondary
    static let purple = Color.kilroyPurple
    static let cyan = Color.kilroyCyan
    
    // Gradient
    static let brandGradient = LinearGradient.kilroyGradient
    
    // Typography
    static let largeTitle = Font.kilroyLargeTitle
    static let headline = Font.kilroyHeadline
    static let body = Font.kilroyBody
    static let caption = Font.kilroyCaption
    static let whisper = Font.kilroyWhisper
    static let timestamp = Font.kilroyTimestamp
}
