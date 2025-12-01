//
//  SettingsView.swift
//  Kilroy
//
//  Account settings, photo sources, preferences.
//

import SwiftUI

struct SettingsView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var photosService: PhotosService
    @EnvironmentObject var memoryStore: MemoryStore
    
    var body: some View {
        NavigationStack {
            List {
                // Stats
                Section {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(LinearGradient.kilroyGradient)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Kilroys Dropped")
                                .font(.kilroyBody)
                            Text("Memories you've left behind")
                                .font(.kilroyCaption)
                                .foregroundColor(.kilroyTextSecondary)
                        }
                        
                        Spacer()
                        
                        Text("\(memoryStore.memories.count)")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(LinearGradient.kilroyGradient)
                    }
                } header: {
                    Text("Your Kilroys")
                }
                
                // Photo Sources
                Section {
                    // Apple Photos
                    HStack {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(LinearGradient.kilroyGradient)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Photos")
                                .font(.kilroyBody)
                            Text("\(photosService.indexedCount) geotagged photos indexed")
                                .font(.kilroyCaption)
                                .foregroundColor(.kilroyTextSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                } header: {
                    Text("Photo Sources")
                } footer: {
                    Text("Your geotagged photos surface as memories when you return to where you took them.")
                }
                
                // About
                Section {
                    HStack {
                        Text("Version")
                            .font(.kilroyBody)
                        Spacer()
                        Text("1.0.0")
                            .font(.kilroyCaption)
                            .foregroundColor(.kilroyTextSecondary)
                    }
                    
                    Link(destination: URL(string: "https://loudlabs.co")!) {
                        HStack {
                            Text("Loud Labs")
                                .font(.kilroyBody)
                                .foregroundColor(.kilroyText)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.kilroyCaption)
                                .foregroundColor(.kilroyTextSecondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(LinearGradient.kilroyGradient)
                }
            }
        }
    }
}
