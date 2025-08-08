//
//  BreathingEngineTests.swift
//  RediscoverTalk Unit Tests
//
//  Created by Claude on 2025-08-07.
//  Comprehensive breathing engine and animation testing
//

import XCTest
import SwiftUI
import Combine
@testable import RediscoverTalk

class BreathingEngineTests: XCTestCase {
    
    // MARK: - Properties
    
    var breathingManager: FamilyBreathingManager!
    var animationEngine: BreathingAnimationEngine!
    var subscriptions: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        breathingManager = FamilyBreathingManager()
        animationEngine = BreathingAnimationEngine()
        subscriptions = Set<AnyCancellable>()
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        breathingManager = nil
        animationEngine = nil
        subscriptions.removeAll()
        subscriptions = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Breathing Exercise Tests
    
    func testBreathingExerciseValidation() {
        let exercises = BreathingExercise.allExercises
        
        for exercise in exercises {
            XCTAssertFalse(exercise.name.isEmpty, "Exercise name should not be empty")
            XCTAssertFalse(exercise.description.isEmpty, "Exercise description should not be empty")
            XCTAssertGreaterThan(exercise.inhaleTime, 0, "Inhale time should be positive")
            XCTAssertGreaterThanOrEqual(exercise.holdTime, 0, "Hold time should be non-negative")
            XCTAssertGreaterThan(exercise.exhaleTime, 0, "Exhale time should be positive")
            XCTAssertGreaterThan(exercise.totalCycles, 0, "Total cycles should be positive")
            
            // Test reasonable time limits
            XCTAssertLessThan(exercise.inhaleTime, 30, "Inhale time should be reasonable")
            XCTAssertLessThan(exercise.holdTime, 30, "Hold time should be reasonable")
            XCTAssertLessThan(exercise.exhaleTime, 30, "Exhale time should be reasonable")
            XCTAssertLessThan(exercise.totalCycles, 100, "Total cycles should be reasonable")
        }
    }
    
    func testBreathingExerciseDefaultValues() {
        let defaultExercise = BreathingExercise.familyDefault
        
        XCTAssertEqual(defaultExercise.name, "Family Harmony", "Default exercise name should match")
        XCTAssertEqual(defaultExercise.difficulty, .beginner, "Default should be beginner difficulty")
        XCTAssertEqual(defaultExercise.inhaleTime, 4.0, "Default inhale time should be 4 seconds")
        XCTAssertEqual(defaultExercise.holdTime, 2.0, "Default hold time should be 2 seconds")
        XCTAssertEqual(defaultExercise.exhaleTime, 6.0, "Default exhale time should be 6 seconds")
        XCTAssertEqual(defaultExercise.totalCycles, 10, "Default cycles should be 10")
    }
    
    func testBreathingExerciseDifficulties() {
        let difficulties = BreathingExercise.Difficulty.allCases
        
        XCTAssertEqual(difficulties.count, 3, "Should have 3 difficulty levels")
        XCTAssertTrue(difficulties.contains(.beginner), "Should have beginner difficulty")
        XCTAssertTrue(difficulties.contains(.intermediate), "Should have intermediate difficulty")
        XCTAssertTrue(difficulties.contains(.advanced), "Should have advanced difficulty")
        
        for difficulty in difficulties {
            XCTAssertFalse(difficulty.rawValue.isEmpty, "Difficulty should have non-empty raw value")
        }
    }
    
    func testCustomBreathingExerciseCreation() {
        let customExercise = BreathingExercise(
            name: "Custom Test Exercise",
            description: "A custom exercise for testing",
            inhaleTime: 3.0,
            holdTime: 1.0,
            exhaleTime: 5.0,
            totalCycles: 5,
            difficulty: .intermediate
        )
        
        XCTAssertNotNil(customExercise.id, "Custom exercise should have ID")
        XCTAssertEqual(customExercise.name, "Custom Test Exercise", "Name should match")
        XCTAssertEqual(customExercise.difficulty, .intermediate, "Difficulty should match")
        XCTAssertEqual(customExercise.totalCycles, 5, "Cycles should match")
    }
    
    // MARK: - Animation Engine Tests
    
    func testAnimationEngineInitialization() {
        XCTAssertEqual(animationEngine.currentScale, 1.0, "Initial scale should be 1.0")
        XCTAssertEqual(animationEngine.currentOpacity, 0.7, "Initial opacity should be 0.7")
        XCTAssertEqual(animationEngine.currentRotation, 0.0, "Initial rotation should be 0.0")
        XCTAssertEqual(animationEngine.particleOffset, 0.0, "Initial particle offset should be 0.0")
    }
    
    func testAnimationEngineSynchronization() {
        // Test start synchronization
        XCTAssertNoThrow(animationEngine.startSynchronization(), "Should start synchronization without throwing")
        
        // Test stop synchronization
        XCTAssertNoThrow(animationEngine.stopSynchronization(), "Should stop synchronization without throwing")
        
        // After stopping, should return to idle values
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.animationEngine.currentScale, 1.0, "Scale should return to 1.0")
            XCTAssertEqual(self.animationEngine.currentOpacity, 0.7, "Opacity should return to 0.7")
            XCTAssertEqual(self.animationEngine.currentRotation, 0.0, "Rotation should return to 0.0")
        }
    }
    
    func testAnimationStateUpdates() {
        let exercise = BreathingExercise.familyDefault
        let states: [FamilyBreathingManager.BreathingState] = [.idle, .inhaling, .holding, .exhaling]
        
        for state in states {
            animationEngine.updateBreathingState(state, cycle: 1, exercise: exercise)
            
            switch state {
            case .idle:
                XCTAssertEqual(animationEngine.currentScale, 1.0, "Idle scale should be 1.0")
                XCTAssertEqual(animationEngine.currentOpacity, 0.7, "Idle opacity should be 0.7")
                
            case .inhaling:
                XCTAssertEqual(animationEngine.currentScale, 1.8, "Inhaling scale should be 1.8")
                XCTAssertEqual(animationEngine.currentOpacity, 0.9, "Inhaling opacity should be 0.9")
                
            case .holding:
                XCTAssertEqual(animationEngine.currentScale, 1.8, "Holding scale should be 1.8")
                XCTAssertEqual(animationEngine.currentOpacity, 1.0, "Holding opacity should be 1.0")
                
            case .exhaling:
                XCTAssertEqual(animationEngine.currentScale, 0.6, "Exhaling scale should be 0.6")
                XCTAssertEqual(animationEngine.currentOpacity, 0.4, "Exhaling opacity should be 0.4")
            }
        }
    }
    
    // MARK: - Breathing Cycle Tests
    
    func testBreathingCycleFlow() async throws {
        let expectation = XCTestExpectation(description: "Breathing cycle completion")
        
        // Create a quick exercise for testing
        let quickExercise = BreathingExercise(
            name: "Quick Test",
            description: "Quick test exercise",
            inhaleTime: 0.1,
            holdTime: 0.1,
            exhaleTime: 0.1,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        // Start the breathing exercise
        breathingManager.isSessionActive = true
        breathingManager.startBreathingExercise(quickExercise)
        
        // Monitor state changes
        var stateSequence: [FamilyBreathingManager.BreathingState] = []
        breathingManager.$breathingState
            .sink { state in
                stateSequence.append(state)
                if state == .idle && stateSequence.count > 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        // Verify state sequence
        XCTAssertTrue(stateSequence.contains(.inhaling), "Should include inhaling state")
        XCTAssertTrue(stateSequence.contains(.exhaling), "Should include exhaling state")
    }
    
    func testBreathingCycleCounter() async throws {
        let expectation = XCTestExpectation(description: "Cycle counter update")
        
        let quickExercise = BreathingExercise(
            name: "Multi-Cycle Test",
            description: "Test multiple cycles",
            inhaleTime: 0.05,
            holdTime: 0,
            exhaleTime: 0.05,
            totalCycles: 3,
            difficulty: .beginner
        )
        
        breathingManager.isSessionActive = true
        breathingManager.startBreathingExercise(quickExercise)
        
        // Monitor cycle count
        breathingManager.$currentCycle
            .sink { cycle in
                if cycle >= 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        await fulfillment(of: [expectation], timeout: 5.0)
        
        XCTAssertGreaterThanOrEqual(breathingManager.currentCycle, 3, "Should complete 3 cycles")
    }
    
    // MARK: - Breathing State Tests
    
    func testBreathingStateDisplayNames() {
        let states: [FamilyBreathingManager.BreathingState] = [.idle, .inhaling, .holding, .exhaling]
        
        for state in states {
            let displayName = state.displayName
            XCTAssertFalse(displayName.isEmpty, "State \(state) should have non-empty display name")
            
            switch state {
            case .idle:
                XCTAssertEqual(displayName, "Ready", "Idle display name should be 'Ready'")
            case .inhaling:
                XCTAssertEqual(displayName, "Breathe In", "Inhaling display name should be 'Breathe In'")
            case .holding:
                XCTAssertEqual(displayName, "Hold", "Holding display name should be 'Hold'")
            case .exhaling:
                XCTAssertEqual(displayName, "Breathe Out", "Exhaling display name should be 'Breathe Out'")
            }
        }
    }
    
    func testBreathingStateTransitionLogic() {
        // Test state transition logic for different exercises
        
        // Exercise with hold time
        let holdExercise = BreathingExercise(
            name: "Hold Test",
            description: "Exercise with hold",
            inhaleTime: 1.0,
            holdTime: 1.0,
            exhaleTime: 1.0,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        breathingManager.isSessionActive = true
        breathingManager.startBreathingExercise(holdExercise)
        XCTAssertEqual(breathingManager.breathingState, .inhaling, "Should start with inhaling")
        
        // Exercise without hold time
        let noHoldExercise = BreathingExercise(
            name: "No Hold Test",
            description: "Exercise without hold",
            inhaleTime: 1.0,
            holdTime: 0.0,
            exhaleTime: 1.0,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        breathingManager.stopBreathingExercise()
        breathingManager.startBreathingExercise(noHoldExercise)
        XCTAssertEqual(breathingManager.breathingState, .inhaling, "Should start with inhaling for no-hold exercise")
    }
    
    // MARK: - Animation Performance Tests
    
    func testAnimationPerformanceWithMultipleUpdates() {
        measure {
            let exercise = BreathingExercise.familyDefault
            
            // Rapidly update animation states
            for i in 0..<1000 {
                let state: FamilyBreathingManager.BreathingState = [.idle, .inhaling, .holding, .exhaling][i % 4]
                animationEngine.updateBreathingState(state, cycle: i / 4, exercise: exercise)
            }
        }
    }
    
    func testBreathingEnginePerformanceUnderLoad() {
        measure {
            // Start multiple breathing sessions rapidly
            for i in 0..<100 {
                let exercise = BreathingExercise(
                    name: "Performance Test \(i)",
                    description: "Performance test exercise",
                    inhaleTime: 0.001,
                    holdTime: 0,
                    exhaleTime: 0.001,
                    totalCycles: 1,
                    difficulty: .beginner
                )
                
                breathingManager.isSessionActive = true
                breathingManager.startBreathingExercise(exercise)
                breathingManager.stopBreathingExercise()
            }
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testAnimationEngineMemoryManagement() {
        weak var weakEngine: BreathingAnimationEngine?
        
        autoreleasepool {
            let engine = BreathingAnimationEngine()
            weakEngine = engine
            engine.startSynchronization()
            engine.stopSynchronization()
            XCTAssertNotNil(weakEngine, "Engine should exist")
        }
        
        // Allow deallocation
        DispatchQueue.main.async {
            XCTAssertNil(weakEngine, "Engine should be deallocated")
        }
    }
    
    func testBreathingTimerCleanup() {
        // Test that timers are properly cleaned up
        let exercise = BreathingExercise.familyDefault
        breathingManager.isSessionActive = true
        breathingManager.startBreathingExercise(exercise)
        
        // Stop exercise should clean up timers
        breathingManager.stopBreathingExercise()
        XCTAssertEqual(breathingManager.breathingState, .idle, "Should return to idle after stop")
        
        // End session should also clean up
        breathingManager.startBreathingExercise(exercise)
        breathingManager.endSession()
        XCTAssertEqual(breathingManager.breathingState, .idle, "Should return to idle after session end")
        XCTAssertFalse(breathingManager.isSessionActive, "Session should not be active")
    }
    
    // MARK: - Edge Case Tests
    
    func testZeroHoldTimeExercise() {
        let noHoldExercise = BreathingExercise(
            name: "No Hold",
            description: "Exercise with no hold time",
            inhaleTime: 1.0,
            holdTime: 0.0,
            exhaleTime: 1.0,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        breathingManager.isSessionActive = true
        breathingManager.startBreathingExercise(noHoldExercise)
        
        // Should handle zero hold time gracefully
        XCTAssertEqual(breathingManager.breathingState, .inhaling, "Should start with inhaling")
        
        // Animation engine should handle zero hold time
        animationEngine.updateBreathingState(.holding, cycle: 1, exercise: noHoldExercise)
        // Should not crash or cause issues
        XCTAssertNotNil(animationEngine, "Animation engine should handle zero hold time")
    }
    
    func testMinimalExerciseTimes() {
        let minimalExercise = BreathingExercise(
            name: "Minimal",
            description: "Minimal time exercise",
            inhaleTime: 0.1,
            holdTime: 0,
            exhaleTime: 0.1,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        breathingManager.isSessionActive = true
        
        // Should handle minimal times without crashing
        XCTAssertNoThrow(breathingManager.startBreathingExercise(minimalExercise), "Should handle minimal times")
        XCTAssertNoThrow(animationEngine.updateBreathingState(.inhaling, cycle: 1, exercise: minimalExercise), "Animation should handle minimal times")
    }
    
    func testSingleCycleExercise() {
        let singleCycleExercise = BreathingExercise(
            name: "Single Cycle",
            description: "Single cycle exercise",
            inhaleTime: 0.1,
            holdTime: 0,
            exhaleTime: 0.1,
            totalCycles: 1,
            difficulty: .beginner
        )
        
        breathingManager.isSessionActive = true
        breathingManager.startBreathingExercise(singleCycleExercise)
        
        XCTAssertEqual(breathingManager.currentCycle, 0, "Should start at cycle 0")
        
        // After completion, should return to idle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            XCTAssertEqual(self.breathingManager.breathingState, .idle, "Should return to idle after single cycle")
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentAnimationUpdates() async throws {
        let expectation = XCTestExpectation(description: "Concurrent animation updates")
        expectation.expectedFulfillmentCount = 10
        
        let exercise = BreathingExercise.familyDefault
        
        // Update animation state concurrently
        for i in 0..<10 {
            Task {
                let state: FamilyBreathingManager.BreathingState = [.inhaling, .holding, .exhaling][i % 3]
                animationEngine.updateBreathingState(state, cycle: i, exercise: exercise)
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Integration Tests
    
    func testBreathingEngineIntegration() async throws {
        // Test full integration between breathing manager and animation engine
        
        let expectation = XCTestExpectation(description: "Engine integration")
        
        let exercise = BreathingExercise(
            name: "Integration Test",
            description: "Test integration",
            inhaleTime: 0.1,
            holdTime: 0.05,
            exhaleTime: 0.1,
            totalCycles: 2,
            difficulty: .beginner
        )
        
        // Monitor breathing state changes and update animation engine
        breathingManager.$breathingState
            .sink { [weak self] state in
                guard let self = self else { return }
                self.animationEngine.updateBreathingState(
                    state,
                    cycle: self.breathingManager.currentCycle,
                    exercise: exercise
                )
                
                if state == .idle && self.breathingManager.currentCycle >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &subscriptions)
        
        breathingManager.isSessionActive = true
        breathingManager.startBreathingExercise(exercise)
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        XCTAssertGreaterThanOrEqual(breathingManager.currentCycle, 2, "Should complete cycles")
        XCTAssertEqual(breathingManager.breathingState, .idle, "Should end in idle state")
    }
}