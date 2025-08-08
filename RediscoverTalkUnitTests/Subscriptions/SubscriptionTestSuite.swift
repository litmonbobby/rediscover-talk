//
//  SubscriptionTestSuite.swift
//  Rediscover Talk Tests
//
//  Created by Claude on 2025-08-07.
//  Comprehensive test suite for StoreKit 2 subscription system
//

import XCTest
import StoreKit
@testable import RediscoverTalk

class SubscriptionTestSuite: XCTestCase {
    
    var subscriptionManager: SubscriptionManager!
    var featureAccessManager: FeatureAccessManager!
    var familyValidator: FamilySubscriptionValidator!
    var statusMonitor: SubscriptionStatusMonitor!
    var restoration: SubscriptionRestoration!
    
    override func setUp() async throws {
        try await super.setUp()
        
        subscriptionManager = SubscriptionManager()
        featureAccessManager = FeatureAccessManager(subscriptionManager: subscriptionManager)
        familyValidator = FamilySubscriptionValidator(subscriptionManager: subscriptionManager)
        statusMonitor = SubscriptionStatusMonitor(subscriptionManager: subscriptionManager)
        restoration = SubscriptionRestoration(subscriptionManager: subscriptionManager)
        
        // Wait for initial setup
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    override func tearDown() async throws {
        subscriptionManager = nil
        featureAccessManager = nil
        familyValidator = nil
        statusMonitor = nil
        restoration = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Product Loading Tests
    
    func testProductLoading() async throws {
        // Given: Fresh subscription manager
        XCTAssertTrue(subscriptionManager.availableProducts.isEmpty, "Products should be empty initially")
        
        // When: Loading products
        await subscriptionManager.loadProducts()
        
        // Then: Products should be loaded
        XCTAssertFalse(subscriptionManager.availableProducts.isEmpty, "Products should be loaded")
        XCTAssertEqual(subscriptionManager.availableProducts.count, 2, "Should have 2 subscription products")
        
        let productIDs = subscriptionManager.availableProducts.map { $0.id }
        XCTAssertTrue(productIDs.contains("rediscover_talk_individual_monthly"), "Should contain individual product")
        XCTAssertTrue(productIDs.contains("rediscover_talk_family_monthly"), "Should contain family product")
    }
    
    func testProductProperties() async throws {
        // Given: Loaded products
        await subscriptionManager.loadProducts()
        
        guard let individualProduct = subscriptionManager.availableProducts.first(where: {
            $0.id == "rediscover_talk_individual_monthly"
        }) else {
            XCTFail("Individual product not found")
            return
        }
        
        guard let familyProduct = subscriptionManager.availableProducts.first(where: {
            $0.id == "rediscover_talk_family_monthly"
        }) else {
            XCTFail("Family product not found")
            return
        }
        
        // Then: Product properties should be correct
        XCTAssertEqual(individualProduct.type, .autoRenewable, "Individual should be auto-renewable")
        XCTAssertEqual(familyProduct.type, .autoRenewable, "Family should be auto-renewable")
        
        XCTAssertNotNil(individualProduct.subscription, "Individual should have subscription info")
        XCTAssertNotNil(familyProduct.subscription, "Family should have subscription info")
        
        XCTAssertTrue(individualProduct.price < familyProduct.price, "Individual should cost less than family")
    }
    
    // MARK: - Subscription Manager Tests
    
    func testSubscriptionManagerInitialization() {
        XCTAssertNotNil(subscriptionManager, "SubscriptionManager should initialize")
        XCTAssertFalse(subscriptionManager.isLoading, "Should not be loading initially")
        XCTAssertNil(subscriptionManager.errorMessage, "Should have no error initially")
    }
    
    func testHasActiveSubscriptionWhenEmpty() {
        XCTAssertFalse(subscriptionManager.hasActiveSubscription(), "Should not have active subscription initially")
        XCTAssertFalse(subscriptionManager.hasFamilySubscription(), "Should not have family subscription initially")
        XCTAssertFalse(subscriptionManager.hasIndividualSubscription(), "Should not have individual subscription initially")
    }
    
    // MARK: - Feature Access Manager Tests
    
    func testFeatureAccessInitialization() {
        XCTAssertNotNil(featureAccessManager, "FeatureAccessManager should initialize")
        XCTAssertFalse(featureAccessManager.isPremiumUser, "Should not be premium initially")
        XCTAssertFalse(featureAccessManager.hasFamilyAccess, "Should not have family access initially")
    }
    
    func testFreeTierLimits() {
        // Given: No subscription (free tier)
        XCTAssertFalse(featureAccessManager.isPremiumUser)
        
        // Then: Free tier limits should apply
        XCTAssertEqual(featureAccessManager.getRemainingFreeSessions(), FeatureAccessManager.FreeTierLimits.maxSessionsPerDay)
        XCTAssertEqual(featureAccessManager.getMaxSessionDuration(), TimeInterval(FeatureAccessManager.FreeTierLimits.maxSessionDuration))
        XCTAssertEqual(featureAccessManager.getMaxFamilyMembers(), FeatureAccessManager.FreeTierLimits.maxFamilyMembers)
    }
    
    func testBreathingPatternAccess() {
        // Given: Free tier user
        XCTAssertFalse(featureAccessManager.isPremiumUser)
        
        // Then: Should only access free patterns
        XCTAssertTrue(featureAccessManager.canAccessBreathingPattern("basic_4_4_4_4"), "Should access basic pattern")
        XCTAssertTrue(featureAccessManager.canAccessBreathingPattern("calm_4_7_8"), "Should access calm pattern")
        XCTAssertFalse(featureAccessManager.canAccessBreathingPattern("advanced_coherence"), "Should not access premium pattern")
    }
    
    func testSupportLevels() {
        // Given: Free tier user
        let supportLevel = featureAccessManager.getSupportLevel()
        
        // Then: Should have basic support
        XCTAssertEqual(supportLevel, .basic, "Free tier should have basic support")
        XCTAssertEqual(supportLevel.responseTime, "48-72 hours", "Basic support response time")
        XCTAssertEqual(supportLevel.channels.count, 2, "Basic support should have 2 channels")
    }
    
    func testUpgradePrompts() {
        // Given: Free tier user
        XCTAssertFalse(featureAccessManager.isPremiumUser)
        
        // Then: Should show upgrade prompts for premium features
        XCTAssertTrue(featureAccessManager.shouldShowUpgradePrompt(for: .sharePlay), "Should prompt for SharePlay")
        XCTAssertTrue(featureAccessManager.shouldShowUpgradePrompt(for: .offlineContent), "Should prompt for offline content")
        XCTAssertTrue(featureAccessManager.shouldShowUpgradePrompt(for: .familyFeatures), "Should prompt for family features")
    }
    
    func testFeatureValidation() async throws {
        // Given: Free tier user trying to access premium features
        
        // When/Then: Should throw appropriate errors
        do {
            try featureAccessManager.validateFeatureAccess(for: .sharePlay)
            XCTFail("Should throw error for SharePlay access")
        } catch FeatureAccessError.requiresFamilySubscription {
            // Expected
        }
        
        do {
            try featureAccessManager.validateFeatureAccess(for: .offlineContent)
            XCTFail("Should throw error for offline content access")
        } catch FeatureAccessError.requiresPremiumSubscription {
            // Expected
        }
    }
    
    func testSessionTracking() {
        // Given: Fresh session count
        let initialCount = featureAccessManager.getRemainingFreeSessions()
        
        // When: Recording a session
        featureAccessManager.recordSessionStart()
        
        // Then: Session count should decrease
        let newCount = featureAccessManager.getRemainingFreeSessions()
        XCTAssertEqual(newCount, initialCount - 1, "Session count should decrease by 1")
    }
    
    // MARK: - Family Validator Tests
    
    func testFamilyValidatorInitialization() {
        XCTAssertNotNil(familyValidator, "FamilyValidator should initialize")
        XCTAssertEqual(familyValidator.maxFamilyMembers, 6, "Should support 6 family members")
        XCTAssertEqual(familyValidator.currentMemberCount, 0, "Should have no members initially")
        XCTAssertEqual(familyValidator.familySubscriptionStatus, .notAvailable, "Should not have family subscription initially")
    }
    
    func testFamilyMemberPermissions() {
        // Given: Different permission levels
        let fullAccess = FamilySubscriptionValidator.MemberPermissions.fullAccess
        let organizer = FamilySubscriptionValidator.MemberPermissions.organizer
        let restricted = FamilySubscriptionValidator.MemberPermissions.restricted
        
        // Then: Permissions should have correct values
        XCTAssertTrue(fullAccess.canUseSharePlay, "Full access should allow SharePlay")
        XCTAssertTrue(fullAccess.canAccessPremiumContent, "Full access should allow premium content")
        XCTAssertFalse(fullAccess.canManageFamily, "Full access should not allow family management")
        
        XCTAssertTrue(organizer.canManageFamily, "Organizer should manage family")
        XCTAssertTrue(organizer.canUseSharePlay, "Organizer should use SharePlay")
        
        XCTAssertFalse(restricted.canAccessPremiumContent, "Restricted should not access premium content")
        XCTAssertEqual(restricted.maxSessionsPerDay, 10, "Restricted should have session limits")
    }
    
    func testFamilyMemberValidation() async throws {
        // Given: Mock family member
        let mockMember = FamilySubscriptionValidator.FamilyMember(
            memberID: "test_member",
            appleID: "test@example.com",
            displayName: "Test Member",
            hasActiveAccess: true,
            joinDate: Date(),
            lastActiveDate: Date(),
            deviceInfo: [],
            permissions: .fullAccess,
            subscriptionSource: .familyMember
        )
        
        // When: Adding mock member (simulated)
        familyValidator.familyMembers = [mockMember]
        familyValidator.currentMemberCount = 1
        familyValidator.familySubscriptionStatus = .active(organizerID: "organizer_id")
        
        // Then: Validation should work
        let isValid = await familyValidator.validateMemberAccess("test_member")
        XCTAssertTrue(isValid, "Valid member should pass validation")
        
        let invalidMember = await familyValidator.validateMemberAccess("invalid_member")
        XCTAssertFalse(invalidMember, "Invalid member should fail validation")
    }
    
    func testFamilyCapacityLimits() {
        // Given: Family validator with active subscription
        familyValidator.familySubscriptionStatus = .active(organizerID: "organizer")
        familyValidator.currentMemberCount = 5
        
        // Then: Should be able to add one more member
        XCTAssertTrue(familyValidator.canAddNewMember(), "Should be able to add member when under limit")
        XCTAssertEqual(familyValidator.getAvailableSlots(), 1, "Should have 1 slot available")
        
        // When: At maximum capacity
        familyValidator.currentMemberCount = 6
        
        // Then: Should not be able to add more members
        XCTAssertFalse(familyValidator.canAddNewMember(), "Should not add member when at limit")
        XCTAssertEqual(familyValidator.getAvailableSlots(), 0, "Should have 0 slots available")
    }
    
    // MARK: - Status Monitor Tests
    
    func testStatusMonitorInitialization() {
        XCTAssertNotNil(statusMonitor, "StatusMonitor should initialize")
        XCTAssertFalse(statusMonitor.isMonitoring, "Should not be monitoring initially")
        XCTAssertNil(statusMonitor.lastUpdateTime, "Should have no update time initially")
        XCTAssertTrue(statusMonitor.alertsEnabled, "Alerts should be enabled by default")
    }
    
    func testStatusMonitoringControls() {
        // Given: Initialized status monitor
        XCTAssertFalse(statusMonitor.isMonitoring)
        
        // When: Starting monitoring
        statusMonitor.startMonitoring()
        
        // Then: Should be monitoring
        XCTAssertTrue(statusMonitor.isMonitoring, "Should be monitoring after start")
        
        // When: Stopping monitoring
        statusMonitor.stopMonitoring()
        
        // Then: Should not be monitoring
        XCTAssertFalse(statusMonitor.isMonitoring, "Should not be monitoring after stop")
    }
    
    func testSubscriptionStatusQueries() {
        // Given: Status monitor with no statuses
        XCTAssertTrue(statusMonitor.getAllActiveStatuses().isEmpty, "Should have no active statuses initially")
        XCTAssertTrue(statusMonitor.getStatusesNeedingAttention().isEmpty, "Should have no statuses needing attention")
        
        XCTAssertFalse(statusMonitor.isSubscriptionActive(productID: "test_product"), "Should not be active for unknown product")
        XCTAssertNil(statusMonitor.getExpirationDate(for: "test_product"), "Should have no expiration for unknown product")
        XCTAssertFalse(statusMonitor.willAutoRenew(productID: "test_product"), "Should not auto-renew for unknown product")
    }
    
    func testAlertToggle() {
        // Given: Alerts enabled by default
        XCTAssertTrue(statusMonitor.alertsEnabled)
        
        // When: Toggling alerts
        statusMonitor.toggleAlerts()
        
        // Then: Alerts should be disabled
        XCTAssertFalse(statusMonitor.alertsEnabled, "Alerts should be disabled after toggle")
        
        // When: Toggling again
        statusMonitor.toggleAlerts()
        
        // Then: Alerts should be enabled
        XCTAssertTrue(statusMonitor.alertsEnabled, "Alerts should be enabled after second toggle")
    }
    
    // MARK: - Restoration Tests
    
    func testRestorationInitialization() {
        XCTAssertNotNil(restoration, "Restoration should initialize")
        XCTAssertEqual(restoration.restorationState, .idle, "Should be idle initially")
        XCTAssertTrue(restoration.restoredSubscriptions.isEmpty, "Should have no restored subscriptions initially")
        XCTAssertNil(restoration.migrationInfo, "Should have no migration info initially")
    }
    
    func testRestorationStateTransitions() {
        // Given: Restoration in idle state
        XCTAssertEqual(restoration.restorationState, .idle)
        XCTAssertFalse(restoration.restorationState.isLoading, "Idle state should not be loading")
        
        // When: Setting checking state
        restoration.restorationState = .checking
        
        // Then: Should be loading
        XCTAssertTrue(restoration.restorationState.isLoading, "Checking state should be loading")
        
        // When: Setting restoring state
        restoration.restorationState = .restoring
        
        // Then: Should still be loading
        XCTAssertTrue(restoration.restorationState.isLoading, "Restoring state should be loading")
        
        // When: Setting completed state
        let result = SubscriptionRestoration.RestoreResult(
            restoredCount: 1,
            activeSubscriptions: [],
            familySubscriptions: [],
            migrationRequired: false,
            warnings: []
        )
        restoration.restorationState = .completed(result)
        
        // Then: Should not be loading
        XCTAssertFalse(restoration.restorationState.isLoading, "Completed state should not be loading")
    }
    
    func testMigrationInfo() {
        // Given: Migration info
        let migrationInfo = SubscriptionRestoration.MigrationInfo(
            fromVersion: "1.0",
            requiredActions: [.syncData, .confirmFamilyMembers],
            benefits: ["Enhanced features", "Better performance"],
            deadline: Date().addingTimeInterval(86400 * 30) // 30 days
        )
        
        // Then: Should have correct properties
        XCTAssertEqual(migrationInfo.fromVersion, "1.0", "From version should match")
        XCTAssertEqual(migrationInfo.requiredActions.count, 2, "Should have 2 required actions")
        XCTAssertEqual(migrationInfo.benefits.count, 2, "Should have 2 benefits")
        XCTAssertNotNil(migrationInfo.deadline, "Should have deadline")
    }
    
    func testRestoredSubscription() {
        // Given: Mock product and transaction
        // This would typically use real StoreKit objects in integration tests
        
        // Create mock restored subscription
        let mockTransaction = createMockTransaction()
        let mockProduct = createMockProduct()
        
        let restoredSubscription = SubscriptionRestoration.RestoredSubscription(
            product: mockProduct,
            transaction: mockTransaction,
            expirationDate: Date().addingTimeInterval(86400 * 30),
            isActive: true,
            isFamilyShared: false,
            originalPurchaseDate: Date().addingTimeInterval(-86400)
        )
        
        // Then: Should have correct properties
        XCTAssertTrue(restoredSubscription.isActive, "Should be active")
        XCTAssertFalse(restoredSubscription.isFamilyShared, "Should not be family shared")
        XCTAssertNotNil(restoredSubscription.expirationDate, "Should have expiration date")
    }
    
    // MARK: - Integration Tests
    
    func testSubscriptionManagerIntegration() async throws {
        // Given: Integrated system
        await subscriptionManager.loadProducts()
        
        // Then: Feature access manager should respond to changes
        XCTAssertFalse(featureAccessManager.isPremiumUser, "Should not be premium initially")
        
        // When: Simulating subscription activation (would be real purchase in integration test)
        // This is where we'd need actual StoreKit sandbox testing
        
        // For unit test, we can test the logic paths
        let hasSubscription = subscriptionManager.hasActiveSubscription()
        XCTAssertFalse(hasSubscription, "Should not have subscription in unit test environment")
    }
    
    func testFamilyValidatorIntegration() async throws {
        // Given: Family validator with subscription manager
        await familyValidator.validateFamilySubscription()
        
        // Then: Should complete validation without errors
        XCTAssertFalse(familyValidator.isValidatingFamily, "Should not be validating after completion")
        
        // Family subscription should not be available in unit test environment
        XCTAssertEqual(familyValidator.familySubscriptionStatus, .notAvailable)
    }
    
    // MARK: - Error Handling Tests
    
    func testFeatureAccessErrors() {
        let dailyLimitError = FeatureAccessError.dailyLimitReached
        let premiumRequiredError = FeatureAccessError.requiresPremiumSubscription
        let familyRequiredError = FeatureAccessError.requiresFamilySubscription
        
        XCTAssertNotNil(dailyLimitError.errorDescription, "Should have error description")
        XCTAssertNotNil(dailyLimitError.recoverySuggestion, "Should have recovery suggestion")
        
        XCTAssertNotNil(premiumRequiredError.errorDescription, "Should have error description")
        XCTAssertNotNil(premiumRequiredError.recoverySuggestion, "Should have recovery suggestion")
        
        XCTAssertNotNil(familyRequiredError.errorDescription, "Should have error description")
        XCTAssertNotNil(familyRequiredError.recoverySuggestion, "Should have recovery suggestion")
    }
    
    func testFamilyValidationErrors() {
        let memberNotFoundError = FamilyValidationError.memberNotFound
        let maxMembersError = FamilyValidationError.maxMembersReached
        let insufficientPermissionsError = FamilyValidationError.insufficientPermissions
        
        XCTAssertNotNil(memberNotFoundError.errorDescription, "Should have error description")
        XCTAssertNotNil(memberNotFoundError.recoverySuggestion, "Should have recovery suggestion")
        
        XCTAssertNotNil(maxMembersError.errorDescription, "Should have error description")
        XCTAssertNotNil(maxMembersError.recoverySuggestion, "Should have recovery suggestion")
        
        XCTAssertNotNil(insufficientPermissionsError.errorDescription, "Should have error description")
        XCTAssertNotNil(insufficientPermissionsError.recoverySuggestion, "Should have recovery suggestion")
    }
    
    func testRestorationErrors() {
        let verificationError = RestorationError.verificationFailed
        let syncError = RestorationError.syncFailed
        let networkError = RestorationError.networkError
        
        XCTAssertNotNil(verificationError.errorDescription, "Should have error description")
        XCTAssertNotNil(verificationError.recoverySuggestion, "Should have recovery suggestion")
        
        XCTAssertNotNil(syncError.errorDescription, "Should have error description")
        XCTAssertNotNil(syncError.recoverySuggestion, "Should have recovery suggestion")
        
        XCTAssertNotNil(networkError.errorDescription, "Should have error description")
        XCTAssertNotNil(networkError.recoverySuggestion, "Should have recovery suggestion")
    }
    
    // MARK: - Performance Tests
    
    func testProductLoadingPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "Product loading")
            
            Task {
                await subscriptionManager.loadProducts()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testFeatureValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = featureAccessManager.canStartNewSession()
                _ = featureAccessManager.canAccessPremiumContent()
                _ = featureAccessManager.canAccessSharePlay()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockTransaction() -> Transaction {
        // In a real test, this would create a proper Transaction object
        // For now, returning a placeholder - actual implementation would need StoreKit testing
        fatalError("Mock transaction creation not implemented - use StoreKit testing environment")
    }
    
    private func createMockProduct() -> Product {
        // In a real test, this would create a proper Product object
        // For now, returning a placeholder - actual implementation would need StoreKit testing
        fatalError("Mock product creation not implemented - use StoreKit testing environment")
    }
}