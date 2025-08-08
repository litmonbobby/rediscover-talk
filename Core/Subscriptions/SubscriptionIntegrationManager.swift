//
//  SubscriptionIntegrationManager.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  Central integration point for all subscription functionality
//

import Foundation
import StoreKit
import Combine
import OSLog
import SwiftUI

/// Central coordinator for all subscription-related functionality
@MainActor
class SubscriptionIntegrationManager: ObservableObject {
    
    // MARK: - Core Components
    let subscriptionManager: SubscriptionManager
    let featureAccessManager: FeatureAccessManager
    let familyValidator: FamilySubscriptionValidator
    let statusMonitor: SubscriptionStatusMonitor
    let restoration: SubscriptionRestoration
    
    // MARK: - Published Properties
    @Published var isFullyInitialized = false
    @Published var systemHealth: SystemHealth = .initializing
    @Published var lastValidationTime: Date?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "SubscriptionIntegration")
    private var cancellables = Set<AnyCancellable>()
    private var validationTimer: Timer?
    
    // MARK: - System Health
    enum SystemHealth {
        case initializing
        case healthy
        case degraded(issues: [String])
        case critical(error: Error)
        
        var isHealthy: Bool {
            switch self {
            case .healthy:
                return true
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .initializing:
                return "Initializing subscription system"
            case .healthy:
                return "All subscription services operational"
            case .degraded(let issues):
                return "Some issues detected: \(issues.joined(separator: ", "))"
            case .critical(let error):
                return "Critical error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    init() {
        // Initialize core components
        self.subscriptionManager = SubscriptionManager()
        self.featureAccessManager = FeatureAccessManager(subscriptionManager: subscriptionManager)
        self.familyValidator = FamilySubscriptionValidator(subscriptionManager: subscriptionManager)
        self.statusMonitor = SubscriptionStatusMonitor(subscriptionManager: subscriptionManager)
        self.restoration = SubscriptionRestoration(subscriptionManager: subscriptionManager)
        
        setupIntegration()
        
        Task {
            await initializeSystem()
        }
    }
    
    // MARK: - System Setup
    private func setupIntegration() {
        // Monitor subscription changes
        subscriptionManager.$purchasedProducts
            .sink { [weak self] products in
                self?.handleSubscriptionChange(products: products)
            }
            .store(in: &cancellables)
        
        // Monitor family validation status
        familyValidator.$familySubscriptionStatus
            .sink { [weak self] status in
                self?.handleFamilyStatusChange(status: status)
            }
            .store(in: &cancellables)
        
        // Monitor system errors
        subscriptionManager.$errorMessage
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleSystemError(error)
            }
            .store(in: &cancellables)
        
        // Start periodic health checks
        startHealthMonitoring()
    }
    
    private func initializeSystem() async {
        logger.info("Initializing subscription system")
        systemHealth = .initializing
        
        do {
            // Step 1: Load products
            await subscriptionManager.loadProducts()
            logger.info("Products loaded successfully")
            
            // Step 2: Update purchased products
            await subscriptionManager.updatePurchasedProducts()
            logger.info("Purchased products updated")
            
            // Step 3: Validate family subscription
            await familyValidator.validateFamilySubscription()
            logger.info("Family subscription validated")
            
            // Step 4: Start status monitoring
            statusMonitor.startMonitoring()
            logger.info("Status monitoring started")
            
            // Step 5: System health check
            await performHealthCheck()
            
            isFullyInitialized = true
            logger.info("Subscription system fully initialized")
            
        } catch {
            systemHealth = .critical(error: error)
            logger.error("Failed to initialize subscription system: \(error)")
        }
    }
    
    // MARK: - Health Monitoring
    private func startHealthMonitoring() {
        validationTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }
    }
    
    private func performHealthCheck() async {
        logger.info("Performing system health check")
        var issues: [String] = []
        
        // Check subscription manager health
        if subscriptionManager.availableProducts.isEmpty {
            issues.append("No products loaded")
        }
        
        if subscriptionManager.isLoading {
            issues.append("Products still loading")
        }
        
        // Check feature access consistency
        let hasSubscription = subscriptionManager.hasActiveSubscription()
        let isPremiumUser = featureAccessManager.isPremiumUser
        
        if hasSubscription != isPremiumUser {
            issues.append("Feature access inconsistency")
        }
        
        // Check family validation health
        if familyValidator.isValidatingFamily {
            issues.append("Family validation stuck")
        }
        
        // Check status monitoring
        if !statusMonitor.isMonitoring && hasSubscription {
            issues.append("Status monitoring not active")
        }
        
        // Update system health
        if issues.isEmpty {
            systemHealth = .healthy
        } else {
            systemHealth = .degraded(issues: issues)
        }
        
        lastValidationTime = Date()
        logger.info("Health check completed. Status: \(systemHealth.description)")
    }
    
    // MARK: - Event Handlers
    private func handleSubscriptionChange(products: [Product]) {
        logger.info("Subscription change detected: \(products.count) products")
        
        Task {
            // Trigger family validation update
            await familyValidator.refreshFamilyStatus()
            
            // Update system health
            await performHealthCheck()
        }
    }
    
    private func handleFamilyStatusChange(status: FamilySubscriptionValidator.FamilySubscriptionStatus) {
        logger.info("Family status changed: \(status.description)")
        
        // Update feature access based on family status
        if case .active = status {
            logger.info("Family subscription active - updating feature access")
        }
    }
    
    private func handleSystemError(_ error: String) {
        logger.error("System error reported: \(error)")
        systemHealth = .degraded(issues: [error])
    }
    
    // MARK: - Public API
    
    /// Comprehensive subscription validation
    func validateFullSubscriptionAccess() async -> SubscriptionValidationResult {
        logger.info("Performing comprehensive subscription validation")
        
        var result = SubscriptionValidationResult()
        
        // 1. Validate basic subscription access
        result.hasActiveSubscription = subscriptionManager.hasActiveSubscription()
        result.hasIndividualSubscription = subscriptionManager.hasIndividualSubscription()
        result.hasFamilySubscription = subscriptionManager.hasFamilySubscription()
        
        // 2. Validate feature access
        result.canAccessPremiumContent = featureAccessManager.canAccessPremiumContent()
        result.canAccessOfflineContent = featureAccessManager.canDownloadForOffline()
        result.canUseUnlimitedSessions = featureAccessManager.hasUnlimitedSessions
        
        // 3. Validate family features
        result.canAccessSharePlay = featureAccessManager.canAccessSharePlay()
        result.canAccessFamilyDashboard = familyValidator.canAccessFamilyDashboard()
        result.familyMemberCount = familyValidator.currentMemberCount
        result.maxFamilyMembers = familyValidator.maxFamilyMembers
        
        // 4. Validate family member access
        if result.hasFamilySubscription {
            let activeFamilyMembers = familyValidator.getActiveFamilyMembers()
            result.activeFamilyMemberIDs = activeFamilyMembers.map { $0.memberID }
            
            // Validate SharePlay access for family members
            let memberIDs = activeFamilyMembers.map { $0.memberID }
            result.sharePlayAccessByMember = await familyValidator.validateSharePlayAccess(for: memberIDs)
        }
        
        // 5. Validate subscription status
        result.subscriptionStatuses = statusMonitor.getAllActiveStatuses().map { status in
            SubscriptionValidationResult.SubscriptionStatusInfo(
                productID: status.productID,
                isActive: status.isActive,
                willAutoRenew: status.willAutoRenew,
                expirationDate: status.expirationDate,
                needsAttention: status.needsAttention
            )
        }
        
        // 6. System health validation
        result.systemHealth = systemHealth
        result.validationTimestamp = Date()
        
        logger.info("Comprehensive validation completed: \(result.summary)")
        return result
    }
    
    /// Purchase a subscription with full validation
    func purchaseSubscription(_ productID: String) async -> PurchaseResult {
        logger.info("Initiating subscription purchase: \(productID)")
        
        guard let product = subscriptionManager.availableProducts.first(where: { $0.id == productID }) else {
            return .failed(error: "Product not found: \(productID)")
        }
        
        // Pre-purchase validation
        do {
            try await validatePurchaseEligibility(product)
        } catch {
            return .failed(error: error.localizedDescription)
        }
        
        // Attempt purchase
        let success = await subscriptionManager.purchase(product)
        
        if success {
            // Post-purchase validation
            await validatePostPurchase(product)
            return .success(product: product)
        } else {
            return .failed(error: subscriptionManager.errorMessage ?? "Purchase failed")
        }
    }
    
    /// Restore purchases with comprehensive validation
    func restorePurchases() async -> RestoreResult {
        logger.info("Initiating purchase restoration")
        
        // Perform restoration
        await restoration.restoreAllPurchases()
        
        switch restoration.restorationState {
        case .completed(let restoreResult):
            // Validate restored access
            let validationResult = await validateFullSubscriptionAccess()
            
            return RestoreResult(
                success: true,
                restoredCount: restoreResult.restoredCount,
                activeSubscriptions: restoreResult.activeSubscriptions,
                familySubscriptions: restoreResult.familySubscriptions,
                validationResult: validationResult,
                warnings: restoreResult.warnings
            )
            
        case .failed(let error):
            return RestoreResult(
                success: false,
                restoredCount: 0,
                activeSubscriptions: [],
                familySubscriptions: [],
                validationResult: nil,
                warnings: ["Restoration failed: \(error.localizedDescription)"]
            )
            
        default:
            return RestoreResult(
                success: false,
                restoredCount: 0,
                activeSubscriptions: [],
                familySubscriptions: [],
                validationResult: nil,
                warnings: ["Restoration in unexpected state"]
            )
        }
    }
    
    /// Validate specific feature access
    func validateFeatureAccess(feature: FeatureAccessManager.PremiumFeature) async -> FeatureValidationResult {
        do {
            try featureAccessManager.validateFeatureAccess(for: feature)
            
            return FeatureValidationResult(
                feature: feature,
                hasAccess: true,
                error: nil,
                upgradeRequired: nil
            )
        } catch let error as FeatureAccessError {
            return FeatureValidationResult(
                feature: feature,
                hasAccess: false,
                error: error,
                upgradeRequired: feature.requiredSubscription
            )
        } catch {
            return FeatureValidationResult(
                feature: feature,
                hasAccess: false,
                error: FeatureAccessError.unknown,
                upgradeRequired: feature.requiredSubscription
            )
        }
    }
    
    // MARK: - Purchase Validation
    private func validatePurchaseEligibility(_ product: Product) async throws {
        // Check if already subscribed to this product
        if subscriptionManager.purchasedProducts.contains(where: { $0.id == product.id }) {
            throw PurchaseError.alreadySubscribed
        }
        
        // Check for conflicting subscriptions (e.g., can't have both individual and family)
        if product.id == SubscriptionManager.SubscriptionProducts.individual.rawValue &&
           subscriptionManager.hasFamilySubscription() {
            throw PurchaseError.conflictingSubscription
        }
        
        if product.id == SubscriptionManager.SubscriptionProducts.family.rawValue &&
           subscriptionManager.hasIndividualSubscription() {
            // This is an upgrade - allow it
            logger.info("Upgrading from individual to family subscription")
        }
    }
    
    private func validatePostPurchase(_ product: Product) async {
        logger.info("Validating post-purchase state for: \(product.displayName)")
        
        // Give the system a moment to process the purchase
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Update all components
        await subscriptionManager.updatePurchasedProducts()
        await familyValidator.validateFamilySubscription()
        await performHealthCheck()
        
        // Verify purchase took effect
        let hasActiveSubscription = subscriptionManager.hasActiveSubscription()
        if !hasActiveSubscription {
            logger.warning("Purchase completed but no active subscription detected")
        } else {
            logger.info("Purchase validation successful")
        }
    }
    
    // MARK: - System Control
    func forceRefreshAllComponents() async {
        logger.info("Force refreshing all subscription components")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.subscriptionManager.loadProducts()
                await self.subscriptionManager.updatePurchasedProducts()
            }
            
            group.addTask {
                await self.familyValidator.refreshFamilyStatus()
            }
            
            group.addTask {
                await self.statusMonitor.refreshAllStatuses()
            }
            
            group.addTask {
                await self.performHealthCheck()
            }
        }
        
        logger.info("Component refresh completed")
    }
    
    func resetSystemState() {
        logger.info("Resetting subscription system state")
        
        // Stop monitoring
        statusMonitor.stopMonitoring()
        validationTimer?.invalidate()
        validationTimer = nil
        
        // Reset state
        isFullyInitialized = false
        systemHealth = .initializing
        
        // Restart system
        Task {
            await initializeSystem()
        }
    }
    
    deinit {
        validationTimer?.invalidate()
        statusMonitor.stopMonitoring()
    }
}

// MARK: - Result Types

struct SubscriptionValidationResult {
    var hasActiveSubscription = false
    var hasIndividualSubscription = false
    var hasFamilySubscription = false
    var canAccessPremiumContent = false
    var canAccessOfflineContent = false
    var canUseUnlimitedSessions = false
    var canAccessSharePlay = false
    var canAccessFamilyDashboard = false
    var familyMemberCount = 0
    var maxFamilyMembers = 6
    var activeFamilyMemberIDs: [String] = []
    var sharePlayAccessByMember: [String: Bool] = [:]
    var subscriptionStatuses: [SubscriptionStatusInfo] = []
    var systemHealth: SubscriptionIntegrationManager.SystemHealth = .initializing
    var validationTimestamp = Date()
    
    struct SubscriptionStatusInfo {
        let productID: String
        let isActive: Bool
        let willAutoRenew: Bool
        let expirationDate: Date?
        let needsAttention: Bool
    }
    
    var summary: String {
        return """
        Subscription Validation Summary:
        - Active Subscription: \(hasActiveSubscription)
        - Individual: \(hasIndividualSubscription)
        - Family: \(hasFamilySubscription)
        - Premium Content: \(canAccessPremiumContent)
        - SharePlay: \(canAccessSharePlay)
        - Family Members: \(familyMemberCount)/\(maxFamilyMembers)
        - System Health: \(systemHealth.description)
        """
    }
}

enum PurchaseResult {
    case success(product: Product)
    case failed(error: String)
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failed:
            return false
        }
    }
}

struct RestoreResult {
    let success: Bool
    let restoredCount: Int
    let activeSubscriptions: [Product]
    let familySubscriptions: [Product]
    let validationResult: SubscriptionValidationResult?
    let warnings: [String]
}

struct FeatureValidationResult {
    let feature: FeatureAccessManager.PremiumFeature
    let hasAccess: Bool
    let error: FeatureAccessError?
    let upgradeRequired: SubscriptionManager.SubscriptionProducts?
}

enum PurchaseError: LocalizedError {
    case alreadySubscribed
    case conflictingSubscription
    case productNotAvailable
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .alreadySubscribed:
            return "Already subscribed to this product"
        case .conflictingSubscription:
            return "Conflicting subscription exists"
        case .productNotAvailable:
            return "Product not available for purchase"
        case .networkError:
            return "Network error occurred"
        }
    }
}