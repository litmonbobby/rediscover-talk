//
//  SubscriptionManager.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  StoreKit 2 subscription management system
//

import Foundation
import StoreKit
import Combine
import OSLog

/// Main subscription manager for Rediscover Talk app
@MainActor
class SubscriptionManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var availableProducts: [Product] = []
    @Published var purchasedProducts: [Product] = []
    @Published var subscriptionStatus: [String: Product.SubscriptionInfo.Status] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "SubscriptionManager")
    private var transactionListener: Task<Void, Error>?
    private var subscriptions = Set<AnyCancellable>()
    
    // MARK: - Product Identifiers
    enum SubscriptionProducts: String, CaseIterable {
        case individual = "rediscover_talk_individual_monthly"
        case family = "rediscover_talk_family_monthly"
        
        var displayName: String {
            switch self {
            case .individual: return "Individual Plan"
            case .family: return "Family Plan"
            }
        }
        
        var features: [String] {
            switch self {
            case .individual:
                return [
                    "Personal breathing sessions",
                    "Progress tracking",
                    "Offline access",
                    "Premium content"
                ]
            case .family:
                return [
                    "Up to 6 family members",
                    "SharePlay breathing sessions",
                    "Family progress dashboard",
                    "All Individual features",
                    "Priority support"
                ]
            }
        }
    }
    
    // MARK: - Subscription Group
    static let subscriptionGroupID = "rediscover_talk_subscriptions"
    
    // MARK: - Initialization
    init() {
        startTransactionListener()
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Product Loading
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let productIdentifiers = SubscriptionProducts.allCases.map { $0.rawValue }
            let products = try await Product.products(for: Set(productIdentifiers))
            
            await MainActor.run {
                self.availableProducts = products.sorted { $0.price < $1.price }
                self.isLoading = false
                self.logger.info("Loaded \(products.count) products")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load products: \(error.localizedDescription)"
                self.isLoading = false
                self.logger.error("Failed to load products: \(error)")
            }
        }
    }
    
    // MARK: - Purchase Flow
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updatePurchasedProducts()
                
                await MainActor.run {
                    self.isLoading = false
                    self.logger.info("Successfully purchased \(product.displayName)")
                }
                return true
                
            case .userCancelled:
                await MainActor.run {
                    self.isLoading = false
                    self.logger.info("User cancelled purchase")
                }
                return false
                
            case .pending:
                await MainActor.run {
                    self.errorMessage = "Purchase is pending approval"
                    self.isLoading = false
                    self.logger.info("Purchase pending approval")
                }
                return false
                
            @unknown default:
                await MainActor.run {
                    self.errorMessage = "Unknown purchase result"
                    self.isLoading = false
                    self.logger.error("Unknown purchase result")
                }
                return false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Purchase failed: \(error.localizedDescription)"
                self.isLoading = false
                self.logger.error("Purchase failed: \(error)")
            }
            return false
        }
    }
    
    // MARK: - Restore Purchases
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            
            await MainActor.run {
                self.isLoading = false
                self.logger.info("Successfully restored purchases")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
                self.isLoading = false
                self.logger.error("Failed to restore purchases: \(error)")
            }
        }
    }
    
    // MARK: - Subscription Status
    func updatePurchasedProducts() async {
        var purchasedProducts: [Product] = []
        var subscriptionStatuses: [String: Product.SubscriptionInfo.Status] = [:]
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if let product = availableProducts.first(where: { $0.id == transaction.productID }) {
                    purchasedProducts.append(product)
                    
                    // Get subscription status for auto-renewable subscriptions
                    if case .autoRenewable = product.type {
                        await updateSubscriptionStatus(for: product.id)
                    }
                }
            } catch {
                logger.error("Failed to verify transaction: \(error)")
            }
        }
        
        await MainActor.run {
            self.purchasedProducts = purchasedProducts
            self.logger.info("Updated purchased products: \(purchasedProducts.count)")
        }
    }
    
    private func updateSubscriptionStatus(for productID: String) async {
        do {
            guard let product = availableProducts.first(where: { $0.id == productID }),
                  let subscription = product.subscription else { return }
            
            let statuses = try await subscription.status
            
            await MainActor.run {
                if let status = statuses.first?.value {
                    self.subscriptionStatus[productID] = status
                    self.logger.info("Updated subscription status for \(productID): \(status)")
                }
            }
        } catch {
            logger.error("Failed to update subscription status for \(productID): \(error)")
        }
    }
    
    // MARK: - Transaction Listener
    private func startTransactionListener() {
        transactionListener = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    self.logger.error("Transaction update failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Transaction Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Access Control
    func hasActiveSubscription() -> Bool {
        return !purchasedProducts.isEmpty
    }
    
    func hasFamilySubscription() -> Bool {
        return purchasedProducts.contains { product in
            product.id == SubscriptionProducts.family.rawValue
        }
    }
    
    func hasIndividualSubscription() -> Bool {
        return purchasedProducts.contains { product in
            product.id == SubscriptionProducts.individual.rawValue
        }
    }
    
    func canAccessFamilyFeatures() -> Bool {
        return hasFamilySubscription()
    }
    
    func canAccessPremiumContent() -> Bool {
        return hasActiveSubscription()
    }
    
    // MARK: - Family Sharing Validation
    func validateFamilyAccess() async -> Bool {
        // Check if user has access through family sharing
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == SubscriptionProducts.family.rawValue {
                    // User has access to family subscription
                    logger.info("User has family subscription access")
                    return true
                }
            } catch {
                logger.error("Failed to verify family transaction: \(error)")
            }
        }
        
        return false
    }
    
    // MARK: - Subscription Management
    func getSubscriptionInfo(for productID: String) async -> Product.SubscriptionInfo? {
        guard let product = availableProducts.first(where: { $0.id == productID }) else {
            return nil
        }
        return product.subscription
    }
    
    func getSubscriptionGroupStatus() async -> [Product.SubscriptionInfo.Status] {
        var statuses: [Product.SubscriptionInfo.Status] = []
        
        for product in availableProducts {
            if let subscription = product.subscription {
                do {
                    let statusResults = try await subscription.status
                    statuses.append(contentsOf: statusResults.map { $0.value })
                } catch {
                    logger.error("Failed to get subscription status: \(error)")
                }
            }
        }
        
        return statuses
    }
}

// MARK: - StoreError
enum StoreError: Error {
    case failedVerification
    case purchaseNotAllowed
    case unknown
}

extension StoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        case .purchaseNotAllowed:
            return "Purchase not allowed"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}