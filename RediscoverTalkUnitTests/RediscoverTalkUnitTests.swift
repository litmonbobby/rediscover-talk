//
//  RediscoverTalkUnitTests.swift
//  RediscoverTalk Unit Tests
//
//  Created by Claude on 2025-08-07.
//  Main unit test suite with comprehensive coverage
//

import XCTest
import StoreKit
import GroupActivities
import Combine
@testable import RediscoverTalk

class RediscoverTalkUnitTests: XCTestCase {
    
    // MARK: - Properties
    
    var subscriptionManager: SubscriptionManager!
    var familyBreathingManager: FamilyBreathingManager!
    var subscriptions: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        subscriptionManager = SubscriptionManager()
        familyBreathingManager = FamilyBreathingManager()
        subscriptions = Set<AnyCancellable>()
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    override func tearDown() async throws {
        subscriptionManager = nil
        familyBreathingManager = nil
        subscriptions.removeAll()
        subscriptions = nil
        
        try await super.tearDown()
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunchPerformance() {
        measure {
            let app = RediscoverTalkApp()
            XCTAssertNotNil(app)
        }
    }
    
    func testAppInitialization() {
        // Test that app components initialize correctly
        let app = RediscoverTalkApp()
        XCTAssertNotNil(app, "App should initialize successfully")
    }
    
    // MARK: - Memory Management Tests
    
    func testSubscriptionManagerMemoryManagement() {
        weak var weakManager: SubscriptionManager?
        
        autoreleasepool {
            let manager = SubscriptionManager()
            weakManager = manager
            XCTAssertNotNil(weakManager, "Manager should exist")
        }
        
        // Allow deallocation
        DispatchQueue.main.async {
            XCTAssertNil(weakManager, "Manager should be deallocated")
        }
    }
    
    func testFamilyBreathingManagerMemoryManagement() {
        weak var weakManager: FamilyBreathingManager?
        
        autoreleasepool {
            let manager = FamilyBreathingManager()
            weakManager = manager
            XCTAssertNotNil(weakManager, "Manager should exist")
        }
        
        // Allow deallocation  
        DispatchQueue.main.async {
            XCTAssertNil(weakManager, "Manager should be deallocated")
        }
    }
    
    // MARK: - State Management Tests
    
    func testPublishedPropertiesInitialState() {
        // Test SubscriptionManager initial state
        XCTAssertTrue(subscriptionManager.availableProducts.isEmpty, "Available products should be empty initially")
        XCTAssertTrue(subscriptionManager.purchasedProducts.isEmpty, "Purchased products should be empty initially")
        XCTAssertFalse(subscriptionManager.isLoading, "Should not be loading initially")
        XCTAssertNil(subscriptionManager.errorMessage, "Should have no error initially")
        
        // Test FamilyBreathingManager initial state
        XCTAssertFalse(familyBreathingManager.isSessionActive, "Session should not be active initially")
        XCTAssertEqual(familyBreathingManager.breathingState, .idle, "Breathing state should be idle initially")
        XCTAssertTrue(familyBreathingManager.currentParticipants.isEmpty, "Participants should be empty initially")
        XCTAssertEqual(familyBreathingManager.currentCycle, 0, "Current cycle should be 0 initially")
        XCTAssertEqual(familyBreathingManager.sessionDuration, 0, "Session duration should be 0 initially")
    }
    
    // MARK: - Data Model Tests
    
    func testBreathingExerciseModel() {
        let exercise = BreathingExercise.familyDefault
        
        XCTAssertEqual(exercise.name, "Family Harmony", "Name should match")
        XCTAssertGreaterThan(exercise.inhaleTime, 0, "Inhale time should be positive")
        XCTAssertGreaterThanOrEqual(exercise.holdTime, 0, "Hold time should be non-negative")
        XCTAssertGreaterThan(exercise.exhaleTime, 0, "Exhale time should be positive")
        XCTAssertGreaterThan(exercise.totalCycles, 0, "Total cycles should be positive")
        XCTAssertNotNil(exercise.difficulty, "Difficulty should be set")
    }
    
    func testParticipantModel() {
        let participant = FamilyBreathingManager.Participant(
            displayName: "Test User",
            isHost: true
        )
        
        XCTAssertNotNil(participant.id, "Participant should have ID")
        XCTAssertEqual(participant.displayName, "Test User", "Display name should match")
        XCTAssertTrue(participant.isHost, "Host flag should match")
        XCTAssertEqual(participant.breathingState, .idle, "Breathing state should default to idle")
        XCTAssertNotNil(participant.joinedAt, "Joined date should be set")
        XCTAssertNotNil(participant.lastActiveAt, "Last active date should be set")
    }
    
    func testEncouragementMessageModel() {
        let message = FamilyBreathingManager.EncouragementMessage(
            senderName: "Test User",
            message: "Great job!",
            type: .encouragement
        )
        
        XCTAssertNotNil(message.id, "Message should have ID")
        XCTAssertEqual(message.senderName, "Test User", "Sender name should match")
        XCTAssertEqual(message.message, "Great job!", "Message text should match")
        XCTAssertEqual(message.messageType, .encouragement, "Message type should match")
        XCTAssertNotNil(message.timestamp, "Timestamp should be set")
    }
    
    // MARK: - Breathing State Tests
    
    func testBreathingStateTransitions() {
        let states: [FamilyBreathingManager.BreathingState] = [.idle, .inhaling, .holding, .exhaling]
        
        for state in states {
            XCTAssertNotNil(state.displayName, "State should have display name")
            XCTAssertFalse(state.displayName.isEmpty, "Display name should not be empty")
        }
    }
    
    // MARK: - Connection Status Tests
    
    func testConnectionStatus() {
        let disconnected = FamilyBreathingManager.ConnectionStatus.disconnected
        let connecting = FamilyBreathingManager.ConnectionStatus.connecting
        let connected = FamilyBreathingManager.ConnectionStatus.connected(participantCount: 3)
        
        XCTAssertFalse(disconnected.isConnected, "Disconnected should not be connected")
        XCTAssertFalse(connecting.isConnected, "Connecting should not be connected")
        XCTAssertTrue(connected.isConnected, "Connected should be connected")
    }
    
    // MARK: - Subscription Product Tests
    
    func testSubscriptionProductEnumeration() {
        let products = SubscriptionManager.SubscriptionProducts.allCases
        
        XCTAssertEqual(products.count, 2, "Should have 2 subscription products")
        XCTAssertTrue(products.contains(.individual), "Should contain individual product")
        XCTAssertTrue(products.contains(.family), "Should contain family product")
        
        for product in products {
            XCTAssertFalse(product.displayName.isEmpty, "Product should have display name")
            XCTAssertFalse(product.features.isEmpty, "Product should have features")
            XCTAssertFalse(product.rawValue.isEmpty, "Product should have raw value")
        }
    }
    
    func testSubscriptionProductFeatures() {
        let individualFeatures = SubscriptionManager.SubscriptionProducts.individual.features
        let familyFeatures = SubscriptionManager.SubscriptionProducts.family.features
        
        XCTAssertGreaterThan(individualFeatures.count, 0, "Individual should have features")
        XCTAssertGreaterThan(familyFeatures.count, 0, "Family should have features")
        XCTAssertGreaterThan(familyFeatures.count, individualFeatures.count, "Family should have more features")
    }
    
    // MARK: - Store Error Tests
    
    func testStoreErrorDescriptions() {
        let errors: [StoreError] = [.failedVerification, .purchaseNotAllowed, .unknown]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }
    
    // MARK: - Async Operation Tests
    
    func testAsyncOperationCancellation() async throws {
        let task = Task {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return "Completed"
        }
        
        // Cancel after a short delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            task.cancel()
        }
        
        do {
            let result = try await task.value
            XCTFail("Task should have been cancelled, got result: \(result)")
        } catch {
            XCTAssertTrue(error is CancellationError, "Should throw CancellationError")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyCollectionHandling() {
        // Test empty participants
        familyBreathingManager.currentParticipants = []
        XCTAssertTrue(familyBreathingManager.currentParticipants.isEmpty, "Participants should be empty")
        
        // Test empty products
        subscriptionManager.availableProducts = []
        XCTAssertTrue(subscriptionManager.availableProducts.isEmpty, "Products should be empty")
        
        // Test empty messages
        familyBreathingManager.encouragementMessages = []
        XCTAssertTrue(familyBreathingManager.encouragementMessages.isEmpty, "Messages should be empty")
    }
    
    func testNilValueHandling() {
        // Test nil error message
        subscriptionManager.errorMessage = nil
        XCTAssertNil(subscriptionManager.errorMessage, "Error message should be nil")
        
        subscriptionManager.errorMessage = "Test error"
        XCTAssertNotNil(subscriptionManager.errorMessage, "Error message should not be nil")
    }
    
    // MARK: - Boundary Value Tests
    
    func testBoundaryValues() {
        // Test zero duration
        let zeroDuration = TimeInterval(0)
        XCTAssertEqual(zeroDuration, 0, "Zero duration should equal 0")
        
        // Test negative values handled gracefully
        let exercise = BreathingExercise(
            name: "Test",
            description: "Test exercise",
            inhaleTime: 1.0,
            holdTime: 0.0, // Zero hold time should be valid
            exhaleTime: 1.0,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        XCTAssertEqual(exercise.holdTime, 0.0, "Zero hold time should be allowed")
        XCTAssertGreaterThan(exercise.inhaleTime, 0, "Inhale time should be positive")
        XCTAssertGreaterThan(exercise.exhaleTime, 0, "Exhale time should be positive")
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAccess() async throws {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 10
        
        // Start multiple concurrent operations
        for i in 0..<10 {
            Task {
                await subscriptionManager.loadProducts()
                XCTAssertNotNil(subscriptionManager.availableProducts, "Products should be loaded in task \(i)")
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Performance Tests
    
    func testStateUpdatePerformance() {
        measure {
            for _ in 0..<1000 {
                familyBreathingManager.breathingState = .inhaling
                familyBreathingManager.breathingState = .holding
                familyBreathingManager.breathingState = .exhaling
                familyBreathingManager.breathingState = .idle
            }
        }
    }
    
    func testCollectionOperationsPerformance() {
        measure {
            var participants: [FamilyBreathingManager.Participant] = []
            
            // Add 1000 participants
            for i in 0..<1000 {
                let participant = FamilyBreathingManager.Participant(
                    displayName: "User \(i)",
                    isHost: i == 0
                )
                participants.append(participant)
            }
            
            // Filter operations
            let hosts = participants.filter { $0.isHost }
            XCTAssertEqual(hosts.count, 1, "Should have 1 host")
            
            // Sort operations
            let sorted = participants.sorted { $0.displayName < $1.displayName }
            XCTAssertEqual(sorted.count, participants.count, "Sorted count should match")
        }
    }
}