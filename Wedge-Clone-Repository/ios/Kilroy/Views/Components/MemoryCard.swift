//
//  MemoryCard.swift
//  Kilroy
//
//  A memory surfaced from the past — soft, floating, touchable.
//

import SwiftUI
import Photos

struct MemoryCard: View {
    
    let memory: LocalMemory
    @State private var image: UIImage?
    
    var body: some View {
        VStack(alignment: .leading, spacing: KilroySpacing.sm) {
            // Image
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.kilroySurface)
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
            
            // Metadata
            HStack {
                Text(memory.age)
                    .font(.kilroyTimestamp)
                    .foregroundColor(.kilroyTextSecondary)
                
                Spacer()
                
                if memory.yearsAgo > 0 {
                    Text("\(memory.yearsAgo) years ago")
                        .font(.kilroyTimestamp)
                        .foregroundColor(.kilroyPurple)
                }
            }
        }
        .padding(KilroySpacing.sm)
        .background(Color.kilroySurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.lg))
        .kilroyShadowSubtle()
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        let size = CGSize(width: 400, height: 400)
        
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: memory.asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                if let result = result {
                    Task { @MainActor in
                        self.image = result
                    }
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - Kilroy Memory Card (for shared Kilroys)

struct KilroyCard: View {
    
    let memory: KilroyMemory
    
    var body: some View {
        VStack(alignment: .leading, spacing: KilroySpacing.sm) {
            // Image placeholder (would load from CloudKit)
            ZStack {
                Rectangle()
                    .fill(LinearGradient.kilroyGradientSubtle)
                
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(.kilroyPurple.opacity(0.5))
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
            
            // Caption
            if let caption = memory.caption {
                Text(caption)
                    .font(.kilroyBody)
                    .foregroundColor(.kilroyText)
                    .lineLimit(2)
            }
            
            // Metadata row
            HStack {
                // Circle indicator
                Image(systemName: memory.circle.icon)
                    .font(.system(size: 12))
                    .foregroundColor(memory.circle.color)
                
                Text(memory.age)
                    .font(.kilroyTimestamp)
                    .foregroundColor(.kilroyTextSecondary)
                
                Spacer()
                
                if let place = memory.placeName {
                    Text(place)
                        .font(.kilroyTimestamp)
                        .foregroundColor(.kilroyTextSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(KilroySpacing.sm)
        .background(Color.kilroySurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.lg))
        .kilroyShadowSubtle()
    }
}
