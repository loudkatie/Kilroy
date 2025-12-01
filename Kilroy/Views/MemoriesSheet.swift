//
//  MemoriesSheet.swift
//  Kilroy
//
//  Shows nearby memories when the user taps the pulse ring.
//

import SwiftUI

struct MemoriesSheet: View {
    
    let photoMemories: [LocalMemory]
    let googleMemories: [GooglePhotoMemory]
    let droppedMemories: [DroppedMemory]
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var memoryStore: MemoryStore
    @State private var selectedDroppedMemory: DroppedMemory?
    @State private var selectedPhotoMemory: LocalMemory?
    @State private var selectedGoogleMemory: GooglePhotoMemory?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: KilroySpacing.md) {
                    // Dropped Kilroys section
                    if !droppedMemories.isEmpty {
                        Section {
                            ForEach(droppedMemories) { memory in
                                DroppedMemoryCard(
                                    memory: memory,
                                    image: memoryStore.loadImage(for: memory)
                                )
                                .onTapGesture {
                                    selectedDroppedMemory = memory
                                }
                            }
                        } header: {
                            sectionHeader("Kilroys", icon: "mappin.circle.fill")
                        }
                    }
                    
                    // Apple Photos section
                    if !photoMemories.isEmpty {
                        Section {
                            ForEach(photoMemories) { memory in
                                MemoryCard(memory: memory)
                                    .onTapGesture {
                                        selectedPhotoMemory = memory
                                    }
                            }
                        } header: {
                            sectionHeader("Apple Photos", icon: "photo.fill")
                        }
                    }
                    
                    // Google Photos section
                    if !googleMemories.isEmpty {
                        Section {
                            ForEach(googleMemories) { memory in
                                GoogleMemoryCard(memory: memory)
                                    .onTapGesture {
                                        selectedGoogleMemory = memory
                                    }
                            }
                        } header: {
                            sectionHeader("Google Photos", icon: "g.circle.fill", iconColor: .red)
                        }
                    }
                }
                .padding()
            }
            .background(KilroyTheme.background)
            .navigationTitle("Memories Here")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(KilroyTheme.brandGradient)
                }
            }
            .sheet(item: $selectedDroppedMemory) { memory in
                DroppedMemoryDetailView(
                    memory: memory,
                    image: memoryStore.loadImage(for: memory)
                )
            }
            .sheet(item: $selectedPhotoMemory) { memory in
                MemoryDetailView(memory: memory)
            }
            .sheet(item: $selectedGoogleMemory) { memory in
                GoogleMemoryDetailView(memory: memory)
            }
        }
    }
    
    private func sectionHeader(_ title: String, icon: String, iconColor: Color? = nil) -> some View {
        HStack(spacing: 8) {
            if let color = iconColor {
                Image(systemName: icon)
                    .foregroundColor(color)
            } else {
                Image(systemName: icon)
                    .foregroundStyle(KilroyTheme.brandGradient)
            }
            Text(title)
                .font(KilroyTheme.caption.weight(.semibold))
                .foregroundColor(KilroyTheme.textSecondary)
            Spacer()
        }
        .padding(.top, KilroySpacing.sm)
    }
}

// MARK: - Google Memory Card

struct GoogleMemoryCard: View {
    let memory: GooglePhotoMemory
    
    var body: some View {
        HStack(spacing: KilroySpacing.md) {
            // Thumbnail from URL
            AsyncImage(url: URL(string: memory.thumbnailUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.kilroySurface
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.kilroyTextSecondary)
                        }
                case .empty:
                    Color.kilroySurface
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                @unknown default:
                    Color.kilroySurface
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.age)
                    .font(KilroyTheme.body.weight(.medium))
                    .foregroundColor(KilroyTheme.textPrimary)
                
                if let distance = memory.distanceMeters {
                    Text("\(Int(distance))m away")
                        .font(KilroyTheme.caption)
                        .foregroundColor(KilroyTheme.textSecondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "g.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text("Google Photos")
                        .font(KilroyTheme.whisper)
                        .foregroundColor(KilroyTheme.textSecondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KilroyTheme.textSecondary)
        }
        .padding(KilroySpacing.md)
        .background(KilroyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.lg))
    }
}

// MARK: - Google Memory Detail View

struct GoogleMemoryDetailView: View {
    let memory: GooglePhotoMemory
    
    @Environment(\.dismiss) private var dismiss
    @State private var showInfo = true
    
    // Full resolution URL
    private var fullResUrl: String {
        "\(memory.baseUrl)=w\(memory.width)-h\(memory.height)"
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: URL(string: fullResUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Failed to load")
                            .font(.kilroyCaption)
                    }
                    .foregroundColor(.white.opacity(0.6))
                case .empty:
                    ProgressView()
                        .tint(.white)
                @unknown default:
                    EmptyView()
                }
            }
            .onTapGesture {
                withAnimation(.kilroyGentle) {
                    showInfo.toggle()
                }
            }
            
            // Info overlay
            if showInfo {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(memory.age)
                            .font(KilroyTheme.body.weight(.medium))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "g.circle.fill")
                                .foregroundColor(.red)
                            Text("Google Photos")
                                .font(KilroyTheme.caption)
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
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
}

// MARK: - Dropped Memory Card

struct DroppedMemoryCard: View {
    let memory: DroppedMemory
    let image: UIImage?
    
    var body: some View {
        HStack(spacing: KilroySpacing.md) {
            // Thumbnail
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.md))
            } else {
                RoundedRectangle(cornerRadius: KilroyRadius.md)
                    .fill(KilroyTheme.surface)
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(KilroyTheme.textSecondary)
                    }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                if let place = memory.placeName {
                    Text(place)
                        .font(KilroyTheme.body.weight(.medium))
                        .foregroundColor(KilroyTheme.textPrimary)
                }
                
                if let comment = memory.comment {
                    Text(comment)
                        .font(KilroyTheme.caption)
                        .foregroundColor(KilroyTheme.textSecondary)
                        .lineLimit(2)
                }
                
                Text(memory.formattedDate)
                    .font(KilroyTheme.whisper)
                    .foregroundColor(KilroyTheme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KilroyTheme.textSecondary)
        }
        .padding(KilroySpacing.md)
        .background(KilroyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: KilroyRadius.lg))
    }
}

// MARK: - Dropped Memory Detail View

struct DroppedMemoryDetailView: View {
    let memory: DroppedMemory
    let image: UIImage?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showInfo = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .onTapGesture {
                        withAnimation(.kilroyGentle) {
                            showInfo.toggle()
                        }
                    }
            }
            
            // Info overlay
            if showInfo {
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        if let place = memory.placeName {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(KilroyTheme.brandGradient)
                                Text(place)
                                    .font(KilroyTheme.body.weight(.medium))
                            }
                        }
                        
                        if let comment = memory.comment {
                            Text(comment)
                                .font(KilroyTheme.body)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Text(memory.formattedDate)
                            .font(KilroyTheme.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
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
}
