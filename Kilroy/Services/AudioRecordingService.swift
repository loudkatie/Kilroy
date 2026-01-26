//
//  AudioRecordingService.swift
//  Kilroy
//
//  Records audio messages/memories to be dropped at locations.
//  Voice notes, ambient sounds, whispered secrets — all anchored in place.
//

import Foundation
import AVFoundation

@MainActor
final class AudioRecordingService: NSObject, ObservableObject {
    
    static let shared = AudioRecordingService()
    
    // MARK: - Published State
    
    @Published var isRecording: Bool = false
    @Published var isPrepared: Bool = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var recordedAudioURL: URL?
    @Published var recordedAudioData: Data?
    @Published var errorMessage: String?
    
    // MARK: - Private
    
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    
    // Max recording duration (seconds)
    private let maxDuration: TimeInterval = 60.0
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    /// Request microphone permission and prepare for recording
    func prepare() async -> Bool {
        // Check/request permission
        let permission = await AVAudioApplication.requestRecordPermission()
        
        guard permission else {
            errorMessage = "Microphone access is required to record audio Kilroys"
            return false
        }
        
        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            isPrepared = true
            return true
        } catch {
            errorMessage = "Failed to configure audio: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Recording
    
    /// Start recording audio
    func startRecording() {
        guard isPrepared else {
            errorMessage = "Audio not prepared. Call prepare() first."
            return
        }
        
        // Create temp file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "kilroy_audio_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        // Recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            recordedAudioURL = fileURL
            isRecording = true
            recordingDuration = 0
            errorMessage = nil
            
            // Start level metering
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAudioLevel()
                }
            }
            
            // Start duration timer
            durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateDuration()
                }
            }
            
            print("🎤 Recording started: \(fileURL.lastPathComponent)")
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    /// Stop recording and prepare data for upload
    func stopRecording() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        levelTimer?.invalidate()
        durationTimer?.invalidate()
        levelTimer = nil
        durationTimer = nil
        isRecording = false
        
        // Load the recorded data
        if let url = recordedAudioURL {
            do {
                recordedAudioData = try Data(contentsOf: url)
                print("🎤 Recording stopped: \(recordingDuration)s, \(recordedAudioData?.count ?? 0) bytes")
            } catch {
                errorMessage = "Failed to load recorded audio: \(error.localizedDescription)"
            }
        }
    }
    
    /// Cancel recording and discard
    func cancelRecording() {
        audioRecorder?.stop()
        levelTimer?.invalidate()
        durationTimer?.invalidate()
        levelTimer = nil
        durationTimer = nil
        isRecording = false
        
        // Delete temp file
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordedAudioURL = nil
        recordedAudioData = nil
        recordingDuration = 0
        print("🎤 Recording cancelled")
    }
    
    /// Clear the recorded audio (after upload or discard)
    func clearRecording() {
        if let url = recordedAudioURL {
            try? FileManager.default.removeItem(at: url)
        }
        recordedAudioURL = nil
        recordedAudioData = nil
        recordingDuration = 0
        audioLevel = 0
    }
    
    // MARK: - Private Helpers
    
    private func updateAudioLevel() {
        audioRecorder?.updateMeters()
        let level = audioRecorder?.averagePower(forChannel: 0) ?? -160
        // Normalize from dB (-160 to 0) to 0-1 range
        let normalizedLevel = max(0, (level + 50) / 50)
        audioLevel = normalizedLevel
    }
    
    private func updateDuration() {
        recordingDuration = audioRecorder?.currentTime ?? 0
        
        // Auto-stop at max duration
        if recordingDuration >= maxDuration {
            stopRecording()
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                errorMessage = "Recording failed"
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            errorMessage = "Recording error: \(error?.localizedDescription ?? "Unknown")"
        }
    }
}
