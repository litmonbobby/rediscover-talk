//
//  SubscriptionStatusMonitor.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  Real-time subscription status monitoring and lifecycle management
//

import Foundation
import StoreKit
import Combine
import OSLog
import UserNotifications

/// Monitors subscription status changes and handles lifecycle events
@MainActor
class SubscriptionStatusMonitor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var subscriptionStatuses: [String: SubscriptionStatus] = [:]
    @Published var isMonitoring = false
    @Published var lastUpdateTime: Date?
    @Published var alertsEnabled = true
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "SubscriptionMonitor")
    private let subscriptionManager: SubscriptionManager
    private var statusUpdateTask: Task<Void, Error>?
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Subscription Status
    struct SubscriptionStatus {
        let productID: String
        let state: Product.SubscriptionInfo.Status.State
        let expirationDate: Date?
        let renewalDate: Date?
        let willAutoRenew: Bool
        let isInGracePeriod: Bool
        let isInBillingRetryPeriod: Bool
        let renewalPrice: Decimal?
        let renewalCurrency: String?
        let lastUpdateDate: Date
        
        var isActive: Bool {
            switch state {
            case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                return true
            case .expired, .revoked:
                return false
            @unknown default:
                return false
            }
        }
        
        var needsAttention: Bool {
            return isInBillingRetryPeriod || (expirationDate ?? Date.distantFuture) < Date().addingTimeInterval(86400 * 7) // 7 days
        }
        
        var statusDescription: String {
            switch state {
            case .subscribed:
                return willAutoRenew ? "Active - Will Renew" : "Active - Will Expire"
            case .expired:
                return "Expired"
            case .inBillingRetryPeriod:
                return "Payment Issue - Retrying"
            case .inGracePeriod:
                return "Grace Period"
            case .revoked:
                return "Revoked"
            @unknown default:
                return "Unknown"
            }
        }
    }
    
    // MARK: - Status Change Events
    enum StatusChangeEvent {
        case subscriptionActivated(productID: String)
        case subscriptionExpired(productID: String)
        case subscriptionRenewed(productID: String)
        case paymentIssue(productID: String)
        case gracePeriodStarted(productID: String)
        case subscriptionCancelled(productID: String)
        case subscriptionRevoked(productID: String)
        
        var title: String {
            switch self {
            case .subscriptionActivated:
                return "Subscription Activated"
            case .subscriptionExpired:
                return "Subscription Expired"
            case .subscriptionRenewed:
                return "Subscription Renewed"
            case .paymentIssue:
                return "Payment Issue"
            case .gracePeriodStarted:
                return "Grace Period Started"
            case .subscriptionCancelled:
                return "Subscription Cancelled"
            case .subscriptionRevoked:
                return "Subscription Revoked"
            }
        }
        
        var message: String {
            switch self {
            case .subscriptionActivated(let productID):
                return "Your \(productID) subscription is now active"
            case .subscriptionExpired(let productID):
                return "Your \(productID) subscription has expired"
            case .subscriptionRenewed(let productID):
                return "Your \(productID) subscription has been renewed"
            case .paymentIssue(let productID):
                return "Payment issue with your \(productID) subscription"
            case .gracePeriodStarted(let productID):
                return "Grace period started for your \(productID) subscription"
            case .subscriptionCancelled(let productID):
                return "Your \(productID) subscription has been cancelled"
            case .subscriptionRevoked(let productID):
                return "Your \(productID) subscription has been revoked"
            }
        }
        
        var isUrgent: Bool {
            switch self {
            case .paymentIssue, .subscriptionExpired, .subscriptionRevoked:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Initialization
    init(subscriptionManager: SubscriptionManager) {
        self.subscriptionManager = subscriptionManager
        setupMonitoring()
        requestNotificationPermissions()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        logger.info("Starting subscription status monitoring")
        
        statusUpdateTask = Task {
            await monitorStatusUpdates()
        }
        
        // Initial status check
        Task {
            await updateAllSubscriptionStatuses()
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        statusUpdateTask?.cancel()
        statusUpdateTask = nil
        
        logger.info("Stopped subscription status monitoring")
    }
    
    // MARK: - Status Monitoring
    private func monitorStatusUpdates() async {
        await withTaskGroup(of: Void.self) { group in
            // Monitor each product's subscription status
            for product in subscriptionManager.availableProducts {
                if product.type == .autoRenewable {
                    group.addTask {
                        await self.monitorProductStatus(product)
                    }
                }
            }
        }
    }
    
    private func monitorProductStatus(_ product: Product) async {
        guard let subscription = product.subscription else { return }
        
        logger.info("Monitoring status for product: \(product.displayName)")
        
        do {
            for await statusResult in subscription.status {
                let status = statusResult.value
                let newStatus = SubscriptionStatus(
                    productID: product.id,
                    state: status.state,
                    expirationDate: status.expirationDate,
                    renewalDate: status.renewalDate,
                    willAutoRenew: status.willAutoRenew,
                    isInGracePeriod: status.state == .inGracePeriod,
                    isInBillingRetryPeriod: status.state == .inBillingRetryPeriod,
                    renewalPrice: status.renewalInfo?.price,
                    renewalCurrency: status.renewalInfo?.currencyCode,
                    lastUpdateDate: Date()
                )
                
                await handleStatusChange(oldStatus: subscriptionStatuses[product.id], newStatus: newStatus)
                subscriptionStatuses[product.id] = newStatus
                lastUpdateTime = Date()
                
                logger.info("Status updated for \(product.displayName): \(status.state)")
            }
        } catch {
            logger.error("Failed to monitor status for \(product.displayName): \(error)")
        }
    }
    
    private func updateAllSubscriptionStatuses() async {
        logger.info("Updating all subscription statuses")
        
        for product in subscriptionManager.availableProducts {
            guard product.type == .autoRenewable,
                  let subscription = product.subscription else { continue }
            
            do {
                let statuses = try await subscription.status
                if let statusResult = statuses.first {
                    let status = statusResult.value
                    let subscriptionStatus = SubscriptionStatus(
                        productID: product.id,
                        state: status.state,
                        expirationDate: status.expirationDate,
                        renewalDate: status.renewalDate,
                        willAutoRenew: status.willAutoRenew,
                        isInGracePeriod: status.state == .inGracePeriod,
                        isInBillingRetryPeriod: status.state == .inBillingRetryPeriod,
                        renewalPrice: status.renewalInfo?.price,
                        renewalCurrency: status.renewalInfo?.currencyCode,
                        lastUpdateDate: Date()
                    )
                    
                    subscriptionStatuses[product.id] = subscriptionStatus
                }
            } catch {
                logger.error("Failed to get status for \(product.displayName): \(error)")
            }
        }
        
        lastUpdateTime = Date()
        logger.info("Updated statuses for \(subscriptionStatuses.count) products")
    }
    
    // MARK: - Status Change Handling
    private func handleStatusChange(oldStatus: SubscriptionStatus?, newStatus: SubscriptionStatus) async {
        // Determine what changed
        let events = detectStatusChangeEvents(oldStatus: oldStatus, newStatus: newStatus)
        
        for event in events {
            logger.info("Subscription event: \(event.title) for \(newStatus.productID)")
            
            // Send notification if enabled
            if alertsEnabled {
                await sendNotification(for: event)
            }
            
            // Handle specific business logic
            await handleStatusEvent(event)
        }
    }
    
    private func detectStatusChangeEvents(oldStatus: SubscriptionStatus?, newStatus: SubscriptionStatus) -> [StatusChangeEvent] {
        var events: [StatusChangeEvent] = []
        
        // New subscription
        if oldStatus == nil {
            if newStatus.isActive {
                events.append(.subscriptionActivated(productID: newStatus.productID))
            }
            return events
        }
        
        guard let oldStatus = oldStatus else { return events }
        
        // State changes
        if oldStatus.state != newStatus.state {
            switch (oldStatus.state, newStatus.state) {
            case (_, .subscribed):
                if oldStatus.state == .expired || oldStatus.state == .inBillingRetryPeriod {
                    events.append(.subscriptionRenewed(productID: newStatus.productID))
                } else {
                    events.append(.subscriptionActivated(productID: newStatus.productID))
                }
                
            case (_, .expired):
                events.append(.subscriptionExpired(productID: newStatus.productID))
                
            case (_, .inBillingRetryPeriod):
                events.append(.paymentIssue(productID: newStatus.productID))
                
            case (_, .inGracePeriod):
                events.append(.gracePeriodStarted(productID: newStatus.productID))
                
            case (_, .revoked):
                events.append(.subscriptionRevoked(productID: newStatus.productID))
                
            default:
                break
            }
        }
        
        // Auto-renewal changes
        if oldStatus.willAutoRenew && !newStatus.willAutoRenew {
            events.append(.subscriptionCancelled(productID: newStatus.productID))
        }
        
        return events
    }
    
    private func handleStatusEvent(_ event: StatusChangeEvent) async {
        switch event {
        case .subscriptionExpired(let productID):
            await handleSubscriptionExpired(productID: productID)
            
        case .paymentIssue(let productID):
            await handlePaymentIssue(productID: productID)
            
        case .subscriptionRenewed(let productID):
            await handleSubscriptionRenewed(productID: productID)
            
        case .subscriptionCancelled(let productID):
            await handleSubscriptionCancelled(productID: productID)
            
        default:
            // Log other events but no specific action needed
            logger.info("Handled subscription event: \(event.title)")
        }
    }
    
    // MARK: - Event Handlers
    private func handleSubscriptionExpired(productID: String) async {
        logger.warning("Subscription expired: \(productID)")
        
        // Update feature access
        await subscriptionManager.updatePurchasedProducts()
        
        // Log analytics event
        logAnalyticsEvent("subscription_expired", parameters: ["product_id": productID])
    }
    
    private func handlePaymentIssue(productID: String) async {
        logger.warning("Payment issue detected: \(productID)")
        
        // Schedule retry notifications
        await schedulePaymentRetryNotifications(productID: productID)
        
        // Log analytics event
        logAnalyticsEvent("payment_issue", parameters: ["product_id": productID])
    }
    
    private func handleSubscriptionRenewed(productID: String) async {
        logger.info("Subscription renewed: \(productID)")
        
        // Update feature access
        await subscriptionManager.updatePurchasedProducts()
        
        // Log analytics event
        logAnalyticsEvent("subscription_renewed", parameters: ["product_id": productID])
    }
    
    private func handleSubscriptionCancelled(productID: String) async {
        logger.info("Subscription cancelled: \(productID)")
        
        // Schedule end-of-period notifications
        if let status = subscriptionStatuses[productID],
           let expirationDate = status.expirationDate {
            await scheduleExpirationReminder(productID: productID, expirationDate: expirationDate)
        }
        
        // Log analytics event
        logAnalyticsEvent("subscription_cancelled", parameters: ["product_id": productID])
    }
    
    // MARK: - Notifications
    private func requestNotificationPermissions() {
        Task {
            do {
                let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
                logger.info("Notification permission granted: \(granted)")
            } catch {
                logger.error("Failed to request notification permissions: \(error)")
            }
        }
    }
    
    private func sendNotification(for event: StatusChangeEvent) async {
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.message
        content.sound = event.isUrgent ? .critical : .default
        
        if event.isUrgent {
            content.badge = 1
        }
        
        let request = UNNotificationRequest(
            identifier: "subscription_\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate delivery
        )
        
        do {
            try await notificationCenter.add(request)
            logger.info("Notification sent for event: \(event.title)")
        } catch {
            logger.error("Failed to send notification: \(error)")
        }
    }
    
    private func schedulePaymentRetryNotifications(productID: String) async {
        let retryDays = [1, 3, 7] // Retry reminders after 1, 3, and 7 days
        
        for day in retryDays {
            let content = UNMutableNotificationContent()
            content.title = "Payment Retry Reminder"
            content.body = "Please update your payment method to continue your subscription"
            content.sound = .default
            content.badge = 1
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(day * 86400),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "payment_retry_\(productID)_day_\(day)",
                content: content,
                trigger: trigger
            )
            
            do {
                try await notificationCenter.add(request)
            } catch {
                logger.error("Failed to schedule payment retry notification: \(error)")
            }
        }
    }
    
    private func scheduleExpirationReminder(productID: String, expirationDate: Date) async {
        let reminderDays = [7, 3, 1] // Remind 7, 3, and 1 days before expiration
        
        for days in reminderDays {
            let reminderDate = expirationDate.addingTimeInterval(-TimeInterval(days * 86400))
            
            guard reminderDate > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Subscription Expiring Soon"
            content.body = "Your subscription will expire in \(days) day\(days > 1 ? "s" : "")"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: reminderDate.timeIntervalSinceNow,
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "expiration_reminder_\(productID)_\(days)d",
                content: content,
                trigger: trigger
            )
            
            do {
                try await notificationCenter.add(request)
            } catch {
                logger.error("Failed to schedule expiration reminder: \(error)")
            }
        }
    }
    
    // MARK: - Analytics
    private func logAnalyticsEvent(_ event: String, parameters: [String: Any]) {
        // This would integrate with your analytics service
        logger.info("Analytics event: \(event) with parameters: \(parameters)")
    }
    
    // MARK: - Status Queries
    func getStatus(for productID: String) -> SubscriptionStatus? {
        return subscriptionStatuses[productID]
    }
    
    func getAllActiveStatuses() -> [SubscriptionStatus] {
        return subscriptionStatuses.values.filter { $0.isActive }
    }
    
    func getStatusesNeedingAttention() -> [SubscriptionStatus] {
        return subscriptionStatuses.values.filter { $0.needsAttention }
    }
    
    func isSubscriptionActive(productID: String) -> Bool {
        return subscriptionStatuses[productID]?.isActive ?? false
    }
    
    func getExpirationDate(for productID: String) -> Date? {
        return subscriptionStatuses[productID]?.expirationDate
    }
    
    func willAutoRenew(productID: String) -> Bool {
        return subscriptionStatuses[productID]?.willAutoRenew ?? false
    }
    
    // MARK: - Manual Actions
    func refreshAllStatuses() async {
        logger.info("Manual refresh of all subscription statuses")
        await updateAllSubscriptionStatuses()
    }
    
    func toggleAlerts() {
        alertsEnabled.toggle()
        logger.info("Subscription alerts \(alertsEnabled ? "enabled" : "disabled")")
    }
    
    func clearNotifications() async {
        await notificationCenter.removeAllPendingNotificationRequests()
        logger.info("Cleared all pending subscription notifications")
    }
}