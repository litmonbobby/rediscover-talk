//
//  AnimationPerformanceTests.swift
//  RediscoverTalk Unit Tests
//
//  Created by Claude on 2025-08-07.
//  Comprehensive animation performance and memory testing
//

import XCTest
import SwiftUI
import Combine
@testable import RediscoverTalk

class AnimationPerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    var animationEngine: BreathingAnimationEngine!
    var familyBreathingManager: FamilyBreathingManager!
    var animationPerformanceManager: AnimationPerformanceManager!
    var subscriptions: Set<AnyCancellable>!
    
    // Performance metrics
    var frameRateSamples: [Double] = []
    var memoryUsageSamples: [Double] = []
    var cpuUsageSamples: [Double] = []
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        animationEngine = BreathingAnimationEngine()
        familyBreathingManager = FamilyBreathingManager()
        animationPerformanceManager = AnimationPerformanceManager()
        subscriptions = Set<AnyCancellable>()
        
        frameRateSamples.removeAll()
        memoryUsageSamples.removeAll()
        cpuUsageSamples.removeAll()
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        animationEngine?.stopSynchronization()
        animationEngine = nil
        familyBreathingManager = nil
        animationPerformanceManager = nil
        subscriptions.removeAll()
        subscriptions = nil
        
        frameRateSamples.removeAll()
        memoryUsageSamples.removeAll()
        cpuUsageSamples.removeAll()
        
        try await super.tearDown()
    }
    
    // MARK: - 60fps Animation Tests
    
    func test60FPSAnimationConsistency() async throws {
        let expectation = XCTestExpectation(description: "60fps animation consistency")
        
        var frameCount = 0
        let targetFrameCount = 600 // 10 seconds at 60fps
        let startTime = Date()
        
        // Start animation synchronization
        animationEngine.startSynchronization()
        
        // Monitor frame updates
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            frameCount += 1
            
            // Update animation state to trigger frame rendering
            let state: FamilyBreathingManager.BreathingState = frameCount % 4 == 0 ? .inhaling : .exhaling
            self.animationEngine.updateBreathingState(
                state,
                cycle: frameCount / 60,
                exercise: BreathingExercise.familyDefault
            )
            
            if frameCount >= targetFrameCount {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
        
        let endTime = Date()
        let actualDuration = endTime.timeIntervalSince(startTime)
        let expectedDuration = Double(targetFrameCount) / 60.0
        
        timer.invalidate()
        animationEngine.stopSynchronization()
        
        // Verify timing accuracy (allow 5% tolerance)
        let timingAccuracy = abs(actualDuration - expectedDuration) / expectedDuration
        XCTAssertLessThan(timingAccuracy, 0.05, "Animation timing should be within 5% of target")
        
        XCTAssertGreaterThanOrEqual(frameCount, targetFrameCount, "Should complete target frame count")
    }
    
    func testAnimationFrameDropDetection() {
        let expectation = XCTestExpectation(description: "Frame drop detection")
        
        var frameTimestamps: [Date] = []
        let maxFrames = 300 // 5 seconds at 60fps
        
        animationEngine.startSynchronization()
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            frameTimestamps.append(Date())
            
            // Simulate frame rendering
            self.animationEngine.updateBreathingState(
                .inhaling,
                cycle: frameTimestamps.count / 60,
                exercise: BreathingExercise.familyDefault
            )
            
            if frameTimestamps.count >= maxFrames {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        timer.invalidate()
        animationEngine.stopSynchronization()
        
        // Analyze frame timing
        var frameDrops = 0
        let targetFrameTime = 1.0 / 60.0 // 16.67ms
        
        for i in 1..<frameTimestamps.count {
            let frameTime = frameTimestamps[i].timeIntervalSince(frameTimestamps[i-1])
            if frameTime > targetFrameTime * 1.5 { // 150% of target time indicates dropped frame
                frameDrops += 1
            }
        }
        
        let frameDropRate = Double(frameDrops) / Double(frameTimestamps.count)
        XCTAssertLessThan(frameDropRate, 0.05, "Frame drop rate should be less than 5%")
    }
    
    // MARK: - Memory Performance Tests
    
    func testAnimationMemoryUsage() {
        let initialMemory = getMemoryUsage()
        
        // Start intensive animation
        animationEngine.startSynchronization()
        
        // Run animation for extended period
        let expectation = XCTestExpectation(description: "Memory usage monitoring")
        var sampleCount = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Update animation state frequently
            let state: FamilyBreathingManager.BreathingState = [.inhaling, .holding, .exhaling].randomElement()!
            self.animationEngine.updateBreathingState(
                state,
                cycle: sampleCount / 10,
                exercise: BreathingExercise.familyDefault
            )
            
            let currentMemory = self.getMemoryUsage()
            self.memoryUsageSamples.append(currentMemory)
            
            sampleCount += 1
            if sampleCount >= 100 { // 10 seconds of samples
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 15.0)
        timer.invalidate()
        animationEngine.stopSynchronization()
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Memory increase should be reasonable (less than 10MB)
        XCTAssertLessThan(memoryIncrease, 10.0 * 1024 * 1024, "Memory increase should be less than 10MB")
        
        // Check for memory leaks
        let maxMemory = memoryUsageSamples.max() ?? 0
        let avgMemory = memoryUsageSamples.reduce(0, +) / Double(memoryUsageSamples.count)
        
        XCTAssertLessThan(maxMemory - avgMemory, avgMemory * 0.2, "Memory spikes should be within 20% of average")
    }
    
    func testMemoryLeakDetection() {
        weak var weakEngine: BreathingAnimationEngine?
        
        // Test multiple creation and destruction cycles
        for _ in 0..<10 {
            autoreleasepool {
                let engine = BreathingAnimationEngine()
                weakEngine = engine
                
                engine.startSynchronization()
                
                // Simulate animation activity
                for j in 0..<100 {
                    let state: FamilyBreathingManager.BreathingState = [.inhaling, .exhaling][j % 2]
                    engine.updateBreathingState(state, cycle: j, exercise: BreathingExercise.familyDefault)
                }
                
                engine.stopSynchronization()
            }
        }
        
        // Force garbage collection
        DispatchQueue.main.async {
            XCTAssertNil(weakEngine, "Animation engine should be deallocated")
        }
    }
    
    // MARK: - CPU Performance Tests
    
    func testCPUUsageUnderLoad() async throws {
        let expectation = XCTestExpectation(description: "CPU usage monitoring")
        
        let initialCPU = getCPUUsage()
        var cpuSamples: [Double] = []
        
        // Start multiple animation engines to simulate load
        let engines = (0..<5).map { _ in BreathingAnimationEngine() }
        engines.forEach { $0.startSynchronization() }
        
        var sampleCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Update all engines
            for engine in engines {
                let state: FamilyBreathingManager.BreathingState = [.inhaling, .holding, .exhaling].randomElement()!
                engine.updateBreathingState(state, cycle: sampleCount, exercise: BreathingExercise.familyDefault)
            }
            
            let currentCPU = self.getCPUUsage()
            cpuSamples.append(currentCPU)
            
            sampleCount += 1
            if sampleCount >= 50 { // 5 seconds of samples
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        timer.invalidate()
        
        engines.forEach { $0.stopSynchronization() }
        
        let avgCPU = cpuSamples.reduce(0, +) / Double(cpuSamples.count)
        let maxCPU = cpuSamples.max() ?? 0
        
        // CPU usage should be reasonable
        XCTAssertLessThan(avgCPU, 30.0, "Average CPU usage should be less than 30%")
        XCTAssertLessThan(maxCPU, 50.0, "Maximum CPU usage should be less than 50%")
    }
    
    // MARK: - Animation Smoothness Tests
    
    func testAnimationSmoothness() async throws {
        let expectation = XCTestExpectation(description: "Animation smoothness")
        
        animationEngine.startSynchronization()
        
        var scaleValues: [CGFloat] = []
        var opacityValues: [Double] = []
        
        // Monitor animation property changes
        animationEngine.$currentScale
            .sink { scale in
                scaleValues.append(scale)
            }
            .store(in: &subscriptions)
        
        animationEngine.$currentOpacity
            .sink { opacity in
                opacityValues.append(opacity)
            }
            .store(in: &subscriptions)
        
        // Simulate breathing cycle
        let exercise = BreathingExercise.familyDefault
        let states: [FamilyBreathingManager.BreathingState] = [.inhaling, .holding, .exhaling, .idle]
        
        var stateIndex = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let state = states[stateIndex % states.count]
            self.animationEngine.updateBreathingState(state, cycle: stateIndex / 4, exercise: exercise)
            
            stateIndex += 1
            if stateIndex >= 20 { // 5 complete cycles
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
        timer.invalidate()
        animationEngine.stopSynchronization()
        
        // Analyze smoothness
        XCTAssertGreaterThan(scaleValues.count, 10, "Should have multiple scale updates")
        XCTAssertGreaterThan(opacityValues.count, 10, "Should have multiple opacity updates")
        
        // Check for extreme jumps in values (indicating jerky animation)
        for i in 1..<scaleValues.count {
            let scaleDiff = abs(scaleValues[i] - scaleValues[i-1])
            XCTAssertLessThan(scaleDiff, 0.5, "Scale changes should be smooth")
        }
        
        for i in 1..<opacityValues.count {
            let opacityDiff = abs(opacityValues[i] - opacityValues[i-1])
            XCTAssertLessThan(opacityDiff, 0.3, "Opacity changes should be smooth")
        }
    }
    
    // MARK: - Performance Benchmarks
    
    func testAnimationUpdatePerformance() {
        measure {
            let exercise = BreathingExercise.familyDefault
            
            for i in 0..<1000 {
                let state: FamilyBreathingManager.BreathingState = [.inhaling, .holding, .exhaling, .idle][i % 4]
                animationEngine.updateBreathingState(state, cycle: i / 4, exercise: exercise)
            }
        }
    }
    
    func testSynchronizationOverhead() {
        measure {
            for _ in 0..<100 {
                animationEngine.startSynchronization()
                animationEngine.stopSynchronization()
            }
        }
    }
    
    func testBatchAnimationUpdates() {
        measure {
            let exercise = BreathingExercise.familyDefault
            
            // Batch 100 updates
            for batch in 0..<10 {
                for i in 0..<100 {
                    let state: FamilyBreathingManager.BreathingState = [.inhaling, .exhaling][i % 2]
                    animationEngine.updateBreathingState(state, cycle: batch * 100 + i, exercise: exercise)
                }
            }
        }
    }
    
    // MARK: - Battery Usage Tests
    
    func testBatteryEfficiency() async throws {
        // Note: Actual battery measurement requires device testing
        // This test focuses on computational efficiency as a proxy
        
        let startTime = Date()
        let initialEnergy = getEnergyUsage()
        
        animationEngine.startSynchronization()
        
        // Run animation for a fixed period
        let expectation = XCTestExpectation(description: "Battery efficiency test")
        
        var updateCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in // 30fps for efficiency
            let state: FamilyBreathingManager.BreathingState = [.inhaling, .exhaling][updateCount % 2]
            self.animationEngine.updateBreathingState(
                state,
                cycle: updateCount / 30,
                exercise: BreathingExercise.familyDefault
            )
            
            updateCount += 1
            if updateCount >= 900 { // 30 seconds at 30fps
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 35.0)
        timer.invalidate()
        animationEngine.stopSynchronization()
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let finalEnergy = getEnergyUsage()
        
        let energyPerSecond = (finalEnergy - initialEnergy) / duration
        
        // Energy usage should be reasonable (implementation specific)
        XCTAssertLessThan(energyPerSecond, 1000.0, "Energy usage per second should be reasonable")
    }
    
    // MARK: - Stress Tests
    
    func testHighFrequencyUpdates() async throws {
        let expectation = XCTestExpectation(description: "High frequency updates")
        
        animationEngine.startSynchronization()
        
        var updateCount = 0
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/120.0, repeats: true) { _ in // 120 updates per second
            let state: FamilyBreathingManager.BreathingState = [.inhaling, .holding, .exhaling][updateCount % 3]
            self.animationEngine.updateBreathingState(
                state,
                cycle: updateCount / 120,
                exercise: BreathingExercise.familyDefault
            )
            
            updateCount += 1
            if updateCount >= 1200 { // 10 seconds at 120fps
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
        timer.invalidate()
        animationEngine.stopSynchronization()
        
        XCTAssertGreaterThanOrEqual(updateCount, 1200, "Should handle high frequency updates")
    }
    
    func testConcurrentAnimationEngines() async throws {
        let expectation = XCTestExpectation(description: "Concurrent animation engines")
        expectation.expectedFulfillmentCount = 10
        
        // Create multiple animation engines running concurrently
        for i in 0..<10 {
            Task {
                let engine = BreathingAnimationEngine()
                engine.startSynchronization()
                
                for j in 0..<100 {
                    let state: FamilyBreathingManager.BreathingState = [.inhaling, .exhaling][j % 2]
                    engine.updateBreathingState(state, cycle: j, exercise: BreathingExercise.familyDefault)
                    
                    try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                }
                
                engine.stopSynchronization()
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 20.0)
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Double {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(taskInfo.resident_size)
        }
        
        return 0
    }
    
    private func getCPUUsage() -> Double {
        var threadsList: thread_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        
        let threadsResult = withUnsafeMutablePointer(to: &threadsList) {
            return $0.withMemoryRebound(to: thread_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadsCount)
            }
        }
        
        guard threadsResult == KERN_SUCCESS else { return 0 }
        
        var totalCPU: Double = 0
        
        if let threadsList = threadsList {
            for j in 0..<threadsCount {
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                var threadInfo = thread_basic_info()
                
                let threadInfoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    return $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[Int(j)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                guard threadInfoResult == KERN_SUCCESS else { continue }
                
                if threadInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalCPU += (Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE)) * 100.0
                }
            }
            
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }
        
        return totalCPU
    }
    
    private func getEnergyUsage() -> Double {
        // Placeholder for energy usage measurement
        // In real implementation, this would use system APIs or profiling tools
        return Double(getCPUUsage() * 10) // Approximation based on CPU usage
    }
}