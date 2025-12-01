//
//  SplashView.swift
//  Kilroy
//
//  Full-screen branded splash. Sets the tone.
//

import SwiftUI

struct SplashView: View {
    
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.8
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.kilroyBackground.ignoresSafeArea()
            
            VStack(spacing: KilroySpacing.lg) {
                // Large wordmark
                Image("kilroy_wordmark_large")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .opacity(opacity)
                    .scaleEffect(scale)
            }
        }
        .onAppear {
            // Fade in
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1
                scale = 1
            }
            
            // Auto-advance after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
    }
}
