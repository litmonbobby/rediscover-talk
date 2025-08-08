//
//  FamilyBreathingManager.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  SharePlay breathing session management with family coordination
//

import Foundation
import GroupActivities
import Combine
import OSLog
import SwiftUI

/// Main manager for family breathing sessions with SharePlay integration
@MainActor
class FamilyBreathingManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isSessionActive = false
    @Published var breathingState: BreathingState = .idle
    @Published var currentParticipants: [Participant] = []
    @Published var currentCycle = 0
    @Published var sessionDuration: TimeInterval = 0
    @Published var encouragementMessages: [EncouragementMessage] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "FamilyBreathingManager")
    private var groupSession: GroupSession<FamilyBreathingSession>?
    private var subscriptions = Set<AnyCancellable>()
    private var breathingTimer: Timer?
    private var sessionTimer: Timer?
    private var currentExercise: BreathingExercise = .familyDefault
    
    // MARK: - Breathing State
    
    enum BreathingState: String, CaseIterable {
        case idle = "idle"
        case inhaling = "inhaling"
        case holding = "holding"
        case exhaling = "exhaling"
        
        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .inhaling: return "Breathe In"
            case .holding: return "Hold"
            case .exhaling: return "Breathe Out"
            }
        }
    }
    
    // MARK: - Connection Status
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected(participantCount: Int)
        case failed(Error)
        
        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }
    
    // MARK: - Data Models
    
    struct Participant: Identifiable, Codable {
        let id: UUID
        let displayName: String
        let avatarData: Data?
        var breathingState: BreathingState
        var isHost: Bool
        var joinedAt: Date
        var lastActiveAt: Date
        
        init(id: UUID = UUID(), displayName: String, isHost: Bool = false) {
            self.id = id
            self.displayName = displayName
            self.avatarData = nil
            self.breathingState = .idle
            self.isHost = isHost
            self.joinedAt = Date()
            self.lastActiveAt = Date()
        }
    }
    
    struct EncouragementMessage: Identifiable, Codable {
        let id: UUID
        let senderName: String
        let message: String
        let timestamp: Date
        let messageType: MessageType
        
        enum MessageType: String, Codable {
            case encouragement
            case milestone
            case celebration
        }
        
        init(senderName: String, message: String, type: MessageType = .encouragement) {
            self.id = UUID()
            self.senderName = senderName
            self.message = message
            self.timestamp = Date()
            self.messageType = type
        }
    }
    
    // MARK: - Initialization
    
    init() {
        logger.info("Initializing FamilyBreathingManager")
        setupGroupActivitySession()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Group Session Management
    
    func startGroupSession() async {
        logger.info("Starting group breathing session")
        
        let activity = FamilyBreathingSession()
        
        do {
            switch await activity.prepareForActivation() {
            case .activationPreferred:
                try await activity.activate()
                logger.info("Group activity activated successfully")
                
            case .activationDisabled:
                logger.warning("Group activity activation disabled - starting solo session")
                await startSoloSession()
                
            case .cancelled:
                logger.info("Group activity activation cancelled by user")
                return
                
            @unknown default:
                logger.warning("Unknown group activity preparation result")
                await startSoloSession()
            }
        } catch {
            logger.error("Failed to activate group activity: \(error)")
            await startSoloSession()
        }
    }
    
    private func startSoloSession() async {
        logger.info("Starting solo breathing session")
        isSessionActive = true
        connectionStatus = .disconnected
        
        // Add current user as solo participant
        let soloParticipant = Participant(
            displayName: "You",
            isHost: true
        )
        currentParticipants = [soloParticipant]
        
        startSessionTimer()
    }
    
    func configureGroupSession(_ session: GroupSession<FamilyBreathingSession>) {
        logger.info("Configuring group session with \(session.activeParticipants.count) participants")
        
        self.groupSession = session
        isSessionActive = true
        connectionStatus = .connected(participantCount: session.activeParticipants.count)
        
        updateParticipants(from: session.activeParticipants)
        
        // Subscribe to session updates
        session.$activeParticipants
            .sink { [weak self] participants in
                Task { @MainActor in
                    self?.updateParticipants(from: participants)
                }
            }
            .store(in: &subscriptions)
        
        session.$state
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.handleSessionStateChange(state)
                }
            }
            .store(in: &subscriptions)
        
        // Subscribe to messages
        session.messages
            .sink { [weak self] message in
                Task { @MainActor in
                    await self?.handleGroupMessage(message)
                }
            }
            .store(in: &subscriptions)
        
        startSessionTimer()
        logger.info("Group session configured successfully")
    }
    
    private func updateParticipants(from groupParticipants: Set<Participant>) {
        logger.info("Updating participants: \(groupParticipants.count)")
        
        // Convert GroupActivity participants to our participants
        var newParticipants: [Participant] = []
        
        for groupParticipant in groupParticipants {
            // In a real implementation, we'd get actual participant data
            let participant = Participant(
                id: UUID(), // Would use actual participant ID
                displayName: "Family Member", // Would use actual name
                isHost: false // Would determine actual host status
            )
            newParticipants.append(participant)
        }
        
        // Ensure current user is included
        if !newParticipants.contains(where: { $0.displayName == "You" }) {
            let currentUser = Participant(displayName: "You", isHost: true)
            newParticipants.append(currentUser)
        }
        
        currentParticipants = newParticipants
        connectionStatus = .connected(participantCount: newParticipants.count)
    }
    
    // MARK: - Breathing Exercise Control
    
    func startBreathingExercise(_ exercise: BreathingExercise) {
        logger.info("Starting breathing exercise: \(exercise.name)")
        
        currentExercise = exercise
        currentCycle = 0
        breathingState = .inhaling
        
        startBreathingCycle()
        
        // Broadcast to group if in session
        if let session = groupSession {
            let message = BreathingMessage.startExercise(exercise)
            session.send(message)
        }
    }
    
    func stopBreathingExercise() {
        logger.info("Stopping breathing exercise")
        
        breathingTimer?.invalidate()
        breathingTimer = nil
        breathingState = .idle
        
        // Broadcast to group if in session
        if let session = groupSession {
            let message = BreathingMessage.stopExercise
            session.send(message)
        }
    }
    
    private func startBreathingCycle() {
        guard breathingState != .idle else { return }
        
        let currentDuration: TimeInterval
        
        switch breathingState {
        case .inhaling:
            currentDuration = currentExercise.inhaleTime
        case .holding:
            currentDuration = currentExercise.holdTime
        case .exhaling:
            currentDuration = currentExercise.exhaleTime
        case .idle:
            return
        }
        
        breathingTimer = Timer.scheduledTimer(withTimeInterval: currentDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.advanceBreathingState()
            }
        }
        
        // Broadcast state change to group
        if let session = groupSession {
            let message = BreathingMessage.stateChange(breathingState, currentCycle)
            session.send(message)
        }
    }
    
    private func advanceBreathingState() {
        switch breathingState {
        case .inhaling:
            breathingState = currentExercise.holdTime > 0 ? .holding : .exhaling
        case .holding:
            breathingState = .exhaling
        case .exhaling:
            currentCycle += 1
            
            // Check if exercise is complete
            if currentCycle >= currentExercise.totalCycles {
                completeBreathingExercise()
                return
            }
            
            breathingState = .inhaling
        case .idle:
            return
        }
        
        startBreathingCycle()
    }
    
    private func completeBreathingExercise() {
        logger.info("Breathing exercise completed after \(currentCycle) cycles")
        
        breathingTimer?.invalidate()
        breathingTimer = nil
        breathingState = .idle
        
        // Send completion message
        let completionMessage = EncouragementMessage(
            senderName: "System",
            message: "Breathing exercise completed! Great job everyone! 🌟",
            type: .celebration
        )
        encouragementMessages.append(completionMessage)
        
        // Broadcast completion to group
        if let session = groupSession {
            let message = BreathingMessage.exerciseComplete(currentCycle)
            session.send(message)
        }
    }
    
    // MARK: - Encouragement System
    
    func sendEncouragement(_ message: String) {
        logger.info("Sending encouragement message")
        
        let encouragement = EncouragementMessage(
            senderName: "You",
            message: message
        )
        
        encouragementMessages.append(encouragement)
        
        // Broadcast to group if in session
        if let session = groupSession {
            let groupMessage = BreathingMessage.encouragement(encouragement)
            session.send(groupMessage)
        }
    }
    
    // MARK: - Session Management
    
    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sessionDuration += 1.0
                
                // Send milestone messages
                if let self = self {
                    self.checkForMilestones()
                }
            }
        }
    }
    
    private func checkForMilestones() {
        let duration = Int(sessionDuration)
        
        // Send milestone messages at certain intervals
        switch duration {
        case 60: // 1 minute
            let milestone = EncouragementMessage(
                senderName: "System",
                message: "One minute of mindful breathing! Keep going! 💪",
                type: .milestone
            )
            encouragementMessages.append(milestone)
            
        case 300: // 5 minutes
            let milestone = EncouragementMessage(
                senderName: "System",
                message: "Five minutes of focused breathing - you're doing amazing! ⭐",
                type: .milestone
            )
            encouragementMessages.append(milestone)
            
        case 600: // 10 minutes
            let milestone = EncouragementMessage(
                senderName: "System",
                message: "Ten minutes of family breathing - this is incredible! 🎉",
                type: .milestone
            )
            encouragementMessages.append(milestone)
            
        default:
            break
        }
    }
    
    func endSession() {
        logger.info("Ending breathing session")
        
        isSessionActive = false
        breathingState = .idle
        currentCycle = 0
        sessionDuration = 0
        
        // Cleanup timers
        breathingTimer?.invalidate()
        sessionTimer?.invalidate()
        breathingTimer = nil
        sessionTimer = nil
        
        // End group session
        groupSession?.end()
        groupSession = nil
        
        // Reset state
        currentParticipants.removeAll()
        encouragementMessages.removeAll()
        connectionStatus = .disconnected
        
        logger.info("Breathing session ended")
    }
    
    // MARK: - Group Messages
    
    private func handleGroupMessage(_ message: BreathingMessage) async {
        logger.info("Received group message: \(message)")
        
        switch message {
        case .startExercise(let exercise):
            if !isSessionActive {
                currentExercise = exercise
                startBreathingExercise(exercise)
            }
            
        case .stateChange(let state, let cycle):
            breathingState = state
            currentCycle = cycle
            
        case .encouragement(let encouragement):
            encouragementMessages.append(encouragement)
            
        case .exerciseComplete(let totalCycles):
            logger.info("Exercise completed with \(totalCycles) cycles")
            
        case .stopExercise:
            stopBreathingExercise()
        }
    }
    
    private func handleSessionStateChange(_ state: GroupSessionState) {
        logger.info("Group session state changed: \(state)")
        
        switch state {
        case .waiting:
            connectionStatus = .connecting
        case .joined:
            connectionStatus = .connected(participantCount: groupSession?.activeParticipants.count ?? 0)
        case .invalidated(let error):
            connectionStatus = .failed(error)
            logger.error("Group session invalidated: \(error)")
        @unknown default:
            logger.warning("Unknown group session state: \(state)")
        }
    }
    
    // MARK: - Setup
    
    private func setupGroupActivitySession() {
        // Listen for incoming group sessions
        Task {
            for await session in FamilyBreathingSession.sessions() {
                configureGroupSession(session)
            }
        }
    }
    
    private func cleanup() {
        logger.info("Cleaning up FamilyBreathingManager")
        
        breathingTimer?.invalidate()
        sessionTimer?.invalidate()
        groupSession?.end()
        subscriptions.removeAll()
    }
}

// MARK: - Group Activity

struct FamilyBreathingSession: GroupActivity {
    var metadata: GroupActivityMetadata {
        var metadata = GroupActivityMetadata()
        metadata.title = "Family Breathing Session"
        metadata.subtitle = "Breathe together, grow together"
        metadata.previewImage = UIImage(systemName: "lungs")?.pngData()
        metadata.type = .generic
        metadata.supportsContinuationOnTV = false
        return metadata
    }
}

// MARK: - Group Messages

enum BreathingMessage: Codable, Sendable {
    case startExercise(BreathingExercise)
    case stateChange(FamilyBreathingManager.BreathingState, Int)
    case encouragement(FamilyBreathingManager.EncouragementMessage)
    case exerciseComplete(Int)
    case stopExercise
}

// MARK: - Breathing Exercise Model

struct BreathingExercise: Codable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let inhaleTime: TimeInterval
    let holdTime: TimeInterval
    let exhaleTime: TimeInterval
    let totalCycles: Int
    let difficulty: Difficulty
    
    enum Difficulty: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }
    
    static let familyDefault = BreathingExercise(
        name: "Family Harmony",
        description: "A gentle breathing pattern perfect for family sessions",
        inhaleTime: 4.0,
        holdTime: 2.0,
        exhaleTime: 6.0,
        totalCycles: 10,
        difficulty: .beginner
    )
    
    static let allExercises: [BreathingExercise] = [
        familyDefault,
        BreathingExercise(
            name: "Calm Waters",
            description: "Deep, relaxing breaths to promote tranquility",
            inhaleTime: 5.0,
            holdTime: 3.0,
            exhaleTime: 7.0,
            totalCycles: 8,
            difficulty: .intermediate
        ),
        BreathingExercise(
            name: "Energy Boost",
            description: "Energizing breath work for alertness and focus",
            inhaleTime: 3.0,
            holdTime: 1.0,
            exhaleTime: 4.0,
            totalCycles: 15,
            difficulty: .beginner
        )
    ]
}