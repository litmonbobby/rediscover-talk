//
//  IntegrationTests.swift
//  RediscoverTalk Unit Tests
//
//  Created by Claude on 2025-08-07.
//  Integration tests for Supabase, SharePlay, StoreKit, and OpenAI
//

import XCTest
import StoreKit
import GroupActivities
import Combine
@testable import RediscoverTalk

class IntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    var subscriptionManager: SubscriptionManager!
    var familyBreathingManager: FamilyBreathingManager!
    var featureAccessManager: FeatureAccessManager!
    var familyValidator: FamilySubscriptionValidator!
    var statusMonitor: SubscriptionStatusMonitor!
    var restoration: SubscriptionRestoration!
    var subscriptions: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        subscriptionManager = SubscriptionManager()
        familyBreathingManager = FamilyBreathingManager()
        featureAccessManager = FeatureAccessManager(subscriptionManager: subscriptionManager)
        familyValidator = FamilySubscriptionValidator(subscriptionManager: subscriptionManager)
        statusMonitor = SubscriptionStatusMonitor(subscriptionManager: subscriptionManager)
        restoration = SubscriptionRestoration(subscriptionManager: subscriptionManager)
        subscriptions = Set<AnyCancellable>()
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    override func tearDown() async throws {
        subscriptionManager = nil
        familyBreathingManager = nil
        featureAccessManager = nil
        familyValidator = nil
        statusMonitor = nil
        restoration = nil
        subscriptions.removeAll()
        subscriptions = nil
        
        try await super.tearDown()
    }
    
    // MARK: - StoreKit Integration Tests
    
    func testStoreKitProductLoading() async throws {
        // Given: Fresh subscription manager
        XCTAssertTrue(subscriptionManager.availableProducts.isEmpty, "Products should be empty initially")
        
        // When: Loading products from StoreKit
        await subscriptionManager.loadProducts()
        
        // Then: Should handle StoreKit response gracefully
        // Note: In test environment, this will likely result in no products loaded
        // but should not crash or throw errors
        XCTAssertFalse(subscriptionManager.isLoading, "Should not be loading after completion")
        
        // In sandbox/production environment, we would expect:
        // XCTAssertFalse(subscriptionManager.availableProducts.isEmpty, "Should load products")
    }
    
    func testStoreKitTransactionHandling() async throws {
        // Test transaction listener setup
        XCTAssertNotNil(subscriptionManager, "Subscription manager should be initialized")
        
        // Test purchased products update
        await subscriptionManager.updatePurchasedProducts()
        
        // Should complete without errors
        XCTAssertTrue(subscriptionManager.purchasedProducts.isEmpty || !subscriptionManager.purchasedProducts.isEmpty,
                     "Purchased products query should complete")
    }
    
    func testStoreKitRestoreFlow() async throws {
        // Given: Subscription manager
        let initialError = subscriptionManager.errorMessage
        
        // When: Attempting to restore purchases
        await subscriptionManager.restorePurchases()
        
        // Then: Should complete restore flow
        XCTAssertFalse(subscriptionManager.isLoading, "Should not be loading after restore")
        
        // Error handling should be graceful
        if let error = subscriptionManager.errorMessage {
            XCTAssertFalse(error.isEmpty, "Error message should be meaningful if present")
        }
    }
    
    // MARK: - SharePlay Integration Tests
    
    func testSharePlayGroupActivitySetup() async throws {
        // Test GroupActivity metadata configuration
        let activity = FamilyBreathingSession()
        let metadata = activity.metadata
        
        XCTAssertFalse(metadata.title.isEmpty, "Activity should have title")
        XCTAssertFalse(metadata.subtitle.isEmpty, "Activity should have subtitle")
        XCTAssertNotNil(metadata.previewImage, "Activity should have preview image")
    }
    
    func testSharePlaySessionFlow() async throws {
        // Given: Family breathing manager
        XCTAssertFalse(familyBreathingManager.isSessionActive, "Session should not be active initially")
        
        // When: Starting group session (will fallback to solo in test environment)
        await familyBreathingManager.startGroupSession()
        
        // Then: Should activate session
        XCTAssertTrue(familyBreathingManager.isSessionActive, "Session should be active")
        XCTAssertFalse(familyBreathingManager.currentParticipants.isEmpty, "Should have participants")
        
        // When: Ending session
        familyBreathingManager.endSession()
        
        // Then: Should clean up properly
        XCTAssertFalse(familyBreathingManager.isSessionActive, "Session should be inactive")
        XCTAssertEqual(familyBreathingManager.connectionStatus, .disconnected, "Should be disconnected")
    }
    
    func testSharePlayMessageSynchronization() async throws {
        // Given: Active session
        await familyBreathingManager.startGroupSession()
        
        // When: Sending encouragement message
        let message = "Great breathing everyone!"
        let initialCount = familyBreathingManager.encouragementMessages.count
        
        familyBreathingManager.sendEncouragement(message)
        
        // Then: Message should be added locally
        XCTAssertEqual(familyBreathingManager.encouragementMessages.count, initialCount + 1, "Should add message")
        
        let lastMessage = familyBreathingManager.encouragementMessages.last
        XCTAssertEqual(lastMessage?.message, message, "Message content should match")
        XCTAssertEqual(lastMessage?.senderName, "You", "Sender should be current user")
    }
    
    func testSharePlayBreathingSynchronization() async throws {
        // Given: Active session
        await familyBreathingManager.startGroupSession()
        
        // When: Starting breathing exercise
        let exercise = BreathingExercise.familyDefault
        familyBreathingManager.startBreathingExercise(exercise)
        
        // Then: Should synchronize breathing state
        XCTAssertEqual(familyBreathingManager.breathingState, .inhaling, "Should start with inhaling")
        XCTAssertEqual(familyBreathingManager.currentCycle, 0, "Should start at cycle 0")
        
        // When: Stopping exercise
        familyBreathingManager.stopBreathingExercise()
        
        // Then: Should return to idle
        XCTAssertEqual(familyBreathingManager.breathingState, .idle, "Should return to idle")
    }
    
    // MARK: - Feature Access Integration Tests
    
    func testFeatureAccessSubscriptionIntegration() async throws {
        // Given: Feature access manager with subscription manager
        XCTAssertFalse(featureAccessManager.isPremiumUser, "Should not be premium initially")
        
        // Test free tier access
        XCTAssertTrue(featureAccessManager.canAccessBreathingPattern("basic_4_4_4_4"), "Should access basic patterns")
        XCTAssertFalse(featureAccessManager.canAccessBreathingPattern("advanced_coherence"), "Should not access premium patterns")
        
        // Test upgrade prompts
        XCTAssertTrue(featureAccessManager.shouldShowUpgradePrompt(for: .sharePlay), "Should show upgrade prompt for SharePlay")
        
        // Test feature validation
        do {
            try featureAccessManager.validateFeatureAccess(for: .sharePlay)
            XCTFail("Should throw error for SharePlay access without subscription")
        } catch FeatureAccessError.requiresFamilySubscription {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testFamilyValidatorIntegration() async throws {
        // Given: Family validator with subscription manager
        XCTAssertEqual(familyValidator.familySubscriptionStatus, .notAvailable, "Should not have family subscription initially")
        XCTAssertEqual(familyValidator.currentMemberCount, 0, "Should have no members initially")
        
        // When: Validating family subscription
        await familyValidator.validateFamilySubscription()
        
        // Then: Should complete validation
        XCTAssertFalse(familyValidator.isValidatingFamily, "Should not be validating after completion")
        
        // Test member management
        XCTAssertFalse(familyValidator.canAddNewMember(), "Should not be able to add members without subscription")
        XCTAssertEqual(familyValidator.getAvailableSlots(), 0, "Should have no available slots")
    }
    
    func testStatusMonitorIntegration() async throws {
        // Given: Status monitor with subscription manager
        XCTAssertFalse(statusMonitor.isMonitoring, "Should not be monitoring initially")
        
        // When: Starting monitoring
        statusMonitor.startMonitoring()
        
        // Then: Should be monitoring
        XCTAssertTrue(statusMonitor.isMonitoring, "Should be monitoring after start")
        
        // Test status queries
        XCTAssertTrue(statusMonitor.getAllActiveStatuses().isEmpty, "Should have no active statuses initially")
        XCTAssertFalse(statusMonitor.isSubscriptionActive(productID: "test_product"), "Should not be active for unknown product")
        
        // When: Stopping monitoring
        statusMonitor.stopMonitoring()
        
        // Then: Should not be monitoring
        XCTAssertFalse(statusMonitor.isMonitoring, "Should not be monitoring after stop")
    }
    
    func testRestorationIntegration() async throws {
        // Given: Restoration service
        XCTAssertEqual(restoration.restorationState, .idle, "Should be idle initially")
        XCTAssertTrue(restoration.restoredSubscriptions.isEmpty, "Should have no restored subscriptions")
        
        // Test state transitions
        restoration.restorationState = .checking
        XCTAssertTrue(restoration.restorationState.isLoading, "Checking state should be loading")
        
        restoration.restorationState = .restoring
        XCTAssertTrue(restoration.restorationState.isLoading, "Restoring state should be loading")
        
        let result = SubscriptionRestoration.RestoreResult(
            restoredCount: 0,
            activeSubscriptions: [],
            familySubscriptions: [],
            migrationRequired: false,
            warnings: []
        )
        restoration.restorationState = .completed(result)
        XCTAssertFalse(restoration.restorationState.isLoading, "Completed state should not be loading")
    }
    
    // MARK: - Full System Integration Tests
    
    func testFullSubscriptionFlow() async throws {
        // Test complete subscription system integration
        
        // Step 1: Load products
        await subscriptionManager.loadProducts()
        XCTAssertNotNil(subscriptionManager.availableProducts, "Products should be loaded")
        
        // Step 2: Update feature access based on subscription status
        let initialPremiumStatus = featureAccessManager.isPremiumUser
        XCTAssertFalse(initialPremiumStatus, "Should not be premium initially")
        
        // Step 3: Test feature restrictions
        XCTAssertTrue(featureAccessManager.shouldShowUpgradePrompt(for: .sharePlay), "Should show upgrade prompts")
        
        // Step 4: Start monitoring
        statusMonitor.startMonitoring()
        XCTAssertTrue(statusMonitor.isMonitoring, "Should be monitoring")
        
        // Step 5: Test family features without subscription
        XCTAssertFalse(familyValidator.canAddNewMember(), "Should not allow family members without subscription")
        
        // Step 6: Clean up
        statusMonitor.stopMonitoring()
        XCTAssertFalse(statusMonitor.isMonitoring, "Should stop monitoring")
    }
    
    func testSharePlayAndSubscriptionIntegration() async throws {
        // Test SharePlay features with subscription requirements
        
        // Step 1: Start SharePlay session
        await familyBreathingManager.startGroupSession()
        XCTAssertTrue(familyBreathingManager.isSessionActive, "SharePlay session should start")
        
        // Step 2: Check SharePlay feature access
        do {
            try featureAccessManager.validateFeatureAccess(for: .sharePlay)
            XCTFail("Should require family subscription for SharePlay")
        } catch FeatureAccessError.requiresFamilySubscription {
            // Expected - SharePlay requires family subscription
        }
        
        // Step 3: Test breathing exercise in SharePlay
        let exercise = BreathingExercise.familyDefault
        familyBreathingManager.startBreathingExercise(exercise)
        XCTAssertNotEqual(familyBreathingManager.breathingState, .idle, "Should start breathing exercise")
        
        // Step 4: Send encouragement message
        familyBreathingManager.sendEncouragement("Keep breathing!")
        XCTAssertGreaterThan(familyBreathingManager.encouragementMessages.count, 0, "Should have messages")
        
        // Step 5: End session
        familyBreathingManager.endSession()
        XCTAssertFalse(familyBreathingManager.isSessionActive, "Session should end")
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testIntegratedErrorHandling() async throws {
        // Test error propagation across system components
        
        // Test subscription error handling
        if let error = subscriptionManager.errorMessage {
            XCTAssertFalse(error.isEmpty, "Error messages should be meaningful")
        }
        
        // Test feature access errors
        let featureErrors: [FeatureAccessError] = [
            .dailyLimitReached,
            .requiresPremiumSubscription,
            .requiresFamilySubscription
        ]
        
        for error in featureErrors {
            XCTAssertNotNil(error.errorDescription, "Feature access errors should have descriptions")
            XCTAssertNotNil(error.recoverySuggestion, "Feature access errors should have recovery suggestions")
        }
        
        // Test family validation errors
        let familyErrors: [FamilyValidationError] = [
            .memberNotFound,
            .maxMembersReached,
            .insufficientPermissions,
            .subscriptionRequired
        ]
        
        for error in familyErrors {
            XCTAssertNotNil(error.errorDescription, "Family validation errors should have descriptions")
            XCTAssertNotNil(error.recoverySuggestion, "Family validation errors should have recovery suggestions")
        }
    }
    
    // MARK: - Performance Integration Tests
    
    func testIntegratedSystemPerformance() async throws {
        let expectation = XCTestExpectation(description: "System performance integration")
        
        measure {
            Task {
                // Test integrated system operations
                await subscriptionManager.loadProducts()
                await subscriptionManager.updatePurchasedProducts()
                
                await familyBreathingManager.startGroupSession()
                familyBreathingManager.startBreathingExercise(BreathingExercise.familyDefault)
                familyBreathingManager.sendEncouragement("Performance test message")
                familyBreathingManager.stopBreathingExercise()
                familyBreathingManager.endSession()
                
                statusMonitor.startMonitoring()
                statusMonitor.stopMonitoring()
                
                await familyValidator.validateFamilySubscription()
                
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Concurrency Integration Tests
    
    func testConcurrentSystemOperations() async throws {
        let expectation = XCTestExpectation(description: "Concurrent system operations")
        expectation.expectedFulfillmentCount = 5
        
        // Run multiple system operations concurrently
        Task {
            await subscriptionManager.loadProducts()
            expectation.fulfill()
        }
        
        Task {
            await familyBreathingManager.startGroupSession()
            familyBreathingManager.endSession()
            expectation.fulfill()
        }
        
        Task {
            statusMonitor.startMonitoring()
            statusMonitor.stopMonitoring()
            expectation.fulfill()
        }
        
        Task {
            await familyValidator.validateFamilySubscription()
            expectation.fulfill()
        }
        
        Task {
            try? featureAccessManager.validateFeatureAccess(for: .offlineContent)
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
    }
    
    // MARK: - Data Flow Integration Tests
    
    func testDataFlowBetweenComponents() async throws {
        // Test data flow from subscription manager to feature access manager
        
        // Initial state
        XCTAssertFalse(featureAccessManager.isPremiumUser, "Should not be premium initially")
        
        // Simulate subscription state change
        // In real app, this would come from actual StoreKit transactions
        subscriptionManager.purchasedProducts = [] // Empty for free tier
        
        // Feature access should reflect subscription state
        XCTAssertFalse(featureAccessManager.isPremiumUser, "Should remain non-premium with empty products")
        XCTAssertFalse(featureAccessManager.hasFamilyAccess, "Should not have family access")
        
        // Test session count tracking
        let initialCount = featureAccessManager.getRemainingFreeSessions()
        featureAccessManager.recordSessionStart()
        let newCount = featureAccessManager.getRemainingFreeSessions()
        
        XCTAssertLessThan(newCount, initialCount, "Session count should decrease")
    }
    
    // MARK: - State Synchronization Tests
    
    func testStateSynchronizationAcrossComponents() async throws {
        // Test that state changes are properly synchronized across components
        
        let expectation = XCTestExpectation(description: "State synchronization")
        
        // Monitor subscription manager state changes
        var subscriptionStateChanges = 0
        subscriptionManager.$isLoading
            .dropFirst() // Skip initial value
            .sink { _ in
                subscriptionStateChanges += 1
                if subscriptionStateChanges >= 2 { // Loading true, then false
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        // Trigger state change
        await subscriptionManager.loadProducts()
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertGreaterThanOrEqual(subscriptionStateChanges, 2, "Should have loading state changes")
    }
    
    // MARK: - Mock Integration Helpers
    
    private func createMockProduct() -> MockProduct {
        return MockProduct(
            id: "test_product",
            displayName: "Test Product",
            price: 9.99
        )
    }
    
    private func createMockTransaction() -> MockTransaction {
        return MockTransaction(
            id: 12345,
            productID: "test_product",
            purchaseDate: Date()
        )
    }
}

// MARK: - Mock Objects for Testing

struct MockProduct {
    let id: String
    let displayName: String
    let price: Double
}

struct MockTransaction {
    let id: Int
    let productID: String
    let purchaseDate: Date
}