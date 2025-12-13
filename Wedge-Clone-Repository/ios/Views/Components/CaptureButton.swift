//
//  CaptureButton.swift
//  Kilroy
//
//  The shutter button — gradient ring, satisfying press.
//

import SwiftUI

struct CaptureButton: View {
    
    let action: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        Button(action: {
            action()
        }) {
            ZStack {
                // Outer gradient ring
                Circle()
                    .stroke(LinearGradient.kilroyGradient, lineWidth: 4)
                    .frame(width: 72, height: 72)
                
                // Inner white circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.kilroyQuick) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.kilroySpring) {
                        isPressed = false
                    }
                }
        )
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.8)
        CaptureButton { }
    }
}
