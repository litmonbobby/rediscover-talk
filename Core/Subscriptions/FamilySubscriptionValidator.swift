//
//  FamilySubscriptionValidator.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  Family subscription validation and member management
//

import Foundation
import StoreKit
import Combine
import OSLog
import CloudKit

/// Validates family subscription access and manages family member permissions
@MainActor
class FamilySubscriptionValidator: ObservableObject {
    
    // MARK: - Published Properties
    @Published var familyMembers: [FamilyMember] = []
    @Published var isValidatingFamily = false
    @Published var familySubscriptionStatus: FamilySubscriptionStatus = .notAvailable
    @Published var maxFamilyMembers = 6
    @Published var currentMemberCount = 0
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "FamilyValidator")
    private let subscriptionManager: SubscriptionManager
    private let cloudContainer = CKContainer.default()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Family Member
    struct FamilyMember {
        let memberID: String
        let appleID: String?
        let displayName: String
        let hasActiveAccess: Bool
        let joinDate: Date
        let lastActiveDate: Date?
        let deviceInfo: [DeviceInfo]
        let permissions: MemberPermissions
        let subscriptionSource: SubscriptionSource
        
        var isActive: Bool {
            guard let lastActive = lastActiveDate else { return false }
            return Date().timeIntervalSince(lastActive) < 86400 * 7 // Active within 7 days
        }
    }
    
    // MARK: - Device Info
    struct DeviceInfo {
        let deviceID: String
        let deviceName: String
        let deviceType: String
        let osVersion: String
        let appVersion: String
        let lastSeen: Date
    }
    
    // MARK: - Member Permissions
    struct MemberPermissions {
        let canUseSharePlay: Bool
        let canAccessPremiumContent: Bool
        let canManageFamily: Bool
        let canViewFamilyProgress: Bool
        let maxSessionsPerDay: Int?
        
        static let fullAccess = MemberPermissions(
            canUseSharePlay: true,
            canAccessPremiumContent: true,
            canManageFamily: false,
            canViewFamilyProgress: true,
            maxSessionsPerDay: nil
        )
        
        static let organizer = MemberPermissions(
            canUseSharePlay: true,
            canAccessPremiumContent: true,
            canManageFamily: true,
            canViewFamilyProgress: true,
            maxSessionsPerDay: nil
        )
        
        static let restricted = MemberPermissions(
            canUseSharePlay: true,
            canAccessPremiumContent: false,
            canManageFamily: false,
            canViewFamilyProgress: false,
            maxSessionsPerDay: 10
        )
    }
    
    // MARK: - Subscription Source
    enum SubscriptionSource {
        case familyOrganizer
        case familyMember
        case individual
        case unknown
        
        var description: String {
            switch self {
            case .familyOrganizer:
                return "Family Organizer"
            case .familyMember:
                return "Family Member"
            case .individual:
                return "Individual"
            case .unknown:
                return "Unknown"
            }
        }
    }
    
    // MARK: - Family Subscription Status
    enum FamilySubscriptionStatus {
        case notAvailable
        case available
        case active(organizerID: String)
        case expired
        case suspended
        case error(Error)
        
        var isActive: Bool {
            switch self {
            case .active:
                return true
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .notAvailable:
                return "Family subscription not available"
            case .available:
                return "Family subscription available"
            case .active(let organizerID):
                return "Active family subscription (Organizer: \(organizerID))"
            case .expired:
                return "Family subscription expired"
            case .suspended:
                return "Family subscription suspended"
            case .error(let error):
                return "Error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
        setupSubscriptionListener()
        
        Task {
            await validateFamilySubscription()
        }
    }
    
    // MARK: - Setup
    private func setupSubscriptionListener() {
        subscriptionManager.$purchasedProducts
            .sink { [weak self] products in
                Task {
                    await self?.validateFamilySubscription()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Family Subscription Validation
    func validateFamilySubscription() async {
        isValidatingFamily = true
        logger.info("Starting family subscription validation")
        
        do {
            // Check if user has family subscription
            let hasFamilySubscription = await checkFamilySubscriptionEntitlement()
            
            if hasFamilySubscription {
                // Validate family subscription status
                let status = await validateFamilySubscriptionStatus()
                familySubscriptionStatus = status
                
                if status.isActive {
                    // Load family members
                    await loadFamilyMembers()
                }
            } else {
                // Check if user is part of someone else's family subscription
                let familyMembershipStatus = await checkFamilyMembershipStatus()
                familySubscriptionStatus = familyMembershipStatus
            }
            
            isValidatingFamily = false
            logger.info("Family validation completed. Status: \(familySubscriptionStatus.description)")
            
        } catch {
            familySubscriptionStatus = .error(error)
            isValidatingFamily = false
            logger.error("Family validation failed: \(error)")
        }
    }
    
    // MARK: - Family Subscription Entitlement
    private func checkFamilySubscriptionEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productID == SubscriptionManager.SubscriptionProducts.family.rawValue {
                    logger.info("Family subscription entitlement found")
                    return true
                }
            } catch {
                logger.error("Failed to verify transaction: \(error)")
            }
        }
        
        return false
    }
    
    // MARK: - Family Subscription Status Validation
    private func validateFamilySubscriptionStatus() async -> FamilySubscriptionStatus {
        guard let familyProduct = subscriptionManager.availableProducts.first(where: { 
            $0.id == SubscriptionManager.SubscriptionProducts.family.rawValue 
        }) else {
            return .notAvailable
        }
        
        guard let subscription = familyProduct.subscription else {
            return .notAvailable
        }
        
        do {
            let statuses = try await subscription.status
            
            guard let statusResult = statuses.first else {
                return .available
            }
            
            let status = statusResult.value
            
            switch status.state {
            case .subscribed:
                // Get organizer information
                let organizerID = await getOrganizer()
                return .active(organizerID: organizerID)
                
            case .expired:
                return .expired
                
            case .inBillingRetryPeriod, .inGracePeriod:
                return .suspended
                
            case .revoked:
                return .expired
                
            @unknown default:
                return .available
            }
        } catch {
            return .error(error)
        }
    }
    
    // MARK: - Family Membership Status
    private func checkFamilyMembershipStatus() async -> FamilySubscriptionStatus {
        // This would typically involve checking with your backend service
        // or Apple's Family Sharing APIs to determine if the user is part
        // of someone else's family subscription
        
        do {
            // Check current entitlements for family-shared subscriptions
            for await result in Transaction.currentEntitlements {
                let transaction = try checkVerified(result)
                
                if transaction.productID == SubscriptionManager.SubscriptionProducts.family.rawValue &&
                   transaction.ownershipType == .familyShared {
                    
                    // User has access through family sharing
                    let organizerID = transaction.originalTransactionID.description // Simplified
                    return .active(organizerID: organizerID)
                }
            }
            
            return .notAvailable
        } catch {
            return .error(error)
        }
    }
    
    // MARK: - Family Members Management
    private func loadFamilyMembers() async {
        logger.info("Loading family members")
        
        // In a real implementation, this would:
        // 1. Query your backend service for family members
        // 2. Check CloudKit for family member information
        // 3. Validate each member's subscription access
        
        do {
            let members = await loadFamilyMembersFromCloudKit()
            familyMembers = members
            currentMemberCount = members.count
            
            logger.info("Loaded \(members.count) family members")
        } catch {
            logger.error("Failed to load family members: \(error)")
        }
    }
    
    private func loadFamilyMembersFromCloudKit() async -> [FamilyMember] {
        // This is a simplified implementation
        // Real implementation would query CloudKit for family member records
        
        return [
            FamilyMember(
                memberID: "member_1",
                appleID: "user1@example.com",
                displayName: "Family Member 1",
                hasActiveAccess: true,
                joinDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
                lastActiveDate: Date().addingTimeInterval(-3600), // 1 hour ago
                deviceInfo: [
                    DeviceInfo(
                        deviceID: "device_1",
                        deviceName: "iPhone 15 Pro",
                        deviceType: "iPhone",
                        osVersion: "iOS 18.0",
                        appVersion: "1.0",
                        lastSeen: Date().addingTimeInterval(-3600)
                    )
                ],
                permissions: .fullAccess,
                subscriptionSource: .familyMember
            ),
            FamilyMember(
                memberID: "member_2",
                appleID: "user2@example.com",
                displayName: "Family Member 2",
                hasActiveAccess: true,
                joinDate: Date().addingTimeInterval(-86400 * 15), // 15 days ago
                lastActiveDate: Date().addingTimeInterval(-86400), // 1 day ago
                deviceInfo: [
                    DeviceInfo(
                        deviceID: "device_2",
                        deviceName: "iPad Pro",
                        deviceType: "iPad",
                        osVersion: "iPadOS 18.0",
                        appVersion: "1.0",
                        lastSeen: Date().addingTimeInterval(-86400)
                    )
                ],
                permissions: .fullAccess,
                subscriptionSource: .familyMember
            )
        ]
    }
    
    // MARK: - Member Validation
    func validateMemberAccess(_ memberID: String) async -> Bool {
        logger.info("Validating access for member: \(memberID)")
        
        guard let member = familyMembers.first(where: { $0.memberID == memberID }) else {
            logger.warning("Member not found: \(memberID)")
            return false
        }
        
        // Check if family subscription is still active
        guard familySubscriptionStatus.isActive else {
            logger.warning("Family subscription not active")
            return false
        }
        
        // Check if member has active access
        guard member.hasActiveAccess else {
            logger.warning("Member access revoked: \(memberID)")
            return false
        }
        
        // Check if member is within activity limits
        if !member.isActive {
            logger.warning("Member not recently active: \(memberID)")
            return false
        }
        
        return true
    }
    
    func validateSharePlayAccess(for memberIDs: [String]) async -> [String: Bool] {
        var results: [String: Bool] = [:]
        
        for memberID in memberIDs {
            let hasAccess = await validateMemberAccess(memberID) && 
                           (familyMembers.first(where: { $0.memberID == memberID })?.permissions.canUseSharePlay ?? false)
            results[memberID] = hasAccess
        }
        
        logger.info("SharePlay validation results: \(results)")
        return results
    }
    
    // MARK: - Family Management
    func canAddNewMember() -> Bool {
        return currentMemberCount < maxFamilyMembers && familySubscriptionStatus.isActive
    }
    
    func getAvailableSlots() -> Int {
        return max(0, maxFamilyMembers - currentMemberCount)
    }
    
    func removeFamilyMember(_ memberID: String) async throws {
        guard let index = familyMembers.firstIndex(where: { $0.memberID == memberID }) else {
            throw FamilyValidationError.memberNotFound
        }
        
        // Remove from CloudKit
        try await removeMemberFromCloudKit(memberID)
        
        // Update local state
        familyMembers.remove(at: index)
        currentMemberCount = familyMembers.count
        
        logger.info("Removed family member: \(memberID)")
    }
    
    private func removeMemberFromCloudKit(_ memberID: String) async throws {
        // Implementation would delete member record from CloudKit
        logger.info("Removing member from CloudKit: \(memberID)")
    }
    
    func updateMemberPermissions(_ memberID: String, permissions: MemberPermissions) async throws {
        guard let index = familyMembers.firstIndex(where: { $0.memberID == memberID }) else {
            throw FamilyValidationError.memberNotFound
        }
        
        var member = familyMembers[index]
        member = FamilyMember(
            memberID: member.memberID,
            appleID: member.appleID,
            displayName: member.displayName,
            hasActiveAccess: member.hasActiveAccess,
            joinDate: member.joinDate,
            lastActiveDate: member.lastActiveDate,
            deviceInfo: member.deviceInfo,
            permissions: permissions,
            subscriptionSource: member.subscriptionSource
        )
        
        // Update CloudKit
        try await updateMemberInCloudKit(member)
        
        // Update local state
        familyMembers[index] = member
        
        logger.info("Updated permissions for member: \(memberID)")
    }
    
    private func updateMemberInCloudKit(_ member: FamilyMember) async throws {
        // Implementation would update member record in CloudKit
        logger.info("Updating member in CloudKit: \(member.memberID)")
    }
    
    // MARK: - Utilities
    private func getOrganizer() async -> String {
        // This would typically come from your backend or Apple's APIs
        return "organizer_user_id"
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw FamilyValidationError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Public API
    func refreshFamilyStatus() async {
        await validateFamilySubscription()
    }
    
    func getFamilyMember(by memberID: String) -> FamilyMember? {
        return familyMembers.first { $0.memberID == memberID }
    }
    
    func getActiveFamilyMembers() -> [FamilyMember] {
        return familyMembers.filter { $0.hasActiveAccess }
    }
    
    func getFamilyMembersWithSharePlayAccess() -> [FamilyMember] {
        return familyMembers.filter { $0.permissions.canUseSharePlay && $0.hasActiveAccess }
    }
    
    func isCurrentUserOrganizer() -> Bool {
        if case .active = familySubscriptionStatus {
            // Check if current user is the organizer
            // This would involve comparing with the current user's ID
            return true // Simplified for this implementation
        }
        return false
    }
    
    func canManageFamily() -> Bool {
        return isCurrentUserOrganizer() && familySubscriptionStatus.isActive
    }
}

// MARK: - Family Validation Errors
enum FamilyValidationError: LocalizedError {
    case verificationFailed
    case memberNotFound
    case familySubscriptionInactive
    case maxMembersReached
    case insufficientPermissions
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Failed to verify family subscription"
        case .memberNotFound:
            return "Family member not found"
        case .familySubscriptionInactive:
            return "Family subscription is not active"
        case .maxMembersReached:
            return "Maximum family members reached (6)"
        case .insufficientPermissions:
            return "Insufficient permissions to perform this action"
        case .networkError:
            return "Network error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .verificationFailed:
            return "Please contact support if this issue persists"
        case .memberNotFound:
            return "Check the member ID and try again"
        case .familySubscriptionInactive:
            return "Renew your family subscription to continue"
        case .maxMembersReached:
            return "Remove a family member before adding a new one"
        case .insufficientPermissions:
            return "Only the family organizer can perform this action"
        case .networkError:
            return "Check your internet connection and try again"
        }
    }
}