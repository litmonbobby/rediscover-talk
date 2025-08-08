//
//  SubscriptionRestoration.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  Advanced subscription restoration and validation system
//

import Foundation
import StoreKit
import Combine
import OSLog

/// Handles subscription restoration across devices and accounts
@MainActor
class SubscriptionRestoration: ObservableObject {
    
    // MARK: - Published Properties
    @Published var restorationState: RestorationState = .idle
    @Published var restoredSubscriptions: [RestoredSubscription] = []
    @Published var migrationInfo: MigrationInfo?
    @Published var familyMembersStatus: [FamilyMemberStatus] = []
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "SubscriptionRestoration")
    private let subscriptionManager: SubscriptionManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Restoration State
    enum RestorationState {
        case idle
        case checking
        case restoring
        case validating
        case completed(RestoreResult)
        case failed(Error)
        
        var isLoading: Bool {
            switch self {
            case .checking, .restoring, .validating:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Restore Result
    struct RestoreResult {
        let restoredCount: Int
        let activeSubscriptions: [Product]
        let familySubscriptions: [Product]
        let migrationRequired: Bool
        let warnings: [String]
    }
    
    // MARK: - Restored Subscription
    struct RestoredSubscription {
        let product: Product
        let transaction: Transaction
        let expirationDate: Date?
        let isActive: Bool
        let isFamilyShared: Bool
        let originalPurchaseDate: Date
    }
    
    // MARK: - Migration Info
    struct MigrationInfo {
        let fromVersion: String
        let requiredActions: [MigrationAction]
        let benefits: [String]
        let deadline: Date?
    }
    
    enum MigrationAction {
        case updateBilling
        case confirmFamilyMembers
        case acceptNewTerms
        case syncData
        
        var description: String {
            switch self {
            case .updateBilling:
                return "Update billing information"
            case .confirmFamilyMembers:
                return "Confirm family members"
            case .acceptNewTerms:
                return "Accept updated terms"
            case .syncData:
                return "Sync subscription data"
            }
        }
    }
    
    // MARK: - Family Member Status
    struct FamilyMemberStatus {
        let memberID: String
        let name: String
        let hasAccess: Bool
        let lastActive: Date?
        let deviceCount: Int
    }
    
    // MARK: - Initialization
    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
        setupSubscriptionListener()
    }
    
    // MARK: - Setup
    private func setupSubscriptionListener() {
        subscriptionManager.$purchasedProducts
            .sink { [weak self] products in
                Task {
                    await self?.validateRestoredProducts(products)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Main Restoration Flow
    func restoreAllPurchases() async {
        logger.info("Starting comprehensive purchase restoration")
        restorationState = .checking
        
        do {
            // Step 1: Check current entitlements
            let currentEntitlements = await getCurrentEntitlements()
            
            // Step 2: Sync with App Store
            restorationState = .restoring
            try await AppStore.sync()
            
            // Step 3: Validate restored transactions
            restorationState = .validating
            let restoredProducts = await validateAndRestoreTransactions()
            
            // Step 4: Check for family sharing
            let familyStatus = await validateFamilySharing()
            
            // Step 5: Check for migration needs
            let migration = await checkMigrationRequirements()
            
            // Step 6: Generate restoration result
            let result = RestoreResult(
                restoredCount: restoredProducts.count,
                activeSubscriptions: restoredProducts.filter { $0.isActive }.map { $0.product },
                familySubscriptions: restoredProducts.filter { $0.isFamilyShared }.map { $0.product },
                migrationRequired: migration != nil,
                warnings: generateWarnings(restoredProducts: restoredProducts, familyStatus: familyStatus)
            )
            
            restoredSubscriptions = restoredProducts
            migrationInfo = migration
            familyMembersStatus = familyStatus
            restorationState = .completed(result)
            
            logger.info("Restoration completed successfully. Restored \(result.restoredCount) subscriptions")
            
        } catch {
            restorationState = .failed(error)
            logger.error("Restoration failed: \(error)")
        }
    }
    
    // MARK: - Current Entitlements
    private func getCurrentEntitlements() async -> [Transaction] {
        var transactions: [Transaction] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                transactions.append(transaction)
            } catch {
                logger.error("Failed to verify current entitlement: \(error)")
            }
        }
        
        return transactions
    }
    
    // MARK: - Transaction Validation and Restoration
    private func validateAndRestoreTransactions() async -> [RestoredSubscription] {
        var restoredSubscriptions: [RestoredSubscription] = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Find corresponding product
                guard let product = subscriptionManager.availableProducts.first(where: { $0.id == transaction.productID }) else {
                    logger.warning("Product not found for transaction: \(transaction.productID)")
                    continue
                }
                
                // Get subscription status
                let subscriptionInfo = await getSubscriptionInfo(for: product)
                let isActive = subscriptionInfo?.isActive ?? false
                let expirationDate = subscriptionInfo?.expirationDate
                
                // Check if family shared
                let isFamilyShared = await checkIfFamilyShared(transaction: transaction)
                
                let restored = RestoredSubscription(
                    product: product,
                    transaction: transaction,
                    expirationDate: expirationDate,
                    isActive: isActive,
                    isFamilyShared: isFamilyShared,
                    originalPurchaseDate: transaction.originalPurchaseDate
                )
                
                restoredSubscriptions.append(restored)
                logger.info("Restored subscription: \(product.displayName), Active: \(isActive)")
                
            } catch {
                logger.error("Failed to restore transaction: \(error)")
            }
        }
        
        return restoredSubscriptions
    }
    
    // MARK: - Subscription Info
    private func getSubscriptionInfo(for product: Product) async -> SubscriptionInfo? {
        guard let subscription = product.subscription else { return nil }
        
        do {
            let statuses = try await subscription.status
            guard let status = statuses.first else { return nil }
            
            return SubscriptionInfo(
                isActive: status.value.state == .subscribed,
                expirationDate: status.value.expirationDate,
                renewalDate: status.value.renewalDate,
                willAutoRenew: status.value.willAutoRenew
            )
        } catch {
            logger.error("Failed to get subscription info: \(error)")
            return nil
        }
    }
    
    private struct SubscriptionInfo {
        let isActive: Bool
        let expirationDate: Date?
        let renewalDate: Date?
        let willAutoRenew: Bool
    }
    
    // MARK: - Family Sharing Validation
    private func checkIfFamilyShared(transaction: Transaction) async -> Bool {
        // In StoreKit 2, family sharing is indicated by the transaction's ownership type
        // This is a simplified implementation - actual implementation would check more thoroughly
        return transaction.ownershipType == .familyShared
    }
    
    private func validateFamilySharing() async -> [FamilyMemberStatus] {
        var familyMembers: [FamilyMemberStatus] = []
        
        // Check for family subscriptions in current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == SubscriptionManager.SubscriptionProducts.family.rawValue {
                    // This would typically involve checking with your backend for family member information
                    // For now, we'll create mock data
                    familyMembers = await generateMockFamilyMemberStatus()
                    break
                }
            } catch {
                logger.error("Failed to validate family sharing: \(error)")
            }
        }
        
        return familyMembers
    }
    
    private func generateMockFamilyMemberStatus() async -> [FamilyMemberStatus] {
        // This would typically come from your backend service
        return [
            FamilyMemberStatus(
                memberID: "member_1",
                name: "Family Member 1",
                hasAccess: true,
                lastActive: Date().addingTimeInterval(-3600),
                deviceCount: 2
            ),
            FamilyMemberStatus(
                memberID: "member_2",
                name: "Family Member 2",
                hasAccess: true,
                lastActive: Date().addingTimeInterval(-86400),
                deviceCount: 1
            )
        ]
    }
    
    // MARK: - Migration Requirements
    private func checkMigrationRequirements() async -> MigrationInfo? {
        // Check if user needs to migrate from older subscription system
        let lastMigrationVersion = UserDefaults.standard.string(forKey: "lastMigrationVersion")
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        
        if lastMigrationVersion == nil || lastMigrationVersion != currentVersion {
            return MigrationInfo(
                fromVersion: lastMigrationVersion ?? "Unknown",
                requiredActions: [.syncData, .confirmFamilyMembers],
                benefits: [
                    "Enhanced family sharing features",
                    "Improved offline sync",
                    "Better progress tracking"
                ],
                deadline: Calendar.current.date(byAdding: .day, value: 30, to: Date())
            )
        }
        
        return nil
    }
    
    // MARK: - Warning Generation
    private func generateWarnings(restoredProducts: [RestoredSubscription], familyStatus: [FamilyMemberStatus]) -> [String] {
        var warnings: [String] = []
        
        // Check for expired subscriptions
        let expired = restoredProducts.filter { !$0.isActive }
        if !expired.isEmpty {
            warnings.append("Found \(expired.count) expired subscription(s)")
        }
        
        // Check for family access issues
        let inactiveFamilyMembers = familyStatus.filter { !$0.hasAccess }
        if !inactiveFamilyMembers.isEmpty {
            warnings.append("\(inactiveFamilyMembers.count) family member(s) need to renew access")
        }
        
        // Check for multiple active subscriptions (unusual case)
        let activeIndividual = restoredProducts.filter { $0.isActive && $0.product.id == SubscriptionManager.SubscriptionProducts.individual.rawValue }
        let activeFamily = restoredProducts.filter { $0.isActive && $0.product.id == SubscriptionManager.SubscriptionProducts.family.rawValue }
        
        if !activeIndividual.isEmpty && !activeFamily.isEmpty {
            warnings.append("Multiple active subscriptions detected - consider managing duplicates")
        }
        
        return warnings
    }
    
    // MARK: - Transaction Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw RestorationError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Product Validation
    private func validateRestoredProducts(_ products: [Product]) async {
        logger.info("Validating \(products.count) restored products")
        
        for product in products {
            // Validate product configuration
            if product.type == .autoRenewable {
                await validateSubscriptionProduct(product)
            }
        }
    }
    
    private func validateSubscriptionProduct(_ product: Product) async {
        guard let subscription = product.subscription else {
            logger.warning("Subscription info missing for product: \(product.id)")
            return
        }
        
        do {
            let statuses = try await subscription.status
            for statusResult in statuses {
                let status = statusResult.value
                logger.info("Product \(product.displayName) status: \(status.state)")
                
                if status.state == .subscribed {
                    logger.info("Active subscription validated for \(product.displayName)")
                } else if status.state == .expired {
                    logger.warning("Expired subscription found for \(product.displayName)")
                }
            }
        } catch {
            logger.error("Failed to validate subscription product \(product.id): \(error)")
        }
    }
    
    // MARK: - Manual Actions
    func completeMigration() async {
        guard let migration = migrationInfo else { return }
        
        // Mark migration as completed
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        UserDefaults.standard.set(currentVersion, forKey: "lastMigrationVersion")
        
        // Clear migration info
        migrationInfo = nil
        
        logger.info("Migration completed for version \(currentVersion)")
    }
    
    func refreshFamilyStatus() async {
        familyMembersStatus = await validateFamilySharing()
        logger.info("Refreshed family member status")
    }
    
    func retryRestoration() async {
        logger.info("Retrying restoration process")
        await restoreAllPurchases()
    }
}

// MARK: - Restoration Errors
enum RestorationError: LocalizedError {
    case verificationFailed
    case syncFailed
    case invalidProduct
    case networkError
    case migrationRequired
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Failed to verify purchase authenticity"
        case .syncFailed:
            return "Failed to sync with App Store"
        case .invalidProduct:
            return "Invalid product configuration"
        case .networkError:
            return "Network connection required"
        case .migrationRequired:
            return "Subscription migration required"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .verificationFailed:
            return "Please contact support if this persists"
        case .syncFailed:
            return "Try again or check your internet connection"
        case .invalidProduct:
            return "Update the app to the latest version"
        case .networkError:
            return "Connect to the internet and try again"
        case .migrationRequired:
            return "Complete the migration process to continue"
        }
    }
}