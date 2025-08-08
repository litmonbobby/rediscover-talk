//
//  SubscriptionView.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  SwiftUI subscription management interface
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var subscriptionManager = SubscriptionManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingManageSubscriptions = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if subscriptionManager.hasActiveSubscription() {
                            activeSubscriptionSection
                        } else {
                            subscriptionPlansSection
                        }
                        
                        featuresComparisonSection
                        restoreSection
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
        .task {
            await subscriptionManager.loadProducts()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.pink)
            
            VStack(spacing: 8) {
                Text("Unlock Premium Wellness")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Access unlimited breathing sessions and family SharePlay features")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Active Subscription Section
    private var activeSubscriptionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Premium Active")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if subscriptionManager.hasFamilySubscription() {
                        Text("Family Plan • SharePlay Enabled")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Individual Plan")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(.green.opacity(0.1))
            .cornerRadius(12)
            
            Button("Manage Subscription") {
                showingManageSubscriptions = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Subscription Plans Section
    private var subscriptionPlansSection: some View {
        VStack(spacing: 16) {
            ForEach(subscriptionManager.availableProducts, id: \.id) { product in
                SubscriptionPlanCard(
                    product: product,
                    isRecommended: product.id == SubscriptionManager.SubscriptionProducts.family.rawValue,
                    onPurchase: {
                        Task {
                            await subscriptionManager.purchase(product)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Features Comparison Section
    private var featuresComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Included")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                FeatureRow(
                    icon: "person.fill",
                    title: "Personal Sessions",
                    individualIncluded: true,
                    familyIncluded: true
                )
                
                FeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Progress Tracking",
                    individualIncluded: true,
                    familyIncluded: true
                )
                
                FeatureRow(
                    icon: "wifi.slash",
                    title: "Offline Access",
                    individualIncluded: true,
                    familyIncluded: true
                )
                
                FeatureRow(
                    icon: "shareplay",
                    title: "SharePlay Sessions",
                    individualIncluded: false,
                    familyIncluded: true
                )
                
                FeatureRow(
                    icon: "person.3.fill",
                    title: "Family Dashboard",
                    individualIncluded: false,
                    familyIncluded: true
                )
                
                FeatureRow(
                    icon: "headphones",
                    title: "Priority Support",
                    individualIncluded: false,
                    familyIncluded: true
                )
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Restore Section
    private var restoreSection: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.blue)
            
            if let errorMessage = subscriptionManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Subscription Plan Card
struct SubscriptionPlanCard: View {
    let product: Product
    let isRecommended: Bool
    let onPurchase: () -> Void
    
    private var planType: SubscriptionManager.SubscriptionProducts? {
        SubscriptionManager.SubscriptionProducts(rawValue: product.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(planType?.displayName ?? product.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(.orange)
                                .foregroundStyle(.white)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("per month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Features
            if let features = planType?.features {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                                .font(.caption)
                            
                            Text(feature)
                                .font(.subheadline)
                        }
                    }
                }
            }
            
            // Free Trial Info
            if product.subscription?.introductoryOffer != nil {
                HStack {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.orange)
                    
                    Text("7-day free trial")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Purchase Button
            Button(action: onPurchase) {
                HStack {
                    Spacer()
                    Text("Start Free Trial")
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(isRecommended ? .blue.opacity(0.05) : .clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRecommended ? .blue : .gray.opacity(0.3), lineWidth: isRecommended ? 2 : 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let individualIncluded: Bool
    let familyIncluded: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 24) {
                Image(systemName: individualIncluded ? "checkmark" : "xmark")
                    .foregroundStyle(individualIncluded ? .green : .red)
                    .font(.caption)
                    .frame(width: 20)
                
                Image(systemName: familyIncluded ? "checkmark" : "xmark")
                    .foregroundStyle(familyIncluded ? .green : .red)
                    .font(.caption)
                    .frame(width: 20)
            }
        }
    }
}

#Preview {
    SubscriptionView()
}