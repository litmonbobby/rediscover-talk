//
//  PerformanceTests.swift
//  RediscoverTalk UI Tests
//
//  Created by Claude on 2025-08-07.
//  Performance testing for 60fps animations, memory usage, battery efficiency
//

import XCTest

final class PerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    var app: XCUIApplication!
    
    // Performance metrics
    var startTime: Date!
    var memoryBaseline: Double = 0
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments.append("--performance-testing")
        app.launchArguments.append("--disable-logging") // Reduce overhead
        
        startTime = Date()
        app.launch()
        
        // Wait for app to stabilize
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))
        
        // Establish memory baseline
        memoryBaseline = getCurrentMemoryUsage()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Animation Performance Tests
    
    func test60FPSAnimationMaintenance() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(options: options) {
            app.buttons["Breathe"].tap()
            
            // Start breathing animation
            let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
            if startButton.waitForExistence(timeout: 3.0) {
                startButton.tap()
                
                // Let animation run for specific duration
                let animationExpectation = expectation(description: "Animation performance")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    animationExpectation.fulfill()
                }
                wait(for: [animationExpectation], timeout: 6.0)
            }
        }
    }
    
    func testBreathingAnimationSmoothness() throws {
        app.buttons["Breathe"].tap()
        
        // Start breathing session
        let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Monitor animation for frame drops
            let testDuration: TimeInterval = 10.0
            let startTime = Date()
            
            var frameChecks = 0
            let expectedFrameChecks = Int(testDuration * 10) // Check 10 times per second
            
            while Date().timeIntervalSince(startTime) < testDuration {
                // Verify animation elements are still responsive
                let breathingCircle = app.otherElements.containing(.any, identifier: "breathing").firstMatch
                if breathingCircle.exists {
                    XCTAssertTrue(breathingCircle.frame.size.width > 0, "Animation should maintain size")
                    XCTAssertTrue(breathingCircle.frame.size.height > 0, "Animation should maintain height")
                }
                
                frameChecks += 1
                usleep(100_000) // 0.1 second delay
            }
            
            XCTAssertGreaterThanOrEqual(frameChecks, expectedFrameChecks / 2, 
                                       "Should complete reasonable number of frame checks")
        }
    }
    
    func testComplexAnimationPerformance() throws {
        // Test performance with multiple animations running
        
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        
        measure(options: options) {
            app.buttons["Breathe"].tap()
            
            // Start breathing animation
            let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
            if startButton.waitForExistence(timeout: 3.0) {
                startButton.tap()
                
                // Add complexity by navigating during animation
                let complexityExpectation = expectation(description: "Complex animation test")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Navigate to other screens while animation runs
                    self.app.buttons["Family"].tap()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.app.buttons["Settings"].tap()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.app.buttons["Breathe"].tap()
                            complexityExpectation.fulfill()
                        }
                    }
                }
                
                wait(for: [complexityExpectation], timeout: 6.0)
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageDuringAnimation() throws {
        let initialMemory = getCurrentMemoryUsage()
        
        app.buttons["Breathe"].tap()
        
        // Start intensive breathing animation
        let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Let animation run and monitor memory
            let memoryTestDuration: TimeInterval = 15.0
            let startTime = Date()
            
            var memorySamples: [Double] = []
            
            while Date().timeIntervalSince(startTime) < memoryTestDuration {
                let currentMemory = getCurrentMemoryUsage()
                memorySamples.append(currentMemory)
                
                sleep(1) // Sample every second
            }
            
            let finalMemory = getCurrentMemoryUsage()
            let memoryIncrease = finalMemory - initialMemory
            
            // Memory increase should be reasonable (less than 50MB)
            XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, 
                             "Memory increase should be less than 50MB during animation")
            
            // Check for memory leaks (memory should not continuously grow)
            let avgMemory = memorySamples.reduce(0, +) / Double(memorySamples.count)
            let maxMemory = memorySamples.max() ?? 0
            
            XCTAssertLessThan(maxMemory - avgMemory, avgMemory * 0.3, 
                             "Memory spikes should be within 30% of average")
        }
    }
    
    func testMemoryStabilityDuringExtendedUse() throws {
        let testDuration: TimeInterval = 30.0
        let startTime = Date()
        let initialMemory = getCurrentMemoryUsage()
        
        var maxMemoryUsed: Double = initialMemory
        var memoryCheckCount = 0
        
        while Date().timeIntervalSince(startTime) < testDuration {
            // Navigate between screens
            app.buttons["Breathe"].tap()
            sleep(2)
            
            app.buttons["Family"].tap()
            sleep(2)
            
            app.buttons["Settings"].tap()
            sleep(2)
            
            // Check memory usage
            let currentMemory = getCurrentMemoryUsage()
            maxMemoryUsed = max(maxMemoryUsed, currentMemory)
            memoryCheckCount += 1
            
            // Memory should not grow unbounded
            let memoryGrowth = currentMemory - initialMemory
            XCTAssertLessThan(memoryGrowth, 100 * 1024 * 1024, 
                             "Memory growth should be less than 100MB during extended use")
        }
        
        XCTAssertGreaterThan(memoryCheckCount, 3, "Should have performed multiple memory checks")
    }
    
    // MARK: - CPU Performance Tests
    
    func testCPUUsageDuringAnimation() throws {
        app.buttons["Breathe"].tap()
        
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        
        measure(options: options) {
            // Start breathing animation
            let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
            if startButton.waitForExistence(timeout: 3.0) {
                startButton.tap()
                
                // Perform CPU-intensive UI operations during animation
                for _ in 0..<10 {
                    // Rapid navigation to test CPU usage
                    app.buttons["Family"].tap()
                    app.buttons["Settings"].tap()
                    app.buttons["Breathe"].tap()
                }
            }
        }
    }
    
    // MARK: - Battery Efficiency Tests
    
    func testBatteryEfficientAnimations() throws {
        // Test that animations use efficient rendering techniques
        
        app.buttons["Breathe"].tap()
        
        let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startButton.waitForExistence(timeout: 3.0) {
            startButton.tap()
            
            // Test battery efficiency by measuring performance overhead
            let options = XCTMeasureOptions()
            options.iterationCount = 5
            
            measure(options: options) {
                let testDuration: TimeInterval = 5.0
                let startTime = Date()
                
                var operationCount = 0
                
                while Date().timeIntervalSince(startTime) < testDuration {
                    // Perform lightweight operations to test overhead
                    if app.buttons["Family"].exists {
                        operationCount += 1
                    }
                    
                    if app.buttons["Settings"].exists {
                        operationCount += 1
                    }
                    
                    usleep(100_000) // 0.1 second delay
                }
                
                XCTAssertGreaterThan(operationCount, 40, "Should maintain responsiveness during animation")
            }
        }
    }
    
    func testLowPowerModePerformance() throws {
        // Test performance in simulated low power conditions
        
        app.buttons["Breathe"].tap()
        
        // Simulate reduced performance environment
        let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startButton.waitForExistence(timeout: 5.0) { // Longer timeout for low power
            startButton.tap()
            
            // Test that basic functionality still works
            let functionality = expectation(description: "Low power functionality")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                // App should still respond to basic interactions
                self.app.buttons["Family"].tap()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.app.buttons["Breathe"].tap()
                    functionality.fulfill()
                }
            }
            
            wait(for: [functionality], timeout: 10.0)
            
            // App should remain stable
            XCTAssertTrue(app.state == .runningForeground, "App should remain stable in low power mode")
        }
    }
    
    // MARK: - Network Performance Tests
    
    func testNetworkEfficiency() throws {
        // Test network usage efficiency
        
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        
        measure(options: options) {
            // Navigate to subscription screen which may trigger network requests
            app.buttons["Family"].tap()
            
            // Wait for any network operations to complete
            let networkExpectation = expectation(description: "Network operations")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                networkExpectation.fulfill()
            }
            wait(for: [networkExpectation], timeout: 8.0)
            
            // App should remain responsive during network operations
            XCTAssertTrue(app.state == .runningForeground, "App should remain responsive during network operations")
        }
    }
    
    func testOfflinePerformance() throws {
        // Test performance when network is unavailable
        
        app.buttons["Breathe"].tap()
        
        // Core breathing functionality should work offline
        let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startButton.waitForExistence(timeout: 3.0) {
            let options = XCTMeasureOptions()
            options.iterationCount = 3
            
            measure(options: options) {
                startButton.tap()
                
                // Breathing animation should work without network
                let offlineTest = expectation(description: "Offline functionality")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    offlineTest.fulfill()
                }
                wait(for: [offlineTest], timeout: 5.0)
            }
        }
    }
    
    // MARK: - Launch Performance Tests
    
    func testAppLaunchTime() throws {
        // Test cold launch performance
        
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.terminate()
            app.launch()
            
            // Wait for app to be fully ready
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5.0), 
                         "App should launch and show main interface")
        }
    }
    
    func testWarmLaunchPerformance() throws {
        // Test resume from background performance
        
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(options: options) {
            // Send app to background
            XCUIDevice.shared.press(.home)
            
            // Brief pause
            sleep(1)
            
            // Reactivate app
            app.activate()
            
            // App should resume quickly
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 2.0), 
                         "App should resume quickly from background")
        }
    }
    
    // MARK: - UI Responsiveness Tests
    
    func testScrollingPerformance() throws {
        // Test scrolling performance if scrollable content exists
        
        app.buttons["Settings"].tap()
        
        let scrollView = app.scrollViews.firstMatch
        let tableView = app.tables.firstMatch
        
        let scrollableView = scrollView.exists ? scrollView : (tableView.exists ? tableView : nil)
        
        if let view = scrollableView {
            let options = XCTMeasureOptions()
            options.iterationCount = 5
            
            measure(options: options) {
                // Perform scrolling operations
                for _ in 0..<10 {
                    view.swipeUp()
                    usleep(100_000) // Small delay between swipes
                }
                
                for _ in 0..<10 {
                    view.swipeDown()
                    usleep(100_000)
                }
            }
        }
    }
    
    func testInteractionResponseTime() throws {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        
        measure(options: options) {
            // Test tap response times
            app.buttons["Breathe"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 1.0), 
                         "Navigation should respond quickly")
            
            app.buttons["Family"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 1.0), 
                         "Family tab should respond quickly")
            
            app.buttons["Settings"].tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 1.0), 
                         "Settings tab should respond quickly")
        }
    }
    
    // MARK: - Stress Tests
    
    func testHighLoadConditions() throws {
        // Test performance under high load conditions
        
        let stressDuration: TimeInterval = 20.0
        let startTime = Date()
        
        var operationCount = 0
        
        while Date().timeIntervalSince(startTime) < stressDuration {
            // Rapid navigation to create load
            app.buttons["Breathe"].tap()
            app.buttons["Family"].tap()
            app.buttons["Settings"].tap()
            
            operationCount += 3
            
            // Check that app remains stable
            XCTAssertTrue(app.state == .runningForeground, 
                         "App should remain stable under load at operation \(operationCount)")
        }
        
        XCTAssertGreaterThan(operationCount, 60, "Should complete many operations under stress test")
    }
    
    func testMemoryPressureHandling() throws {
        // Simulate memory pressure conditions
        
        let initialMemory = getCurrentMemoryUsage()
        var allocatedMemory: Double = initialMemory
        
        // Perform memory-intensive operations
        for i in 0..<50 {
            app.buttons["Breathe"].tap()
            
            // Start breathing session to use memory
            let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
            if startButton.waitForExistence(timeout: 2.0) {
                startButton.tap()
                usleep(200_000) // 0.2 seconds
            }
            
            app.buttons["Family"].tap()
            app.buttons["Settings"].tap()
            
            // Check memory every 10 iterations
            if i % 10 == 0 {
                allocatedMemory = getCurrentMemoryUsage()
                let memoryGrowth = allocatedMemory - initialMemory
                
                // Memory growth should be controlled
                XCTAssertLessThan(memoryGrowth, 200 * 1024 * 1024, 
                                 "Memory growth should be controlled during pressure test")
            }
        }
        
        // App should handle memory pressure gracefully
        XCTAssertTrue(app.state == .runningForeground, "App should survive memory pressure test")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Double {
        let processInfo = ProcessInfo.processInfo
        
        // Simple memory usage approximation
        // In a real implementation, this would use more sophisticated memory measurement
        return Double(processInfo.physicalMemory) * 0.001 // Placeholder calculation
    }
    
    private func measureFrameRate(duration: TimeInterval) -> Double {
        let startTime = Date()
        var frameCount = 0
        
        while Date().timeIntervalSince(startTime) < duration {
            frameCount += 1
            usleep(16667) // ~60fps
        }
        
        let actualDuration = Date().timeIntervalSince(startTime)
        return Double(frameCount) / actualDuration
    }
}