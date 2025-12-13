//
//  OnboardingView.swift
//  Kilroy
//
//  First-time flow: Permissions + How It Works
//  Simple, beautiful, gets out of the way.
//

import SwiftUI

enum OnboardingStep {
    case welcome
    case howItWorks1
    case howItWorks2
    case howItWorks3
    case location
    case photos
    case ready
}

struct OnboardingView: View {
    
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var photosService: PhotosService
    @EnvironmentObject var googlePhotosService: GooglePhotosService
    
    @State private var step: OnboardingStep = .welcome
    @State private var isRequestingLocation = false
    @State private var isRequestingPhotos = false
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.kilroyBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Content
                Group {
                    switch step {
                    case .welcome:
                        welcomeContent
                    case .howItWorks1:
                        howItWorks1Content
                    case .howItWorks2:
                        howItWorks2Content
                    case .howItWorks3:
                        howItWorks3Content
                    case .location:
                        locationContent
                    case .photos:
                        photosContent
                    case .ready:
                        readyContent
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Progress dots (for How It Works section)
                if [.howItWorks1, .howItWorks2, .howItWorks3].contains(step) {
                    progressDots
                        .padding(.bottom, 32)
                }
            }
        }
    }
    
    // MARK: - Welcome
    
    private var welcomeContent: some View {
        VStack(spacing: 40) {
            Image("kilroy_wordmark_large")
                .resizable()
                .scaledToFit()
                .frame(height: 60)
            
            VStack(spacing: 16) {
                Text("Leave your memories")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.kilroyText)
                
                Text("where they happened.")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(LinearGradient.kilroyGradient)
            }
            
            primaryButton("Get Started") {
                advance(to: .howItWorks1)
            }
        }
    }
    
    // MARK: - How It Works
    
    private var howItWorks1Content: some View {
        howItWorksPage(
            icon: "figure.walk",
            title: "Walk",
            subtitle: "Move through the world with Kilroy in your pocket.",
            action: { advance(to: .howItWorks2) }
        )
    }
    
    private var howItWorks2Content: some View {
        howItWorksPage(
            icon: "hand.tap.fill",
            title: "Feel the tap",
            subtitle: "When you're near a memory, your phone will gently tap you.",
            action: { advance(to: .howItWorks3) }
        )
    }
    
    private var howItWorks3Content: some View {
        howItWorksPage(
            icon: "eye.fill",
            title: "Discover",
            subtitle: "See photos from this exact spot — yours, or someone else's.",
            action: { advance(to: .location) }
        )
    }
    
    private func howItWorksPage(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .fill(Color.kilroySurface)
                    .frame(width: 120, height: 120)
                
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(LinearGradient.kilroyGradient)
            }
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.kilroyText)
                
                Text(subtitle)
                    .font(.system(size: 17))
                    .foregroundColor(.kilroyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            primaryButton("Next") {
                action()
            }
        }
    }
    
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(dotIndex == index ? Color.kilroyPurple : Color.kilroySubtle)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var dotIndex: Int {
        switch step {
        case .howItWorks1: return 0
        case .howItWorks2: return 1
        case .howItWorks3: return 2
        default: return 0
        }
    }
    
    // MARK: - Permissions
    
    private var locationContent: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .fill(Color.kilroySurface)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "location.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.kilroyGradient)
            }
            
            VStack(spacing: 12) {
                Text("Enable Location")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.kilroyText)
                
                Text("Kilroy needs your location to surface memories and let you drop new ones.")
                    .font(.kilroyBody)
                    .foregroundColor(.kilroyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            primaryButton(isRequestingLocation ? "Waiting..." : "Enable Location") {
                isRequestingLocation = true
                Task {
                    await locationService.requestAuthorization()
                    isRequestingLocation = false
                    advance(to: .photos)
                }
            }
            .disabled(isRequestingLocation)
        }
    }
    
    private var photosContent: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .fill(Color.kilroySurface)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "photo.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.kilroyGradient)
            }
            
            VStack(spacing: 12) {
                Text("Enable Photos")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.kilroyText)
                
                Text("We'll scan your photos for location data and surface them at the right places.")
                    .font(.kilroyBody)
                    .foregroundColor(.kilroyTextSecondary)
                    .multilineTextAlignment(.center)
            }
            
            primaryButton(isRequestingPhotos ? "Scanning..." : "Enable Photos") {
                isRequestingPhotos = true
                Task {
                    print("📸 Requesting photo authorization...")
                    let status = await photosService.requestAuthorization()
                    print("📸 Authorization status: \(status.rawValue)")
                    if status == .authorized || status == .limited {
                        print("📸 Calling buildIndex...")
                        await photosService.buildIndex()
                        print("📸 buildIndex complete")
                    }
                    isRequestingPhotos = false
                    advance(to: .ready)
                }
            }
            .disabled(isRequestingPhotos)
        }
    }
    
    // MARK: - Ready
    
    private var readyContent: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .fill(Color.kilroySurface)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(LinearGradient.kilroyGradient)
            }
            
            VStack(spacing: 12) {
                Text("You're ready")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.kilroyText)
                
                if photosService.indexedCount > 0 {
                    Text("Found \(photosService.indexedCount) geotagged photos. Now go walk around and discover them.")
                        .font(.kilroyBody)
                        .foregroundColor(.kilroyTextSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No geotagged photos found yet. Start dropping Kilroys to leave your mark.")
                        .font(.kilroyBody)
                        .foregroundColor(.kilroyTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            primaryButton("Start Exploring") {
                onComplete()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func advance(to nextStep: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            step = nextStep
        }
    }
    
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient.kilroyGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
