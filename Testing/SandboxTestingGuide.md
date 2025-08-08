# StoreKit 2 Sandbox Testing Guide - Rediscover Talk

## Overview

This guide provides comprehensive instructions for testing the Rediscover Talk subscription system using Apple's StoreKit 2 sandbox environment.

## Prerequisites

### Apple Developer Account Setup
1. **Sandbox Tester Accounts**: Create multiple Apple IDs for testing
2. **App Store Connect**: Configure subscription products
3. **Xcode Configuration**: Set up StoreKit configuration file

### Required Test Apple IDs

Create the following sandbox tester accounts in App Store Connect:

```
Primary Tester (Individual Plan):
- Email: individual.tester@example.com
- Region: United States
- Purpose: Individual subscription testing

Family Organizer:
- Email: family.organizer@example.com  
- Region: United States
- Purpose: Family subscription organizer

Family Member 1:
- Email: family.member1@example.com
- Region: United States
- Purpose: Family sharing member

Family Member 2:
- Email: family.member2@example.com
- Region: United States
- Purpose: Family sharing member

International Tester:
- Email: intl.tester@example.com
- Region: Canada
- Purpose: International pricing/localization

Edge Case Tester:
- Email: edge.tester@example.com
- Region: United States
- Purpose: Payment failures, cancellations
```

## Sandbox Configuration

### 1. App Store Connect Subscription Setup

#### Individual Plan Configuration
```
Product ID: rediscover_talk_individual_monthly
Display Name: Individual Plan
Duration: 1 Month (Auto-Renewable)
Price Tier: $6.99 USD
Family Shareable: No

Introductory Offer:
- Type: Free Trial
- Duration: 7 days
- Eligible: New Subscribers Only

Promotional Offers:
- Win-back: 50% off for 3 months (lapsed subscribers)
- Upgrade: Free 1 month when upgrading from Individual to Family
```

#### Family Plan Configuration
```
Product ID: rediscover_talk_family_monthly
Display Name: Family Plan
Duration: 1 Month (Auto-Renewable)
Price Tier: $19.99 USD
Family Shareable: Yes (Up to 6 members)

Introductory Offer:
- Type: Free Trial
- Duration: 7 days
- Eligible: New Subscribers Only

Promotional Offers:
- New Customer: 1 month free for first-time family subscribers
- Loyalty: 10% off for subscribers > 12 months
```

#### Subscription Group Configuration
```
Group Name: Rediscover Talk Subscriptions
Group ID: rediscover_talk_subscriptions

Upgrade/Downgrade Matrix:
- Individual → Family: Upgrade (immediate)
- Family → Individual: Downgrade (at next renewal)
```

### 2. StoreKit Configuration File

The `StoreKitConfiguration.storekit` file is already configured with:
- Accelerated subscription renewals (5 minutes = 1 month)
- Billing retry settings
- Grace period configuration
- Failure simulation options

### 3. Xcode Scheme Configuration

1. Open scheme editor for Rediscover Talk target
2. Run tab → Options
3. StoreKit Configuration: Select "StoreKitConfiguration.storekit"
4. Enable "Debug StoreKit" for detailed logging

## Testing Scenarios

### Scenario 1: Individual Subscription Lifecycle

**Objective**: Test complete individual subscription flow

**Steps**:
1. Sign out of all Apple IDs on test device
2. Sign in with `individual.tester@example.com`
3. Launch app and navigate to subscription view
4. Verify products load correctly
5. Purchase Individual Plan with 7-day free trial
6. Verify subscription activates immediately
7. Test premium feature access
8. Wait for accelerated renewal (5 minutes)
9. Verify subscription renews automatically
10. Cancel subscription in Settings
11. Verify access continues until expiration
12. Test subscription restoration after reinstall

**Expected Results**:
- ✅ Products load successfully
- ✅ Free trial activates immediately
- ✅ Premium features unlock
- ✅ Auto-renewal works correctly
- ✅ Cancellation handled properly
- ✅ Restoration works across devices

### Scenario 2: Family Subscription Setup

**Objective**: Test family subscription organizer flow

**Steps**:
1. Sign in with `family.organizer@example.com`
2. Purchase Family Plan subscription
3. Verify family sharing is enabled
4. Test SharePlay feature access
5. Verify family dashboard functionality
6. Check subscription status in Family Management
7. Test adding family members (simulated)
8. Verify organizer permissions

**Expected Results**:
- ✅ Family subscription activates
- ✅ SharePlay features unlock
- ✅ Family dashboard accessible
- ✅ Organizer permissions work
- ✅ Family member slots available

### Scenario 3: Family Member Access

**Objective**: Test family member subscription access

**Steps**:
1. Set up Family Sharing in iOS Settings
2. Add `family.member1@example.com` to family
3. Sign in with family member account
4. Launch app and verify automatic access
5. Test premium feature availability
6. Test SharePlay session joining
7. Verify cannot manage subscription
8. Test access after organizer cancellation

**Expected Results**:
- ✅ Automatic subscription access
- ✅ Premium features available
- ✅ SharePlay sessions work
- ✅ Limited management permissions
- ✅ Access revoked when organizer cancels

### Scenario 4: Subscription Restoration

**Objective**: Test purchase restoration across devices

**Test Matrix**:
```
Device A → Device B:
- iPhone → iPad: Individual subscription
- iPhone → iPad: Family subscription
- iPad → iPhone: After account change
- iPhone → iPhone: After app reinstall
```

**Steps**:
1. Purchase subscription on Device A
2. Sign in with same Apple ID on Device B
3. Launch app on Device B
4. Tap "Restore Purchases"
5. Verify subscription activates
6. Test feature access on both devices
7. Make changes on Device A, verify sync to Device B

**Expected Results**:
- ✅ Purchases restore successfully
- ✅ Features unlock on both devices
- ✅ Changes sync between devices
- ✅ No duplicate charges occur

### Scenario 5: Payment Failure Handling

**Objective**: Test billing retry and grace periods

**Setup**: Configure sandbox to simulate payment failures

**Steps**:
1. Purchase subscription with valid payment
2. Simulate payment failure (StoreKit configuration)
3. Verify app enters billing retry period
4. Check notification delivery
5. Simulate payment recovery
6. Test grace period behavior
7. Verify subscription reactivation

**Expected Results**:
- ✅ Billing retry period activates
- ✅ User notifications sent
- ✅ Grace period preserves access
- ✅ Recovery reactivates subscription
- ✅ Failed payment revokes access

### Scenario 6: Subscription Upgrades/Downgrades

**Objective**: Test plan changes between Individual and Family

**Individual → Family Upgrade**:
1. Start with Individual subscription
2. Tap upgrade to Family plan
3. Verify immediate upgrade
4. Check prorated billing
5. Verify family features activate

**Family → Individual Downgrade**:
1. Start with Family subscription
2. Downgrade to Individual plan
3. Verify change scheduled for next renewal
4. Check family features remain until downgrade
5. Verify downgrade activates at renewal

**Expected Results**:
- ✅ Upgrades apply immediately
- ✅ Downgrades scheduled appropriately
- ✅ Prorated billing calculated correctly
- ✅ Feature access updates properly

### Scenario 7: International Testing

**Objective**: Test international pricing and localization

**Steps**:
1. Sign in with `intl.tester@example.com` (Canada)
2. Verify prices display in CAD
3. Test subscription purchase
4. Verify currency conversion
5. Check localized strings
6. Test tax calculation

**Expected Results**:
- ✅ Prices shown in local currency
- ✅ Purchase flow works internationally
- ✅ Taxes calculated correctly
- ✅ Localization displays properly

## Testing Tools & Utilities

### 1. StoreKit Test Environment
```swift
// Enable detailed StoreKit logging
#if DEBUG
import StoreKit

func enableStoreKitLogging() {
    // Enable transaction logging
    SKPaymentQueue.default().add(TransactionObserver())
    
    // Log product requests
    print("StoreKit testing enabled")
}
#endif
```

### 2. Subscription Status Monitoring
```swift
// Monitor subscription changes during testing
Task {
    for await update in Transaction.updates {
        print("Transaction update: \(update)")
    }
}
```

### 3. Test Data Reset
```swift
// Clear test data between scenarios
func resetTestData() {
    // Clear UserDefaults
    UserDefaults.standard.removeObject(forKey: "lastMigrationVersion")
    
    // Reset feature flags
    UserDefaults.standard.removeObject(forKey: "premiumFeaturesUnlocked")
    
    // Clear analytics
    // Analytics.reset()
}
```

## Automation Scripts

### Purchase Flow Automation
```swift
// Automated purchase testing
func automatePurchaseTest() async {
    let subscriptionManager = SubscriptionManager()
    await subscriptionManager.loadProducts()
    
    guard let individualProduct = subscriptionManager.availableProducts.first(where: {
        $0.id == "rediscover_talk_individual_monthly"
    }) else {
        XCTFail("Individual product not found")
        return
    }
    
    let success = await subscriptionManager.purchase(individualProduct)
    XCTAssertTrue(success, "Purchase should succeed")
    
    // Verify activation
    XCTAssertTrue(subscriptionManager.hasActiveSubscription())
}
```

### Family Validation Testing
```swift
// Automated family validation
func testFamilyValidation() async {
    let familyValidator = FamilySubscriptionValidator(
        subscriptionManager: SubscriptionManager()
    )
    
    await familyValidator.validateFamilySubscription()
    
    // Test organizer status
    XCTAssertTrue(familyValidator.isCurrentUserOrganizer())
    
    // Test member limits
    XCTAssertEqual(familyValidator.maxFamilyMembers, 6)
}
```

## Issue Resolution

### Common Issues and Solutions

#### Products Not Loading
**Symptoms**: Empty product list, loading errors
**Solutions**:
1. Verify StoreKit configuration file is selected
2. Check product IDs match App Store Connect
3. Ensure sandbox account is signed in
4. Clear Xcode derived data and rebuild

#### Purchase Failures
**Symptoms**: Purchase returns failure or pending
**Solutions**:
1. Verify sandbox tester account status
2. Check payment method validity
3. Ensure region compatibility
4. Reset sandbox account if needed

#### Family Sharing Not Working
**Symptoms**: Family members can't access subscription
**Solutions**:
1. Verify Family Sharing enabled in Settings
2. Check subscription is marked as family shareable
3. Confirm family members are added to organizer's family
4. Test with fresh sandbox accounts

#### Restoration Issues
**Symptoms**: Restore purchases doesn't work
**Solutions**:
1. Ensure same Apple ID used for original purchase
2. Verify App Store connection
3. Check transaction verification logic
4. Test with clean app install

### Debug Information Collection
```swift
// Comprehensive debug info
func collectDebugInfo() {
    print("=== StoreKit Debug Info ===")
    print("Available Products: \(subscriptionManager.availableProducts.count)")
    print("Purchased Products: \(subscriptionManager.purchasedProducts.count)")
    print("Family Status: \(familyValidator.familySubscriptionStatus)")
    print("Current User: \(getCurrentAppleID())")
    print("App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown")")
    print("Device: \(UIDevice.current.model)")
    print("iOS Version: \(UIDevice.current.systemVersion)")
    print("==========================")
}
```

## Testing Checklist

### Pre-Testing Setup
- [ ] Sandbox tester accounts created
- [ ] App Store Connect products configured
- [ ] StoreKit configuration file updated
- [ ] Xcode scheme configured for sandbox
- [ ] Test devices prepared

### Core Functionality
- [ ] Product loading
- [ ] Individual subscription purchase
- [ ] Family subscription purchase
- [ ] Free trial activation
- [ ] Premium feature access
- [ ] Subscription restoration
- [ ] Auto-renewal
- [ ] Cancellation handling

### Family Features
- [ ] Family subscription setup
- [ ] Member invitation (simulated)
- [ ] SharePlay access validation
- [ ] Family dashboard functionality
- [ ] Organizer permissions
- [ ] Member access control

### Edge Cases
- [ ] Payment failures
- [ ] Billing retry
- [ ] Grace periods
- [ ] Subscription upgrades
- [ ] Subscription downgrades
- [ ] Account changes
- [ ] App reinstalls

### International
- [ ] Multi-region pricing
- [ ] Currency conversion
- [ ] Localization
- [ ] Tax calculation

### Performance
- [ ] Product loading speed
- [ ] Purchase completion time
- [ ] Restoration performance
- [ ] Background sync
- [ ] Memory usage
- [ ] Battery impact

## Reporting

### Test Results Documentation
```markdown
## Test Session Report

**Date**: [Date]
**Tester**: [Name]
**App Version**: [Version]
**iOS Version**: [Version]

### Results Summary
- ✅ Individual Subscriptions: 8/8 passed
- ✅ Family Subscriptions: 6/6 passed  
- ⚠️  Payment Failures: 2/3 passed (1 timeout)
- ✅ Restoration: 5/5 passed
- ✅ Upgrades/Downgrades: 4/4 passed

### Issues Found
1. **Payment timeout**: Occasional 30s timeout in sandbox
   - Impact: Low (sandbox only)
   - Workaround: Retry purchase
   - Status: Monitoring

### Recommendations
1. Add retry logic for network timeouts
2. Improve error messaging for payment failures
3. Consider reducing grace period duration
```

This comprehensive testing guide ensures thorough validation of the StoreKit 2 subscription system across all scenarios and edge cases.