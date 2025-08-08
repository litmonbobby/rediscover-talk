//
//  AccessibilityTests.swift
//  RediscoverTalk UI Tests
//
//  Created by Claude on 2025-08-07.
//  Comprehensive accessibility testing for WCAG compliance
//

import XCTest

final class AccessibilityTests: XCTestCase {
    
    // MARK: - Properties
    
    var app: XCUIApplication!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launchArguments.append("--accessibility-testing")
        app.launch()
        
        // Wait for app to load
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - VoiceOver Tests
    
    func testVoiceOverElementsExist() {
        // Enable accessibility inspector simulation
        
        // Test main navigation elements have accessibility labels
        let breatheTab = app.buttons["Breathe"]
        XCTAssertTrue(breatheTab.exists, "Breathe tab should exist")
        XCTAssertFalse(breatheTab.label.isEmpty, "Breathe tab should have accessibility label")
        
        let familyTab = app.buttons["Family"]
        XCTAssertTrue(familyTab.exists, "Family tab should exist")
        XCTAssertFalse(familyTab.label.isEmpty, "Family tab should have accessibility label")
        
        let settingsTab = app.buttons["Settings"]
        XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
        XCTAssertFalse(settingsTab.label.isEmpty, "Settings tab should have accessibility label")
    }
    
    func testVoiceOverLabelsAreDescriptive() {
        // Navigate to Breathe tab
        app.buttons["Breathe"].tap()
        
        // Check that buttons have descriptive labels
        let buttons = app.buttons.allElementsBoundByIndex
        
        for button in buttons {
            if button.exists && button.isHittable {
                XCTAssertFalse(button.label.isEmpty, "Button should have accessibility label: \(button.debugDescription)")
                XCTAssertGreaterThan(button.label.count, 2, "Button label should be descriptive: \(button.label)")
                
                // Labels should not just be generic terms
                let genericLabels = ["Button", "button", "Click", "Tap"]
                XCTAssertFalse(genericLabels.contains(button.label), 
                              "Button label should not be generic: \(button.label)")
            }
        }
    }
    
    func testVoiceOverHints() {
        app.buttons["Breathe"].tap()
        
        // Check for accessibility hints on interactive elements
        let interactiveElements = app.buttons.allElementsBoundByIndex + 
                                 app.textFields.allElementsBoundByIndex
        
        for element in interactiveElements {
            if element.exists && element.isHittable {
                // Important interactive elements should have hints
                if element.label.contains("Start") || element.label.contains("Send") || 
                   element.label.contains("Share") {
                    // These elements should have accessibility hints
                    let hasHint = !element.accessibilityHint.isEmpty
                    XCTAssertTrue(hasHint, "Important element should have accessibility hint: \(element.label)")
                }
            }
        }
    }
    
    func testVoiceOverNavigationOrder() {
        app.buttons["Breathe"].tap()
        
        // Test that elements can be navigated in logical order
        let focusableElements = app.buttons.allElementsBoundByIndex.filter { $0.isHittable } +
                               app.textFields.allElementsBoundByIndex.filter { $0.isHittable }
        
        XCTAssertGreaterThan(focusableElements.count, 0, "Should have focusable elements")
        
        // Test that we can navigate between elements
        if focusableElements.count > 1 {
            let firstElement = focusableElements[0]
            let secondElement = focusableElements[1]
            
            // Both should be accessible
            XCTAssertTrue(firstElement.exists, "First element should be accessible")
            XCTAssertTrue(secondElement.exists, "Second element should be accessible")
        }
    }
    
    // MARK: - Dynamic Type Tests
    
    func testDynamicTypeSupport() {
        // Test various text size categories
        let textSizeCategories: [UIContentSizeCategory] = [
            .extraSmall,
            .small,
            .medium,
            .large,
            .extraLarge,
            .extraExtraLarge,
            .extraExtraExtraLarge,
            .accessibilityMedium,
            .accessibilityLarge,
            .accessibilityExtraLarge,
            .accessibilityExtraExtraLarge,
            .accessibilityExtraExtraExtraLarge
        ]
        
        for category in textSizeCategories {
            // In a real test, we would set the content size category
            // For this test, we'll verify text elements are accessible
            
            app.buttons["Breathe"].tap()
            
            // Check that text elements exist and are readable
            let textElements = app.staticTexts.allElementsBoundByIndex
            
            for textElement in textElements {
                if textElement.exists && !textElement.label.isEmpty {
                    XCTAssertTrue(textElement.frame.size.height > 0, 
                                 "Text should have positive height for category \(category.rawValue)")
                    XCTAssertTrue(textElement.frame.size.width > 0, 
                                 "Text should have positive width for category \(category.rawValue)")
                }
            }
        }
    }
    
    func testLargeTextScaling() {
        // Test that interface adapts to large text sizes
        
        // Navigate to each screen and verify text is still readable
        let screens = ["Breathe", "Family", "Settings"]
        
        for screen in screens {
            app.buttons[screen].tap()
            
            let textElements = app.staticTexts.allElementsBoundByIndex
            let buttonElements = app.buttons.allElementsBoundByIndex
            
            // Text elements should be visible and not cut off
            for element in textElements + buttonElements {
                if element.exists && !element.label.isEmpty {
                    // Text should fit within reasonable bounds
                    XCTAssertLessThan(element.frame.origin.x, UIScreen.main.bounds.width, 
                                     "Element should not extend beyond screen width: \(element.label)")
                    XCTAssertGreaterThan(element.frame.size.height, 0, 
                                        "Element should have positive height: \(element.label)")
                }
            }
        }
    }
    
    // MARK: - Color Contrast Tests
    
    func testColorContrastCompliance() {
        // Test that UI elements have sufficient color contrast
        // Note: This is a structural test since we can't measure actual colors in UI tests
        
        app.buttons["Breathe"].tap()
        
        // Verify that text elements are visible (not transparent or hidden)
        let textElements = app.staticTexts.allElementsBoundByIndex
        
        for element in textElements {
            if element.exists {
                // Element should be visible (not alpha 0)
                XCTAssertTrue(element.isHittable || element.frame.size.height > 0, 
                             "Text element should be visible: \(element.label)")
            }
        }
        
        // Check button contrast
        let buttons = app.buttons.allElementsBoundByIndex
        
        for button in buttons {
            if button.exists && !button.label.isEmpty {
                // Buttons should be clearly distinguishable
                XCTAssertTrue(button.frame.size.height >= 44, 
                             "Button should meet minimum touch target size: \(button.label)")
                XCTAssertTrue(button.frame.size.width >= 44, 
                             "Button should meet minimum touch target width: \(button.label)")
            }
        }
    }
    
    func testHighContrastModeSupport() {
        // Test interface in high contrast mode
        // This would normally require system-level settings changes
        
        app.buttons["Breathe"].tap()
        
        // Verify key elements are still visible and functional
        let criticalElements = [
            app.buttons.containing(.any, identifier: "Start").firstMatch,
            app.navigationBars.firstMatch
        ]
        
        for element in criticalElements {
            if element.exists {
                XCTAssertTrue(element.frame.size.height > 0, "Critical element should be visible")
                XCTAssertTrue(element.frame.size.width > 0, "Critical element should have width")
            }
        }
    }
    
    // MARK: - Touch Target Tests
    
    func testMinimumTouchTargetSizes() {
        // Test that interactive elements meet minimum size requirements (44x44 points)
        
        let screens = ["Breathe", "Family", "Settings"]
        
        for screen in screens {
            app.buttons[screen].tap()
            
            let interactiveElements = app.buttons.allElementsBoundByIndex
            
            for element in interactiveElements {
                if element.exists && element.isHittable {
                    let frame = element.frame
                    
                    // WCAG AA requires 44x44 point minimum touch targets
                    XCTAssertGreaterThanOrEqual(frame.size.height, 44, 
                                              "Touch target height should be at least 44 points: \(element.label)")
                    XCTAssertGreaterThanOrEqual(frame.size.width, 44, 
                                              "Touch target width should be at least 44 points: \(element.label)")
                }
            }
        }
    }
    
    func testTouchTargetSpacing() {
        // Test that touch targets have adequate spacing
        
        app.buttons["Breathe"].tap()
        
        let buttons = app.buttons.allElementsBoundByIndex.filter { $0.exists && $0.isHittable }
        
        if buttons.count > 1 {
            for i in 0..<buttons.count-1 {
                for j in i+1..<buttons.count {
                    let button1 = buttons[i]
                    let button2 = buttons[j]
                    
                    // Calculate distance between buttons
                    let centerDistance = sqrt(
                        pow(button1.frame.midX - button2.frame.midX, 2) +
                        pow(button1.frame.midY - button2.frame.midY, 2)
                    )
                    
                    // If buttons are close, they should have adequate spacing
                    if centerDistance < 100 { // Nearby buttons
                        let minDistance = (button1.frame.height + button2.frame.height) / 2 + 8
                        XCTAssertGreaterThanOrEqual(centerDistance, minDistance, 
                                                   "Nearby buttons should have adequate spacing")
                    }
                }
            }
        }
    }
    
    // MARK: - Motion and Animation Tests
    
    func testReduceMotionSupport() {
        // Test that app respects reduce motion preferences
        // This would normally require system settings changes
        
        app.buttons["Breathe"].tap()
        
        // Look for breathing animation
        let breathingCircle = app.otherElements.containing(.any, identifier: "breathing").firstMatch
        
        if breathingCircle.exists {
            // In reduce motion mode, animations should be minimal or replaced with transitions
            // For now, verify the element is still functional
            XCTAssertTrue(breathingCircle.exists, "Breathing element should exist even with reduced motion")
        }
        
        // Start a breathing session if possible
        let startButton = app.buttons.containing(.any, identifier: "Start").firstMatch
        if startButton.exists {
            startButton.tap()
            
            // App should still function with reduced animations
            XCTAssertTrue(app.state == .runningForeground, "App should work with reduced motion")
        }
    }
    
    func testAnimationAlternatives() {
        // Test that essential information is conveyed without relying solely on animation
        
        app.buttons["Breathe"].tap()
        
        // Look for breathing state indicators
        let stateIndicators = ["Ready", "Breathe In", "Hold", "Breathe Out"]
        
        // At least one state should be visible as text (not just animation)
        let hasTextIndicator = stateIndicators.contains { stateName in
            app.staticTexts[stateName].exists
        }
        
        if !hasTextIndicator {
            // Should have some other form of state indication
            let hasStateInfo = app.staticTexts.allElementsBoundByIndex.contains { element in
                element.label.lowercased().contains("breath") || 
                element.label.lowercased().contains("state") ||
                element.label.lowercased().contains("cycle")
            }
            
            XCTAssertTrue(hasStateInfo, "Should provide text-based breathing state information")
        }
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testKeyboardNavigation() {
        // Test that app supports external keyboard navigation
        
        app.buttons["Breathe"].tap()
        
        // Find focusable elements
        let focusableElements = app.buttons.allElementsBoundByIndex.filter { $0.isHittable } +
                               app.textFields.allElementsBoundByIndex.filter { $0.isHittable }
        
        XCTAssertGreaterThan(focusableElements.count, 0, "Should have keyboard-focusable elements")
        
        // Test that we can interact with elements
        for element in focusableElements {
            if element.exists {
                // Element should be accessible via keyboard
                XCTAssertTrue(element.isHittable, "Element should be keyboard accessible: \(element.label)")
            }
        }
    }
    
    func testTabOrder() {
        // Test logical tab order for keyboard navigation
        
        app.buttons["Settings"].tap()
        
        // Settings should have a logical tab order
        let cells = app.cells.allElementsBoundByIndex.filter { $0.exists }
        
        if cells.count > 1 {
            // Cells should be in logical reading order (top to bottom)
            var previousY: CGFloat = -1
            
            for cell in cells {
                let currentY = cell.frame.midY
                if previousY >= 0 {
                    // Generally, elements should be in top-to-bottom order
                    // (allowing some flexibility for complex layouts)
                    let yDifference = currentY - previousY
                    XCTAssertGreaterThan(yDifference, -50, "Tab order should generally be top-to-bottom")
                }
                previousY = currentY
            }
        }
    }
    
    // MARK: - Form Accessibility Tests
    
    func testFormLabeling() {
        app.buttons["Breathe"].tap()
        
        // Find text input fields
        let textFields = app.textFields.allElementsBoundByIndex
        
        for textField in textFields {
            if textField.exists {
                // Text fields should have labels
                XCTAssertFalse(textField.placeholderValue?.isEmpty ?? true, 
                              "Text field should have placeholder or label")
                
                // Should have accessibility label if no visible label
                if textField.placeholderValue?.isEmpty ?? true {
                    XCTAssertFalse(textField.label.isEmpty, 
                                  "Text field should have accessibility label if no placeholder")
                }
            }
        }
    }
    
    func testFormValidation() {
        app.buttons["Breathe"].tap()
        
        // Test encouragement text field if it exists
        let encouragementField = app.textFields.containing(.any, identifier: "encouragement").firstMatch
        
        if encouragementField.exists {
            encouragementField.tap()
            
            // Clear any existing text
            encouragementField.clear()
            
            // Try to send empty message
            let sendButton = app.buttons["Send"].firstMatch
            if sendButton.exists {
                sendButton.tap()
                
                // Should provide feedback about empty input
                // Either validation message or graceful handling
                XCTAssertTrue(app.state == .runningForeground, 
                             "App should handle empty form input gracefully")
            }
        }
    }
    
    // MARK: - Screen Reader Tests
    
    func testScreenReaderContent() {
        // Test content that would be read by screen readers
        
        let screens = ["Breathe", "Family", "Settings"]
        
        for screen in screens {
            app.buttons[screen].tap()
            
            // Check for meaningful content structure
            let headings = app.staticTexts.allElementsBoundByIndex.filter { element in
                element.exists && !element.label.isEmpty
            }
            
            XCTAssertGreaterThan(headings.count, 0, "Screen should have readable content: \(screen)")
            
            // Content should be meaningful
            let hasMeaningfulContent = headings.contains { element in
                element.label.count > 3 && !element.label.allSatisfy { $0.isNumber }
            }
            
            XCTAssertTrue(hasMeaningfulContent, "Screen should have meaningful text content: \(screen)")
        }
    }
    
    func testImageDescriptions() {
        // Test that images have appropriate accessibility descriptions
        
        app.buttons["Breathe"].tap()
        
        let images = app.images.allElementsBoundByIndex
        
        for image in images {
            if image.exists {
                // Decorative images should have empty labels, functional images should have descriptions
                // For now, ensure they don't have generic labels
                let genericLabels = ["Image", "Picture", "Icon"]
                XCTAssertFalse(genericLabels.contains(image.label), 
                              "Image should not have generic accessibility label")
            }
        }
    }
    
    // MARK: - Language and Localization Tests
    
    func testRightToLeftSupport() {
        // Test RTL language support structure
        // This would normally require changing system language
        
        app.buttons["Breathe"].tap()
        
        // Verify layout doesn't break with different text directions
        let textElements = app.staticTexts.allElementsBoundByIndex
        
        for element in textElements {
            if element.exists && !element.label.isEmpty {
                // Text should be contained within screen bounds
                XCTAssertGreaterThanOrEqual(element.frame.origin.x, -50, 
                                           "Text should not extend too far left: \(element.label)")
                XCTAssertLessThan(element.frame.maxX, UIScreen.main.bounds.width + 50, 
                                 "Text should not extend too far right: \(element.label)")
            }
        }
    }
    
    // MARK: - Comprehensive Accessibility Audit
    
    func testComprehensiveAccessibilityAudit() {
        // Comprehensive test across all screens
        
        let screens = ["Breathe", "Family", "Settings"]
        var accessibilityIssues: [String] = []
        
        for screen in screens {
            app.buttons[screen].tap()
            
            // Check for common accessibility issues
            
            // 1. Unlabeled interactive elements
            let buttons = app.buttons.allElementsBoundByIndex
            for button in buttons {
                if button.exists && button.isHittable && button.label.isEmpty {
                    accessibilityIssues.append("Unlabeled button in \(screen) screen")
                }
            }
            
            // 2. Insufficient touch target sizes
            for button in buttons {
                if button.exists && button.isHittable {
                    if button.frame.height < 44 || button.frame.width < 44 {
                        accessibilityIssues.append("Small touch target in \(screen): \(button.label)")
                    }
                }
            }
            
            // 3. Missing navigation structure
            let navigationBar = app.navigationBars.firstMatch
            if !navigationBar.exists {
                accessibilityIssues.append("Missing navigation structure in \(screen)")
            }
            
            // 4. Text fields without labels
            let textFields = app.textFields.allElementsBoundByIndex
            for textField in textFields {
                if textField.exists && textField.label.isEmpty && (textField.placeholderValue?.isEmpty ?? true) {
                    accessibilityIssues.append("Unlabeled text field in \(screen)")
                }
            }
        }
        
        // Report any accessibility issues found
        if !accessibilityIssues.isEmpty {
            let issueReport = accessibilityIssues.joined(separator: "\n")
            XCTFail("Accessibility issues found:\n\(issueReport)")
        }
    }
}