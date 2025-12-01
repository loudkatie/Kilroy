//
//  MemoryDetailView.swift
//  Kilroy
//
//  Full-screen memory reveal. Just the photo. Just the moment.
//

import SwiftUI
import Photos

struct MemoryDetailView: View {
    
    let memory: LocalMemory
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showingInfo: Bool = true
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                // Image
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .tint(.white)
                }
                
                // Overlay info (tap to toggle)
                if showingInfo {
                    VStack {
                        // Top bar
                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, KilroySpacing.lg)
                        .padding(.top, KilroySpacing.lg)
                        
                        Spacer()
                        
                        // Bottom info
                        VStack(spacing: KilroySpacing.xs) {
                            Text(memory.age)
                                .font(.kilroyHeadline)
                                .foregroundColor(.white)
                            
                            if memory.yearsAgo > 0 {
                                Text("\(memory.yearsAgo) years ago")
                                    .font(.kilroyCaption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.vertical, KilroySpacing.lg)
                        .padding(.horizontal, KilroySpacing.xl)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .onTapGesture {
                withAnimation(.kilroyGentle) {
                    showingInfo.toggle()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismiss()
                        }
                    }
            )
        }
        .task {
            await loadFullImage()
        }
    }
    
    private func loadFullImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        // Request full size
        let size = PHImageManagerMaximumSize
        
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: memory.asset,
                targetSize: size,
                contentMode: .aspectFit,
                options: options
            ) { result, info in
                if let result = result {
                    Task { @MainActor in
                        self.image = result
                    }
                }
                
                // Only resume once (high quality callback)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume()
                }
            }
        }
    }
}
