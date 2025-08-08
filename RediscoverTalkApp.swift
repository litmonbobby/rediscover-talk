//
//  RediscoverTalkApp.swift
//  Rediscover Talk
//
//  Created by Claude on 2025-08-07.
//  Main app entry point with SharePlay and StoreKit integration
//

import SwiftUI
import StoreKit
import GroupActivities
import OSLog

@main
struct RediscoverTalkApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "RediscoverTalk", category: "App")
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .task {
                    await setupApp()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didFinishLaunchingNotification)) { _ in
                    configureStoreKit()
                }
        }
    }
    
    // MARK: - App Setup
    
    private func setupApp() async {
        logger.info("Setting up Rediscover Talk app")
        
        // Load subscription products
        await subscriptionManager.loadProducts()
        
        // Update purchased products  
        await subscriptionManager.updatePurchasedProducts()
        
        // Configure SharePlay
        await configureSharePlay()
        
        logger.info("App setup completed")
    }
    
    private func configureStoreKit() {
        // Configure StoreKit for testing
        #if DEBUG
        if let path = Bundle.main.path(forResource: "StoreKitConfiguration", ofType: "storekit") {
            logger.info("Loading StoreKit configuration from: \(path)")
        }
        #endif
    }
    
    private func configureSharePlay() async {
        logger.info("Configuring SharePlay for family breathing sessions")
        // SharePlay configuration will be handled by FamilyBreathingManager
    }
}

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BreatheView()
                .tabItem {
                    Image(systemName: "lungs")
                    Text("Breathe")
                }
                .tag(0)
            
            SubscriptionView()
                .tabItem {
                    Image(systemName: "person.3")
                    Text("Family")
                }
                .tag(1)
                
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .accentColor(.blue)
    }
}

// MARK: - Settings View (Placeholder)

struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            List {
                Section("Subscription") {
                    if subscriptionManager.hasActiveSubscription() {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("Active")
                                .foregroundColor(.green)
                        }
                        
                        if subscriptionManager.hasFamilySubscription() {
                            HStack {
                                Text("Type")
                                Spacer()
                                Text("Family Plan")
                            }
                        }
                    } else {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("Free Tier")
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SubscriptionManager())
    }
}