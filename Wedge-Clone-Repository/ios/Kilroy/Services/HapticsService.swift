//
//  HapticsService.swift
//  Kilroy
//
//  Tactile language for Kilroy moments.
//  Each memory type has a distinct haptic signature.
//

import Foundation
import CoreHaptics
import UIKit

@MainActor
final class HapticsService: ObservableObject {
    
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    
    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        setupEngine()
    }
    
    private func setupEngine() {
        guard supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            engine?.playsHapticsOnly = true
            engine?.isAutoShutdownEnabled = true
            
            engine?.resetHandler = { [weak self] in
                do {
                    try self?.engine?.start()
                } catch {
                    print("HapticsService: Failed to restart engine")
                }
            }
        } catch {
            print("HapticsService: Failed to create engine: \(error)")
        }
    }
    
    // MARK: - Public Haptic Patterns
    
    /// Gentle tap — you're approaching a Kilroy
    func approachTap() {
        guard supportsHaptics else {
            simpleFallback(.light)
            return
        }
        
        do {
            try engine?.start()
            
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            simpleFallback(.light)
        }
    }
    
    /// Warm pulse — memory nearby
    func memoryPulse() {
        guard supportsHaptics else {
            simpleFallback(.medium)
            return
        }
        
        do {
            try engine?.start()
            
            let events = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0,
                    duration: 0.3
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.35,
                    duration: 0.2
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            simpleFallback(.medium)
        }
    }
    
    /// Success — action completed
    func success() {
        guard supportsHaptics else {
            simpleFallback(.heavy)
            return
        }
        
        do {
            try engine?.start()
            
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: 0.08
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.16
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            simpleFallback(.heavy)
        }
    }
    
    /// Notification tap
    func notification() {
        guard supportsHaptics else {
            simpleFallback(.medium)
            return
        }
        
        do {
            try engine?.start()
            
            let events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                    ],
                    relativeTime: 0.1,
                    duration: 0.15
                )
            ]
            
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            simpleFallback(.medium)
        }
    }
    
    // MARK: - Private
    
    private func simpleFallback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
