//
//  CircleSelector.swift
//  Kilroy
//
//  Privacy circle picker — who can see this Kilroy?
//

import SwiftUI

struct CircleSelector: View {
    
    @Binding var selected: PrivacyCircle
    
    var body: some View {
        HStack(spacing: KilroySpacing.md) {
            ForEach(PrivacyCircle.allCases, id: \.self) { circle in
                CircleButton(
                    circle: circle,
                    isSelected: selected == circle
                ) {
                    withAnimation(.kilroySpring) {
                        selected = circle
                    }
                }
            }
        }
    }
}

struct CircleButton: View {
    
    let circle: PrivacyCircle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: KilroySpacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? circle.color : Color.kilroySurface)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: circle.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isSelected ? .white : .kilroyTextSecondary)
                }
                
                Text(circle.rawValue.components(separatedBy: " ").first ?? "")
                    .font(.kilroyCaption)
                    .foregroundColor(isSelected ? circle.color : .kilroyTextSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var selected: PrivacyCircle = .friends
        
        var body: some View {
            CircleSelector(selected: $selected)
                .padding()
        }
    }
    
    return PreviewWrapper()
}
