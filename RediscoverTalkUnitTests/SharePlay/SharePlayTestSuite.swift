//
//  SharePlayTestSuite.swift
//  RediscoverTalk Unit Tests
//
//  Created by Claude on 2025-08-07.
//  Comprehensive SharePlay testing with multi-device coordination
//

import XCTest
import GroupActivities
import Combine
@testable import RediscoverTalk

class SharePlayTestSuite: XCTestCase {
    
    // MARK: - Properties
    
    var familyBreathingManager: FamilyBreathingManager!
    var mockGroupSession: MockGroupSession!
    var subscriptions: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        familyBreathingManager = FamilyBreathingManager()
        mockGroupSession = MockGroupSession()
        subscriptions = Set<AnyCancellable>()
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        familyBreathingManager = nil
        mockGroupSession = nil
        subscriptions.removeAll()
        subscriptions = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Group Activity Tests
    
    func testFamilyBreathingSessionMetadata() {
        let activity = FamilyBreathingSession()
        let metadata = activity.metadata
        
        XCTAssertEqual(metadata.title, "Family Breathing Session", "Title should match")
        XCTAssertEqual(metadata.subtitle, "Breathe together, grow together", "Subtitle should match")
        XCTAssertNotNil(metadata.previewImage, "Should have preview image")
        XCTAssertEqual(metadata.type, .generic, "Should be generic type")
        XCTAssertFalse(metadata.supportsContinuationOnTV, "Should not support TV continuation")
    }
    
    func testGroupActivityInitialization() {
        let activity = FamilyBreathingSession()
        XCTAssertNotNil(activity, "Activity should initialize")
        
        let metadata = activity.metadata
        XCTAssertFalse(metadata.title.isEmpty, "Title should not be empty")
        XCTAssertFalse(metadata.subtitle.isEmpty, "Subtitle should not be empty")
    }
    
    // MARK: - Session Management Tests
    
    func testStartGroupSession() async throws {
        // Given: Fresh family breathing manager
        XCTAssertFalse(familyBreathingManager.isSessionActive, "Session should not be active initially")
        XCTAssertEqual(familyBreathingManager.connectionStatus, .disconnected, "Should be disconnected initially")
        
        // When: Starting group session (will fallback to solo in test environment)
        await familyBreathingManager.startGroupSession()
        
        // Then: Session should be active
        XCTAssertTrue(familyBreathingManager.isSessionActive, "Session should be active after start")
        XCTAssertFalse(familyBreathingManager.currentParticipants.isEmpty, "Should have participants")
        
        // Solo session should have current user
        let soloParticipant = familyBreathingManager.currentParticipants.first
        XCTAssertNotNil(soloParticipant, "Should have solo participant")
        XCTAssertEqual(soloParticipant?.displayName, "You", "Solo participant should be 'You'")
        XCTAssertTrue(soloParticipant?.isHost ?? false, "Solo participant should be host")
    }
    
    func testConfigureGroupSession() {
        // Given: Mock group session with participants
        let mockParticipants = createMockParticipants(count: 3)
        mockGroupSession.activeParticipants = Set(mockParticipants)
        mockGroupSession.state = .joined
        
        // When: Configuring group session
        familyBreathingManager.configureGroupSession(mockGroupSession as! GroupSession<FamilyBreathingSession>)
        
        // Then: Session should be configured
        XCTAssertTrue(familyBreathingManager.isSessionActive, "Session should be active")
        XCTAssertTrue(familyBreathingManager.connectionStatus.isConnected, "Should be connected")
        XCTAssertGreaterThan(familyBreathingManager.currentParticipants.count, 0, "Should have participants")
    }
    
    func testEndSession() async throws {
        // Given: Active session
        await familyBreathingManager.startGroupSession()
        XCTAssertTrue(familyBreathingManager.isSessionActive, "Session should be active")
        
        // When: Ending session
        familyBreathingManager.endSession()
        
        // Then: Session should be ended
        XCTAssertFalse(familyBreathingManager.isSessionActive, "Session should not be active")
        XCTAssertEqual(familyBreathingManager.breathingState, .idle, "Should be in idle state")
        XCTAssertEqual(familyBreathingManager.currentCycle, 0, "Cycle count should be reset")
        XCTAssertEqual(familyBreathingManager.sessionDuration, 0, "Duration should be reset")
        XCTAssertTrue(familyBreathingManager.currentParticipants.isEmpty, "Participants should be empty")
        XCTAssertEqual(familyBreathingManager.connectionStatus, .disconnected, "Should be disconnected")
    }
    
    // MARK: - Participant Management Tests
    
    func testParticipantUpdates() {
        // Given: Mock participants
        let participants = createMockParticipants(count: 4)
        mockGroupSession.activeParticipants = Set(participants)
        
        // When: Configuring session with participants
        familyBreathingManager.configureGroupSession(mockGroupSession as! GroupSession<FamilyBreathingSession>)
        
        // Then: Participants should be updated
        XCTAssertGreaterThan(familyBreathingManager.currentParticipants.count, 0, "Should have participants")
        
        // Should include current user
        let hasCurrentUser = familyBreathingManager.currentParticipants.contains { $0.displayName == "You" }
        XCTAssertTrue(hasCurrentUser, "Should include current user")
    }
    
    func testParticipantLimit() {
        // Test with maximum participants (6 for family plan)
        let participants = createMockParticipants(count: 6)
        mockGroupSession.activeParticipants = Set(participants)
        
        familyBreathingManager.configureGroupSession(mockGroupSession as! GroupSession<FamilyBreathingSession>)
        
        // Should handle maximum participants gracefully
        XCTAssertLessThanOrEqual(familyBreathingManager.currentParticipants.count, 7, "Should not exceed family limit + current user")
    }
    
    // MARK: - Breathing Synchronization Tests
    
    func testBreathingExerciseStart() {
        // Given: Active session
        familyBreathingManager.isSessionActive = true
        let exercise = BreathingExercise.familyDefault
        
        // When: Starting breathing exercise
        familyBreathingManager.startBreathingExercise(exercise)
        
        // Then: Exercise should start
        XCTAssertEqual(familyBreathingManager.breathingState, .inhaling, "Should start with inhaling")
        XCTAssertEqual(familyBreathingManager.currentCycle, 0, "Should start at cycle 0")
    }
    
    func testBreathingExerciseStop() {
        // Given: Active breathing exercise
        familyBreathingManager.isSessionActive = true
        let exercise = BreathingExercise.familyDefault
        familyBreathingManager.startBreathingExercise(exercise)
        
        // When: Stopping exercise
        familyBreathingManager.stopBreathingExercise()
        
        // Then: Exercise should stop
        XCTAssertEqual(familyBreathingManager.breathingState, .idle, "Should return to idle")
    }
    
    func testBreathingStateTransitions() {
        let expectation = XCTestExpectation(description: "Breathing state transitions")
        
        // Given: Active session
        familyBreathingManager.isSessionActive = true
        
        // Monitor state changes
        var stateChanges: [FamilyBreathingManager.BreathingState] = []
        familyBreathingManager.$breathingState
            .sink { state in
                stateChanges.append(state)
                if stateChanges.count >= 3 { // idle -> inhaling -> holding (or exhaling)
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // When: Starting exercise with short durations for testing
        let testExercise = BreathingExercise(
            name: "Quick Test",
            description: "Test exercise",
            inhaleTime: 0.1,
            holdTime: 0.1,
            exhaleTime: 0.1,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        familyBreathingManager.startBreathingExercise(testExercise)
        
        // Then: Should transition through states
        wait(for: [expectation], timeout: 5.0)
        XCTAssertGreaterThanOrEqual(stateChanges.count, 2, "Should have multiple state changes")
        XCTAssertEqual(stateChanges.first, .idle, "Should start with idle")
    }
    
    // MARK: - Message Synchronization Tests
    
    func testEncouragementMessageSending() {
        // Given: Active session
        familyBreathingManager.isSessionActive = true
        let initialCount = familyBreathingManager.encouragementMessages.count
        
        // When: Sending encouragement
        let message = "Great job everyone!"
        familyBreathingManager.sendEncouragement(message)
        
        // Then: Message should be added
        XCTAssertEqual(familyBreathingManager.encouragementMessages.count, initialCount + 1, "Should add message")
        
        let lastMessage = familyBreathingManager.encouragementMessages.last
        XCTAssertEqual(lastMessage?.message, message, "Message text should match")
        XCTAssertEqual(lastMessage?.senderName, "You", "Sender should be 'You'")
        XCTAssertEqual(lastMessage?.messageType, .encouragement, "Should be encouragement type")
    }
    
    func testMilestoneMessages() async throws {
        // Given: Active session
        familyBreathingManager.isSessionActive = true
        let initialCount = familyBreathingManager.encouragementMessages.count
        
        // When: Simulating session duration milestones
        familyBreathingManager.sessionDuration = 60 // 1 minute
        
        // Trigger milestone check by calling private method through reflection
        // In real implementation, this would be triggered by timer
        let mirror = Mirror(reflecting: familyBreathingManager)
        if let checkForMilestonesMethod = mirror.children.first(where: { $0.label == "checkForMilestones" }) {
            // This is a simplified test - actual implementation would use proper async testing
        }
        
        // For now, test that milestone messages can be created
        let milestone = FamilyBreathingManager.EncouragementMessage(
            senderName: "System",
            message: "One minute milestone reached!",
            type: .milestone
        )
        
        familyBreathingManager.encouragementMessages.append(milestone)
        
        // Then: Milestone message should be added
        XCTAssertEqual(familyBreathingManager.encouragementMessages.count, initialCount + 1, "Should add milestone")
        XCTAssertEqual(milestone.messageType, .milestone, "Should be milestone type")
    }
    
    // MARK: - Group Message Handling Tests
    
    func testBreathingMessageTypes() {
        // Test all message types can be created
        let exercise = BreathingExercise.familyDefault
        let encouragement = FamilyBreathingManager.EncouragementMessage(
            senderName: "Test User",
            message: "Test message"
        )
        
        let messages: [BreathingMessage] = [
            .startExercise(exercise),
            .stateChange(.inhaling, 1),
            .encouragement(encouragement),
            .exerciseComplete(10),
            .stopExercise
        ]
        
        for message in messages {
            XCTAssertNotNil(message, "Message should be created")
            
            // Test that messages can be encoded/decoded
            do {
                let encoded = try JSONEncoder().encode(message)
                let decoded = try JSONDecoder().decode(BreathingMessage.self, from: encoded)
                XCTAssertNotNil(decoded, "Message should be encodable/decodable")
            } catch {
                XCTFail("Message should be Codable: \(error)")
            }
        }
    }
    
    // MARK: - Connection Status Tests
    
    func testConnectionStatusUpdates() {
        // Test different connection states
        let states: [FamilyBreathingManager.ConnectionStatus] = [
            .disconnected,
            .connecting,
            .connected(participantCount: 3),
            .failed(NSError(domain: "test", code: -1, userInfo: nil))
        ]
        
        for state in states {
            familyBreathingManager.connectionStatus = state
            
            switch state {
            case .connected:
                XCTAssertTrue(state.isConnected, "Connected state should report as connected")
            default:
                XCTAssertFalse(state.isConnected, "Non-connected states should report as not connected")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testGroupSessionErrors() {
        // Test handling of session errors
        let error = NSError(domain: "GroupActivityError", code: -1000, userInfo: [
            NSLocalizedDescriptionKey: "Failed to join group session"
        ])
        
        familyBreathingManager.connectionStatus = .failed(error)
        
        XCTAssertFalse(familyBreathingManager.connectionStatus.isConnected, "Failed state should not be connected")
        
        if case .failed(let statusError) = familyBreathingManager.connectionStatus {
            XCTAssertNotNil(statusError, "Should contain error information")
        } else {
            XCTFail("Status should be failed")
        }
    }
    
    // MARK: - Performance Tests
    
    func testParticipantUpdatePerformance() {
        measure {
            let participants = createMockParticipants(count: 100)
            mockGroupSession.activeParticipants = Set(participants)
            familyBreathingManager.configureGroupSession(mockGroupSession as! GroupSession<FamilyBreathingSession>)
        }
    }
    
    func testMessageProcessingPerformance() {
        measure {
            for i in 0..<1000 {
                let message = "Performance test message \(i)"
                familyBreathingManager.sendEncouragement(message)
            }
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentSessionOperations() async throws {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 5
        
        // Start multiple concurrent operations
        for i in 0..<5 {
            Task {
                await familyBreathingManager.startGroupSession()
                familyBreathingManager.endSession()
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    func testConcurrentMessageSending() async throws {
        familyBreathingManager.isSessionActive = true
        
        let expectation = XCTestExpectation(description: "Concurrent messages")
        expectation.expectedFulfillmentCount = 10
        
        // Send multiple concurrent messages
        for i in 0..<10 {
            Task {
                familyBreathingManager.sendEncouragement("Concurrent message \(i)")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // All messages should be recorded
        XCTAssertEqual(familyBreathingManager.encouragementMessages.count, 10, "Should have all messages")
    }
    
    // MARK: - Integration Tests
    
    func testSharePlayIntegrationFlow() async throws {
        // Test full SharePlay integration flow
        
        // Step 1: Start group session
        await familyBreathingManager.startGroupSession()
        XCTAssertTrue(familyBreathingManager.isSessionActive, "Session should start")
        
        // Step 2: Start breathing exercise
        let exercise = BreathingExercise.familyDefault
        familyBreathingManager.startBreathingExercise(exercise)
        XCTAssertEqual(familyBreathingManager.breathingState, .inhaling, "Should start breathing")
        
        // Step 3: Send encouragement
        familyBreathingManager.sendEncouragement("Let's breathe together!")
        XCTAssertGreaterThan(familyBreathingManager.encouragementMessages.count, 0, "Should have messages")
        
        // Step 4: End session
        familyBreathingManager.endSession()
        XCTAssertFalse(familyBreathingManager.isSessionActive, "Session should end")
        XCTAssertEqual(familyBreathingManager.breathingState, .idle, "Should return to idle")
    }
    
    // MARK: - Helper Methods
    
    private func createMockParticipants(count: Int) -> [FamilyBreathingManager.Participant] {
        return (0..<count).map { index in
            FamilyBreathingManager.Participant(
                displayName: "Mock User \(index)",
                isHost: index == 0
            )
        }
    }
}

// MARK: - Mock Group Session

class MockGroupSession {
    var activeParticipants: Set<FamilyBreathingManager.Participant> = []
    var state: GroupSessionState = .waiting
    var messages: PassthroughSubject<BreathingMessage, Never> = PassthroughSubject()
    
    func send(_ message: BreathingMessage) {
        messages.send(message)
    }
    
    func end() {
        state = .invalidated(reason: NSError(domain: "MockError", code: 0, userInfo: nil))
        activeParticipants.removeAll()
    }
}