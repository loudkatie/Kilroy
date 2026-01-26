//
//  AIAgentService.swift
//  Kilroy
//
//  Your personal Contextual AI agent — born when you create an account,
//  learns everything about you, and proactively taps you when there's
//  content for you at your current location.
//
//  This is the soul of Contextual: an AI that navigates the world FOR you.
//

import Foundation
import CoreLocation

/// The user's personal AI agent that learns and proactively discovers content
@MainActor
final class AIAgentService: ObservableObject {
    
    static let shared = AIAgentService()
    
    // MARK: - Published State
    
    @Published var isInitialized: Bool = false
    @Published var lastMessage: AgentMessage?
    @Published var conversationHistory: [AgentMessage] = []
    @Published var isThinking: Bool = false
    @Published var pendingDiscovery: DiscoveryNotification?
    
    // MARK: - Configuration
    
    private let openAIAPIKey: String? = nil  // TODO: Add via environment or secure storage
    private let assistantId: String? = nil   // TODO: Create OpenAI Assistant for Kilroy
    private var threadId: String?            // Persistent conversation thread
    
    // MARK: - User Context
    
    private var userProfile: UserProfile?
    
    private init() {
        loadPersistedThread()
    }
    
    // MARK: - Initialization
    
    /// Initialize the AI agent for a user (called on first launch or account creation)
    func initializeAgent() async {
        // For now, create a local agent without OpenAI
        // When API key is added, this will create a persistent thread
        
        userProfile = UserProfile(
            deviceId: getDeviceId(),
            createdAt: Date(),
            preferences: [:]
        )
        
        // Welcome message
        let welcome = AgentMessage(
            role: .assistant,
            content: "👋 Hey! I'm your Kilroy guide. I'll tap you when there are hidden memories nearby. Walk around — I'm watching for easter eggs at your location.",
            timestamp: Date()
        )
        conversationHistory.append(welcome)
        lastMessage = welcome
        isInitialized = true
        
        persistThread()
    }
    
    // MARK: - Proactive Discovery
    
    /// Called when user enters a location with Kilroys
    func notifyDiscovery(kilroys: [CloudKilroy], at location: CLLocation) {
        guard !kilroys.isEmpty else { return }
        
        let count = kilroys.count
        let placeName = kilroys.first?.placeName ?? "this spot"
        
        // Build contextual message
        let message: String
        if count == 1 {
            let kilroy = kilroys[0]
            let timeAgo = kilroy.createdAt.timeAgoString()
            message = "🎯 Found something! Someone left a memory at \(placeName) \(timeAgo). Tap to discover."
        } else {
            message = "🎯 \(count) hidden memories at \(placeName). You're standing in a special spot."
        }
        
        let agentMessage = AgentMessage(
            role: .assistant,
            content: message,
            timestamp: Date(),
            associatedKilroys: kilroys
        )
        
        conversationHistory.append(agentMessage)
        lastMessage = agentMessage
        
        pendingDiscovery = DiscoveryNotification(
            kilroys: kilroys,
            message: message,
            location: location
        )
    }
    
    /// User asks the agent something
    func sendMessage(_ text: String) async {
        let userMessage = AgentMessage(
            role: .user,
            content: text,
            timestamp: Date()
        )
        conversationHistory.append(userMessage)
        
        isThinking = true
        
        // For now, simple local responses
        // TODO: Replace with OpenAI API call when integrated
        let response = generateLocalResponse(to: text)
        
        try? await Task.sleep(nanoseconds: 500_000_000) // Simulate thinking
        
        let agentMessage = AgentMessage(
            role: .assistant,
            content: response,
            timestamp: Date()
        )
        conversationHistory.append(agentMessage)
        lastMessage = agentMessage
        isThinking = false
        
        persistThread()
    }
    
    // MARK: - Local Response Generation (pre-OpenAI)
    
    private func generateLocalResponse(to input: String) -> String {
        let lowercased = input.lowercased()
        
        if lowercased.contains("what") && lowercased.contains("kilroy") {
            return "Kilroys are hidden memories people leave at specific spots. Photos, audio, notes — all tied to exact locations. When you're in the right place, you'll see what others left there. It's like a secret layer on top of the real world."
        }
        
        if lowercased.contains("how") && (lowercased.contains("drop") || lowercased.contains("leave")) {
            return "Tap the camera button to capture a moment. Add a note if you want, then drop it. It'll be pinned to your exact spot — others will only see it when they're standing right there."
        }
        
        if lowercased.contains("where") || lowercased.contains("nearby") {
            return "I'm constantly scanning your location for hidden content. When I find something, I'll tap you. Keep exploring!"
        }
        
        if lowercased.contains("who") && lowercased.contains("see") {
            return "Right now, everyone can see everything — we're in alpha testing. Eventually, you'll be able to gate content to specific groups: friends, team members, loyalty club members."
        }
        
        if lowercased.contains("floor") || lowercased.contains("height") {
            return "Kilroys are pinned to height too, not just lat/long. Content on the 9th floor won't show up in the lobby. I use your phone's altimeter to know which floor you're on."
        }
        
        return "I'm here to help you discover hidden memories. Walk around and I'll tap you when there's something at your location. Or drop your own Kilroy for others to find!"
    }
    
    // MARK: - Persistence
    
    private func loadPersistedThread() {
        if let threadData = UserDefaults.standard.data(forKey: "ai_agent_thread"),
           let thread = try? JSONDecoder().decode(PersistedThread.self, from: threadData) {
            self.threadId = thread.threadId
            self.conversationHistory = thread.messages
            self.lastMessage = thread.messages.last
            self.isInitialized = true
        }
    }
    
    private func persistThread() {
        let thread = PersistedThread(
            threadId: threadId,
            messages: conversationHistory
        )
        if let data = try? JSONEncoder().encode(thread) {
            UserDefaults.standard.set(data, forKey: "ai_agent_thread")
        }
    }
    
    private func getDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: "kilroy_device_id") {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "kilroy_device_id")
        return newId
    }
}

// MARK: - Supporting Models

struct AgentMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    var associatedKilroys: [CloudKilroy]?
    
    init(role: MessageRole, content: String, timestamp: Date, associatedKilroys: [CloudKilroy]? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.associatedKilroys = associatedKilroys
    }
    
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp
        // Don't persist associatedKilroys
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

struct UserProfile: Codable {
    let deviceId: String
    let createdAt: Date
    var preferences: [String: String]
}

struct DiscoveryNotification {
    let kilroys: [CloudKilroy]
    let message: String
    let location: CLLocation
}

struct PersistedThread: Codable {
    let threadId: String?
    let messages: [AgentMessage]
}

// MARK: - Date Extension

extension Date {
    func timeAgoString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
