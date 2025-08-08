//
//  FeatureAccessManager.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  Feature access control and premium content gating
//

import Foundation
import StoreKit
import Combine
import OSLog

/// Manages feature access based on subscription status
@MainActor
class FeatureAccessManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isPremiumUser = false
    @Published var hasFamilyAccess = false
    @Published var hasSharePlayAccess = false
    @Published var canAccessOfflineContent = false
    @Published var hasUnlimitedSessions = false
    @Published var hasPrioritySupport = false
    
    // MARK: - Private Properties
    private let subscriptionManager: SubscriptionManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "FeatureAccess")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Feature Limits
    struct FreeTierLimits {
        static let maxSessionsPerDay = 3
        static let maxSessionDuration = 300 // 5 minutes in seconds
        static let availableBreathingPatterns = 2
        static let maxFamilyMembers = 0 // No family features for free tier
    }
    
    struct PremiumFeatures {
        static let unlimitedSessions = true
        static let unlimitedDuration = true
        static let allBreathingPatterns = true
        static let offlineAccess = true
        static let progressTracking = true
        static let premiumContent = true
    }
    
    struct FamilyFeatures {
        static let sharePlaySessions = true
        static let familyDashboard = true
        static let maxFamilyMembers = 6
        static let familyProgressTracking = true
        static let prioritySupport = true
    }
    
    // MARK: - Initialization
    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
        setupSubscriptions()
        updateFeatureAccess()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Listen to subscription changes
        subscriptionManager.$purchasedProducts
            .sink { [weak self] _ in
                self?.updateFeatureAccess()
            }
            .store(in: &cancellables)
        
        subscriptionManager.$subscriptionStatus
            .sink { [weak self] _ in
                self?.updateFeatureAccess()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Feature Access Updates
    private func updateFeatureAccess() {
        let hasIndividual = subscriptionManager.hasIndividualSubscription()
        let hasFamily = subscriptionManager.hasFamilySubscription()
        let hasAnySubscription = hasIndividual || hasFamily
        
        isPremiumUser = hasAnySubscription
        hasFamilyAccess = hasFamily
        hasSharePlayAccess = hasFamily
        canAccessOfflineContent = hasAnySubscription
        hasUnlimitedSessions = hasAnySubscription
        hasPrioritySupport = hasFamily
        
        logger.info("Updated feature access - Premium: \(isPremiumUser), Family: \(hasFamilyAccess)")
    }
    
    // MARK: - Session Access Control
    func canStartNewSession() -> Bool {
        if isPremiumUser {
            return true
        }
        
        // Check daily session limit for free users
        let todaysSessions = getTodaysSessionCount()
        return todaysSessions < FreeTierLimits.maxSessionsPerDay
    }
    
    func getMaxSessionDuration() -> TimeInterval {
        if isPremiumUser {
            return .infinity // Unlimited for premium users
        }
        return TimeInterval(FreeTierLimits.maxSessionDuration)
    }
    
    func canAccessBreathingPattern(_ patternID: String) -> Bool {
        if isPremiumUser {
            return true
        }
        
        // Free users can access only basic patterns
        let freePatterns = ["basic_4_4_4_4", "calm_4_7_8"]
        return freePatterns.contains(patternID)
    }
    
    func getRemainingFreeSessions() -> Int {
        if isPremiumUser {
            return Int.max
        }
        
        let used = getTodaysSessionCount()
        return max(0, FreeTierLimits.maxSessionsPerDay - used)
    }
    
    // MARK: - Family Features
    func canAccessSharePlay() -> Bool {
        return hasSharePlayAccess
    }
    
    func canCreateFamilySession() -> Bool {
        return hasFamilyAccess
    }
    
    func canInviteFamilyMembers() -> Bool {
        return hasFamilyAccess
    }
    
    func getMaxFamilyMembers() -> Int {
        if hasFamilyAccess {
            return FamilyFeatures.maxFamilyMembers
        }
        return FreeTierLimits.maxFamilyMembers
    }
    
    func canAccessFamilyDashboard() -> Bool {
        return hasFamilyAccess
    }
    
    // MARK: - Content Access
    func canAccessPremiumContent() -> Bool {
        return isPremiumUser
    }
    
    func canDownloadForOffline() -> Bool {
        return canAccessOfflineContent
    }
    
    func canAccessAdvancedAnalytics() -> Bool {
        return isPremiumUser
    }
    
    func canExportProgress() -> Bool {
        return isPremiumUser
    }
    
    // MARK: - Support Features
    func getSupportLevel() -> SupportLevel {
        if hasPrioritySupport {
            return .priority
        } else if isPremiumUser {
            return .premium
        } else {
            return .basic
        }
    }
    
    enum SupportLevel {
        case basic
        case premium
        case priority
        
        var responseTime: String {
            switch self {
            case .basic:
                return "48-72 hours"
            case .premium:
                return "12-24 hours"
            case .priority:
                return "2-4 hours"
            }
        }
        
        var channels: [String] {
            switch self {
            case .basic:
                return ["FAQ", "Community Forum"]
            case .premium:
                return ["FAQ", "Community Forum", "Email Support"]
            case .priority:
                return ["FAQ", "Community Forum", "Email Support", "Priority Chat"]
            }
        }
    }
    
    // MARK: - Upgrade Prompts
    func shouldShowUpgradePrompt(for feature: PremiumFeature) -> Bool {
        if isPremiumUser {
            return false
        }
        
        switch feature {
        case .unlimitedSessions:
            return getRemainingFreeSessions() <= 1
        case .sharePlay:
            return !hasSharePlayAccess
        case .offlineContent:
            return !canAccessOfflineContent
        case .premiumBreathingPatterns:
            return true
        case .familyFeatures:
            return !hasFamilyAccess
        case .advancedAnalytics:
            return !canAccessAdvancedAnalytics()
        case .prioritySupport:
            return !hasPrioritySupport
        }
    }
    
    enum PremiumFeature {
        case unlimitedSessions
        case sharePlay
        case offlineContent
        case premiumBreathingPatterns
        case familyFeatures
        case advancedAnalytics
        case prioritySupport
        
        var title: String {
            switch self {
            case .unlimitedSessions:
                return "Unlimited Sessions"
            case .sharePlay:
                return "SharePlay Sessions"
            case .offlineContent:
                return "Offline Content"
            case .premiumBreathingPatterns:
                return "Premium Breathing Patterns"
            case .familyFeatures:
                return "Family Features"
            case .advancedAnalytics:
                return "Advanced Analytics"
            case .prioritySupport:
                return "Priority Support"
            }
        }
        
        var description: String {
            switch self {
            case .unlimitedSessions:
                return "Practice breathing exercises without daily limits"
            case .sharePlay:
                return "Share breathing sessions with family members"
            case .offlineContent:
                return "Download sessions for offline practice"
            case .premiumBreathingPatterns:
                return "Access all breathing techniques and patterns"
            case .familyFeatures:
                return "Family dashboard and progress tracking"
            case .advancedAnalytics:
                return "Detailed progress analytics and insights"
            case .prioritySupport:
                return "Get priority customer support"
            }
        }
        
        var requiredSubscription: SubscriptionManager.SubscriptionProducts {
            switch self {
            case .unlimitedSessions, .offlineContent, .premiumBreathingPatterns, .advancedAnalytics:
                return .individual
            case .sharePlay, .familyFeatures, .prioritySupport:
                return .family
            }
        }
    }
    
    // MARK: - Usage Tracking
    private func getTodaysSessionCount() -> Int {
        // This would typically be stored in UserDefaults or Core Data
        // For now, returning a mock value
        let key = "sessions_\(dateString(from: Date()))"
        return UserDefaults.standard.integer(forKey: key)
    }
    
    func recordSessionStart() {
        let key = "sessions_\(dateString(from: Date()))"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
        logger.info("Recorded session start. Today's count: \(current + 1)")
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // MARK: - Feature Validation
    func validateFeatureAccess(for feature: PremiumFeature) throws {
        switch feature {
        case .unlimitedSessions:
            if !canStartNewSession() {
                throw FeatureAccessError.dailyLimitReached
            }
        case .sharePlay:
            if !canAccessSharePlay() {
                throw FeatureAccessError.requiresFamilySubscription
            }
        case .offlineContent:
            if !canDownloadForOffline() {
                throw FeatureAccessError.requiresPremiumSubscription
            }
        case .premiumBreathingPatterns:
            if !isPremiumUser {
                throw FeatureAccessError.requiresPremiumSubscription
            }
        case .familyFeatures:
            if !hasFamilyAccess {
                throw FeatureAccessError.requiresFamilySubscription
            }
        case .advancedAnalytics:
            if !canAccessAdvancedAnalytics() {
                throw FeatureAccessError.requiresPremiumSubscription
            }
        case .prioritySupport:
            if !hasPrioritySupport {
                throw FeatureAccessError.requiresFamilySubscription
            }
        }
    }
}

// MARK: - Feature Access Errors
enum FeatureAccessError: LocalizedError {
    case dailyLimitReached
    case requiresPremiumSubscription
    case requiresFamilySubscription
    case networkRequired
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            return "Daily session limit reached. Upgrade to premium for unlimited access."
        case .requiresPremiumSubscription:
            return "This feature requires a premium subscription."
        case .requiresFamilySubscription:
            return "This feature requires a family subscription."
        case .networkRequired:
            return "Network connection required for this feature."
        case .unknown:
            return "Unable to access this feature at this time."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .dailyLimitReached, .requiresPremiumSubscription:
            return "Upgrade to Individual or Family plan to unlock this feature."
        case .requiresFamilySubscription:
            return "Upgrade to Family plan to access SharePlay and family features."
        case .networkRequired:
            return "Please check your internet connection and try again."
        case .unknown:
            return "Try again later or contact support if the problem persists."
        }
    }
}