//
//  PulseRing.swift
//  Kilroy
//
//  Animated ring that pulses when memories are nearby.
//  The heart of the ambient interface.
//

import SwiftUI

struct PulseRing: View {
    
    let isActive: Bool
    let count: Int
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // Outer pulse (only when active)
            if isActive {
                Circle()
                    .stroke(LinearGradient.kilroyGradient, lineWidth: 2)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
            }
            
            // Inner ring
            Circle()
                .stroke(
                    isActive ? LinearGradient.kilroyGradient : LinearGradient(colors: [.kilroySubtle], startPoint: .top, endPoint: .bottom),
                    lineWidth: isActive ? 3 : 2
                )
            
            // Count badge (if active)
            if isActive && count > 0 {
                Text("\(count)")
                    .font(.kilroyCaptionMedium)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(LinearGradient.kilroyGradient)
                    .clipShape(Circle())
                    .offset(x: 28, y: -28)
            }
        }
        .onAppear {
            if isActive {
                startPulsing()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startPulsing()
            } else {
                stopPulsing()
            }
        }
    }
    
    private func startPulsing() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.3
            pulseOpacity = 0.0
        }
    }
    
    private func stopPulsing() {
        withAnimation(.kilroyGentle) {
            pulseScale = 1.0
            pulseOpacity = 0.6
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        PulseRing(isActive: false, count: 0)
            .frame(width: 80, height: 80)
        
        PulseRing(isActive: true, count: 3)
            .frame(width: 80, height: 80)
    }
    .padding()
}
