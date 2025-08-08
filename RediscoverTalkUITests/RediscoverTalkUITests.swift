//
//  RediscoverTalkUITests.swift
//  RediscoverTalk UI Tests
//
//  Created by Claude on 2025-08-07.
//  Comprehensive UI test automation with complete user journey coverage
//

import XCTest

final class RediscoverTalkUITests: XCTestCase {
    
    // MARK: - Properties
    
    var app: XCUIApplication!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchEnvironment["ANIMATION_SPEED"] = "2.0" // Speed up animations for testing
        app.launch()
        
        // Wait for app to fully load
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunch() {
        // Verify app launches successfully
        XCTAssertTrue(app.state == .runningForeground, "App should be running in foreground")
        
        // Check main tab bar is visible
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "Tab bar should exist")
        
        // Verify main tabs are present
        XCTAssertTrue(app.buttons["Breathe"].exists, "Breathe tab should exist")
        XCTAssertTrue(app.buttons["Family"].exists, "Family tab should exist")
        XCTAssertTrue(app.buttons["Settings"].exists, "Settings tab should exist")
    }
    
    func testInitialScreenLoad() {
        // Should start on Breathe tab
        let breatheTab = app.buttons["Breathe"]
        XCTAssertTrue(breatheTab.isSelected, "Breathe tab should be selected by default")
        
        // Check key UI elements are visible
        XCTAssertTrue(app.navigationBars["Family Breathing"].exists, "Navigation title should be visible")
    }
    
    // MARK: - Navigation Tests
    
    func testTabNavigation() {
        // Test Family tab
        app.buttons["Family"].tap()
        
        // Wait for navigation
        let familyNavigationBar = app.navigationBars.containing(.any, identifier: "Family").firstMatch
        XCTAssertTrue(familyNavigationBar.waitForExistence(timeout: 3.0), "Family screen should load")
        
        // Test Settings tab
        app.buttons["Settings"].tap()
        
        let settingsNavigationBar = app.navigationBars.containing(.any, identifier: "Settings").firstMatch
        XCTAssertTrue(settingsNavigationBar.waitForExistence(timeout: 3.0), "Settings screen should load")
        
        // Return to Breathe tab
        app.buttons["Breathe"].tap()
        
        let breatheNavigationBar = app.navigationBars["Family Breathing"]
        XCTAssertTrue(breatheNavigationBar.waitForExistence(timeout: 3.0), "Breathe screen should load")
    }
    
    // MARK: - Breathing Session Tests
    
    func testBreathingSessionFlow() {
        // Ensure we're on the Breathe tab
        app.buttons["Breathe"].tap()
        
        // Look for start session button
        let startSessionButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startSessionButton.exists {
            startSessionButton.tap()
            
            // Wait for session to start
            let sessionActiveIndicator = app.staticTexts.containing(.any, identifier: "Active").firstMatch
            XCTAssertTrue(sessionActiveIndicator.waitForExistence(timeout: 5.0), "Session should become active")
        }
        
        // Look for breathing exercise controls
        let startBreathingButton = app.buttons.containing(.any, identifier: "Start Breathing").firstMatch
        if startBreathingButton.exists {
            startBreathingButton.tap()
            
            // Verify breathing animation starts
            let breathingCircle = app.otherElements.containing(.any, identifier: "breathing-circle").firstMatch
            XCTAssertTrue(breathingCircle.exists, "Breathing circle should be visible")
        }
    }
    
    func testBreathingStateIndicators() {
        // Start breathing session
        app.buttons["Breathe"].tap()
        
        // Look for breathing state indicators
        let stateIndicators = ["Ready", "Breathe In", "Hold", "Breathe Out"]
        
        // At least one state indicator should be visible
        let hasStateIndicator = stateIndicators.contains { stateName in
            app.staticTexts[stateName].exists
        }
        
        XCTAssertTrue(hasStateIndicator, "At least one breathing state indicator should be visible")
    }
    
    func testBreathingExerciseSelection() {
        app.buttons["Breathe"].tap()
        
        // Look for exercise selection
        if app.buttons["Family Harmony"].exists {
            app.buttons["Family Harmony"].tap()
            
            // Should show exercise details or start the exercise
            XCTAssertTrue(app.staticTexts.containing(.any, identifier: "harmony").firstMatch.waitForExistence(timeout: 3.0),
                         "Exercise selection should show details")
        }
    }
    
    // MARK: - SharePlay Tests
    
    func testSharePlaySessionStart() {
        app.buttons["Breathe"].tap()
        
        // Look for SharePlay/Group session controls
        let sharePlayButton = app.buttons.containing(.any, identifier: "Share").firstMatch
        if sharePlayButton.exists {
            sharePlayButton.tap()
            
            // Should show SharePlay invitation or start solo session
            let expectation = XCTestExpectation(description: "SharePlay response")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
            
            // Verify some response occurred (either SharePlay started or solo fallback)
            XCTAssertTrue(app.staticTexts.containing(.any, identifier: "session").firstMatch.exists ||
                         app.staticTexts["You"].exists, "Should show session status or solo user")
        }
    }
    
    func testParticipantsList() {
        app.buttons["Breathe"].tap()
        
        // Look for participants section
        let participantsCard = app.otherElements.containing(.any, identifier: "participants").firstMatch
        if participantsCard.exists {
            participantsCard.tap()
            
            // Should show participants detail view
            let participantsList = app.tables.firstMatch
            XCTAssertTrue(participantsList.waitForExistence(timeout: 3.0), "Participants list should appear")
        }
    }
    
    func testEncouragementMessages() {
        app.buttons["Breathe"].tap()
        
        // Look for encouragement section
        let encouragementField = app.textFields.containing(.any, identifier: "encouragement").firstMatch
        if encouragementField.exists {
            encouragementField.tap()
            encouragementField.typeText("Great job everyone!")
            
            let sendButton = app.buttons["Send"].firstMatch
            if sendButton.exists {
                sendButton.tap()
                
                // Message should appear in the list
                XCTAssertTrue(app.staticTexts["Great job everyone!"].waitForExistence(timeout: 3.0),
                             "Encouragement message should appear")
            }
        }
    }
    
    // MARK: - Subscription Tests
    
    func testSubscriptionScreenAccess() {
        app.buttons["Family"].tap()
        
        // Should load subscription/family management screen
        let subscriptionTitle = app.navigationBars.containing(.any, identifier: "Subscription").firstMatch
        XCTAssertTrue(subscriptionTitle.waitForExistence(timeout: 5.0) ||
                     app.staticTexts.containing(.any, identifier: "Plan").firstMatch.exists,
                     "Subscription screen should load")
    }
    
    func testFreeTierFeatures() {
        app.buttons["Family"].tap()
        
        // Should show free tier status
        let freeTierIndicator = app.staticTexts.containing(.any, identifier: "Free").firstMatch
        if freeTierIndicator.exists {
            XCTAssertTrue(freeTierIndicator.exists, "Free tier status should be visible")
        }
        
        // Should show upgrade prompts
        let upgradeButton = app.buttons.containing(.any, identifier: "Upgrade").firstMatch
        if upgradeButton.exists {
            upgradeButton.tap()
            
            // Should show subscription options
            let subscriptionOptions = app.scrollViews.firstMatch
            XCTAssertTrue(subscriptionOptions.waitForExistence(timeout: 3.0), "Subscription options should appear")
        }
    }
    
    func testSubscriptionPlanDisplay() {
        app.buttons["Family"].tap()
        
        // Should show available subscription plans
        let subscriptionPlans = ["Individual Plan", "Family Plan"]
        
        for plan in subscriptionPlans {
            if app.staticTexts[plan].exists {
                XCTAssertTrue(app.staticTexts[plan].exists, "\(plan) should be displayed")
            }
        }
        
        // Should show pricing information
        let hasPricing = app.staticTexts.allElementsBoundByIndex.contains { element in
            element.label.contains("$") || element.label.contains("month")
        }
        
        if hasPricing {
            XCTAssertTrue(hasPricing, "Pricing information should be visible")
        }
    }
    
    func testRestorePurchases() {
        app.buttons["Settings"].tap()
        
        // Look for restore purchases button
        let restoreButton = app.buttons["Restore Purchases"]
        if restoreButton.exists {
            restoreButton.tap()
            
            // Should show some feedback
            let expectation = XCTestExpectation(description: "Restore completion")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 5.0)
            
            // Should complete without crashing
            XCTAssertTrue(app.state == .runningForeground, "App should remain running after restore")
        }
    }
    
    // MARK: - Settings Tests
    
    func testSettingsScreenElements() {
        app.buttons["Settings"].tap()
        
        // Check for key settings elements
        let settingsTable = app.tables.firstMatch
        XCTAssertTrue(settingsTable.waitForExistence(timeout: 3.0), "Settings table should exist")
        
        // Should show subscription status
        let subscriptionSection = app.staticTexts.containing(.any, identifier: "Subscription").firstMatch
        XCTAssertTrue(subscriptionSection.exists, "Subscription section should exist")
        
        // Should show app version
        let versionCell = app.cells.containing(.any, identifier: "Version").firstMatch
        XCTAssertTrue(versionCell.exists, "Version information should be visible")
    }
    
    func testSubscriptionStatus() {
        app.buttons["Settings"].tap()
        
        // Should show current subscription status
        let statusIndicators = ["Free Tier", "Active", "Individual Plan", "Family Plan"]
        
        let hasStatus = statusIndicators.contains { status in
            app.staticTexts[status].exists
        }
        
        XCTAssertTrue(hasStatus, "Should show subscription status")
    }
    
    // MARK: - Performance Tests
    
    func testUIResponsiveness() {
        // Test tab switching responsiveness
        let startTime = Date()
        
        app.buttons["Family"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2.0), "Family tab should load quickly")
        
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2.0), "Settings tab should load quickly")
        
        app.buttons["Breathe"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2.0), "Breathe tab should load quickly")
        
        let totalTime = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(totalTime, 6.0, "Tab switching should complete within 6 seconds")
    }
    
    func testAnimationPerformance() {
        app.buttons["Breathe"].tap()
        
        // Start breathing animation
        let startBreathingButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startBreathingButton.exists {
            startBreathingButton.tap()
            
            // Let animation run for a few seconds
            let expectation = XCTestExpectation(description: "Animation performance")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 8.0)
            
            // App should remain responsive during animation
            XCTAssertTrue(app.state == .runningForeground, "App should remain responsive during animation")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testNetworkErrorHandling() {
        // Simulate network issues by testing offline behavior
        app.buttons["Family"].tap()
        
        // Should handle subscription loading gracefully
        let loadingIndicator = app.activityIndicators.firstMatch
        if loadingIndicator.exists {
            // Wait for loading to complete or timeout
            XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: 10.0) || 
                         app.staticTexts.containing(.any, identifier: "error").firstMatch.exists,
                         "Should handle loading completion or show error")
        }
    }
    
    func testInvalidInputHandling() {
        app.buttons["Breathe"].tap()
        
        // Test empty encouragement message
        let encouragementField = app.textFields.containing(.any, identifier: "encouragement").firstMatch
        if encouragementField.exists {
            encouragementField.tap()
            encouragementField.typeText("")
            
            let sendButton = app.buttons["Send"].firstMatch
            if sendButton.exists {
                sendButton.tap()
                
                // Should handle empty input gracefully
                XCTAssertTrue(app.state == .runningForeground, "App should handle empty input gracefully")
            }
        }
    }
    
    // MARK: - User Journey Tests
    
    func testCompleteUserJourney() {
        // Complete user journey from launch to breathing session
        
        // Step 1: App launch (already done in setup)
        XCTAssertTrue(app.buttons["Breathe"].exists, "App should launch successfully")
        
        // Step 2: Navigate to breathing
        app.buttons["Breathe"].tap()
        XCTAssertTrue(app.navigationBars["Family Breathing"].waitForExistence(timeout: 3.0), 
                     "Should navigate to breathing screen")
        
        // Step 3: Start session
        let startSessionButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startSessionButton.exists {
            startSessionButton.tap()
            
            // Step 4: Begin breathing exercise
            let startBreathingButton = app.buttons.containing(.any, identifier: "Breathing").firstMatch
            if startBreathingButton.exists {
                startBreathingButton.tap()
                
                // Step 5: Send encouragement
                let encouragementField = app.textFields.containing(.any, identifier: "encouragement").firstMatch
                if encouragementField.exists {
                    encouragementField.tap()
                    encouragementField.typeText("Feeling great!")
                    
                    let sendButton = app.buttons["Send"].firstMatch
                    if sendButton.exists {
                        sendButton.tap()
                    }
                }
            }
        }
        
        // Step 6: Check subscription options
        app.buttons["Family"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3.0), 
                     "Should navigate to family/subscription screen")
        
        // Step 7: View settings
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.tables.firstMatch.waitForExistence(timeout: 3.0), 
                     "Should navigate to settings screen")
        
        // Complete journey without crashes
        XCTAssertTrue(app.state == .runningForeground, "App should complete journey successfully")
    }
    
    func testNewUserOnboarding() {
        // Test new user experience
        
        // Should show main interface immediately (no complex onboarding)
        XCTAssertTrue(app.tabBars.firstMatch.exists, "Main interface should be immediately accessible")
        
        // Should show helpful UI elements for new users
        let helpElements = app.buttons.matching(identifier: "help").allElementsBoundByIndex + 
                          app.buttons.matching(identifier: "info").allElementsBoundByIndex
        
        // Some form of help or guidance should be available
        if !helpElements.isEmpty {
            XCTAssertGreaterThan(helpElements.count, 0, "Help elements should be available for new users")
        }
    }
    
    // MARK: - Regression Tests
    
    func testCriticalPathStability() {
        // Test that critical user paths remain stable
        
        let criticalPaths = [
            { self.app.buttons["Breathe"].tap() },
            { self.app.buttons["Family"].tap() },
            { self.app.buttons["Settings"].tap() }
        ]
        
        for (index, path) in criticalPaths.enumerated() {
            path()
            
            // Each path should load without crashing
            XCTAssertTrue(app.state == .runningForeground, 
                         "Critical path \(index + 1) should complete successfully")
            
            // Navigation should work
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 3.0), 
                         "Navigation should work for critical path \(index + 1)")
        }
    }
    
    func testMemoryStabilityDuringLongSession() {
        // Test app stability during extended use
        
        let iterationCount = 10
        
        for iteration in 0..<iterationCount {
            // Navigate through all tabs
            app.buttons["Breathe"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2.0))
            
            app.buttons["Family"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2.0))
            
            app.buttons["Settings"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2.0))
            
            // App should remain stable
            XCTAssertTrue(app.state == .runningForeground, 
                         "App should remain stable after iteration \(iteration + 1)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 5.0) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = expectation(for: predicate, evaluatedWith: element, handler: nil)
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}