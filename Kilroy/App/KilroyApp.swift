//
//  KilroyApp.swift
//  Kilroy
//
//  Your memories. At the places they happened.
//

import SwiftUI
import GoogleSignIn

@main
struct KilroyApp: App {
    
    @StateObject private var locationService = LocationService()
    @StateObject private var photosService = PhotosService()
    @StateObject private var googlePhotosService = GooglePhotosService()
    @StateObject private var memoryStore = MemoryStore()
    @StateObject private var hapticsService = HapticsService()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if hasCompletedOnboarding && !showingSplash {
                    // Main app — single screen, full-bleed map
                    HomeView()
                        .environmentObject(locationService)
                        .environmentObject(photosService)
                        .environmentObject(googlePhotosService)
                        .environmentObject(memoryStore)
                        .environmentObject(hapticsService)
                        .onOpenURL { url in
                            GIDSignIn.sharedInstance.handle(url)
                        }
                } else if !hasCompletedOnboarding && !showingSplash {
                    // First-time onboarding
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                    .environmentObject(locationService)
                    .environmentObject(photosService)
                    .environmentObject(googlePhotosService)
                    .environmentObject(memoryStore)
                    .environmentObject(hapticsService)
                }
                
                // Splash screen — shows every app open
                if showingSplash {
                    SplashView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSplash = false
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showingSplash)
        }
    }
}
