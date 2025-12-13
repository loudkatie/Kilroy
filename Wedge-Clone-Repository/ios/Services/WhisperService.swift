//
//  WhisperService.swift
//  Kilroy
//
//  Spatial audio whispers via AirPods.
//  "You have memories here."
//

import Foundation
import AVFoundation

@MainActor
final class WhisperService: NSObject, ObservableObject {
    
    @Published var isWhispering: Bool = false
    @Published var lastWhisper: String?
    
    private let synthesizer = AVSpeechSynthesizer()
    private var lastWhisperTime: Date?
    
    /// Minimum seconds between whispers
    private let cooldownSeconds: TimeInterval = 30
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        } catch {
            print("WhisperService: Audio session config failed: \(error)")
        }
    }
    
    // MARK: - Public API
    
    /// Whisper a message (respects cooldown)
    func whisper(_ message: String) {
        guard canWhisper() else { return }
        deliver(message)
    }
    
    /// Whisper about nearby memories
    func whisperNearby(count: Int, oldestYears: Int?) {
        guard canWhisper() else { return }
        
        let message: String
        if let years = oldestYears, years > 0 {
            if count == 1 {
                message = "A memory from \(years) years ago."
            } else {
                message = "\(count) memories here. The oldest from \(years) years ago."
            }
        } else {
            message = count == 1 ? "A memory nearby." : "\(count) memories nearby."
        }
        
        deliver(message)
    }
    
    /// Stop any current whisper
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isWhispering = false
    }
    
    // MARK: - Private
    
    private func canWhisper() -> Bool {
        guard let last = lastWhisperTime else { return true }
        return Date().timeIntervalSince(last) >= cooldownSeconds
    }
    
    private func deliver(_ message: String) {
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = 0.45
        utterance.pitchMultiplier = 0.95
        utterance.volume = 0.8
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        // Use Siri voice if available
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        lastWhisper = message
        lastWhisperTime = Date()
        isWhispering = true
        
        synthesizer.speak(utterance)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension WhisperService: AVSpeechSynthesizerDelegate {
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isWhispering = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isWhispering = false
        }
    }
}
