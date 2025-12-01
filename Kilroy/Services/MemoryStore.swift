//
//  MemoryStore.swift
//  Kilroy
//
//  Persists dropped memories locally.
//  Stores images in Documents, metadata in JSON.
//

import Foundation
import UIKit
import CoreLocation

@MainActor
final class MemoryStore: ObservableObject {
    
    @Published private(set) var memories: [DroppedMemory] = []
    
    private let fileManager = FileManager.default
    private var memoriesURL: URL {
        documentsDirectory.appendingPathComponent("memories.json")
    }
    private var imagesDirectory: URL {
        documentsDirectory.appendingPathComponent("MemoryImages", isDirectory: true)
    }
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    init() {
        createImagesDirectoryIfNeeded()
        loadMemories()
    }
    
    // MARK: - Public
    
    /// Save a new memory with image
    func saveMemory(
        image: UIImage,
        coordinate: CLLocationCoordinate2D,
        comment: String?,
        placeName: String?,
        placeAddress: String?
    ) -> DroppedMemory? {
        let id = UUID()
        let filename = "\(id.uuidString).jpg"
        
        // Save image
        guard saveImage(image, filename: filename) else {
            print("MemoryStore: Failed to save image")
            return nil
        }
        
        let memory = DroppedMemory(
            id: id,
            coordinate: CodableCoordinate(coordinate),
            capturedAt: Date(),
            imageFilename: filename,
            comment: comment?.isEmpty == true ? nil : comment,
            placeName: placeName,
            placeAddress: placeAddress
        )
        
        memories.insert(memory, at: 0)
        persistMemories()
        
        print("MemoryStore: Saved memory at \(placeName ?? "unknown location")")
        return memory
    }
    
    /// Load image for a memory
    func loadImage(for memory: DroppedMemory) -> UIImage? {
        let url = imagesDirectory.appendingPathComponent(memory.imageFilename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    /// Find memories near a location
    func memoriesNear(_ location: CLLocation, radius: Double = 50) -> [DroppedMemory] {
        memories.filter { memory in
            let memoryLocation = memory.location
            return location.distance(from: memoryLocation) <= radius
        }
    }
    
    /// Delete a memory
    func deleteMemory(_ memory: DroppedMemory) {
        // Remove image
        let imageURL = imagesDirectory.appendingPathComponent(memory.imageFilename)
        try? fileManager.removeItem(at: imageURL)
        
        // Remove from array
        memories.removeAll { $0.id == memory.id }
        persistMemories()
    }
    
    // MARK: - Private
    
    private func createImagesDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: imagesDirectory.path) {
            try? fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func saveImage(_ image: UIImage, filename: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
        let url = imagesDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return true
        } catch {
            print("MemoryStore: Error saving image: \(error)")
            return false
        }
    }
    
    private func loadMemories() {
        guard fileManager.fileExists(atPath: memoriesURL.path) else { return }
        do {
            let data = try Data(contentsOf: memoriesURL)
            memories = try JSONDecoder().decode([DroppedMemory].self, from: data)
            print("MemoryStore: Loaded \(memories.count) memories")
        } catch {
            print("MemoryStore: Error loading memories: \(error)")
        }
    }
    
    private func persistMemories() {
        do {
            let data = try JSONEncoder().encode(memories)
            try data.write(to: memoriesURL)
        } catch {
            print("MemoryStore: Error persisting memories: \(error)")
        }
    }
}
