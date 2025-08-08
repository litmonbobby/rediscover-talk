import SwiftUI
import Combine
import QuartzCore

/// High-performance animation manager optimized for 60fps breathing animations
/// Implements frame rate monitoring, adaptive quality, and resource management
@MainActor
class AnimationPerformanceManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentFPS: Double = 60.0
    @Published var targetFPS: Double = 60.0
    @Published var animationQuality: AnimationQuality = .high
    @Published var performanceMetrics: PerformanceMetrics = PerformanceMetrics()
    @Published var isLowPowerMode: Bool = false
    
    // MARK: - Performance Models
    
    enum AnimationQuality: String, CaseIterable {
        case low = "Power Saver"
        case medium = "Balanced"
        case high = "High Quality"
        case maximum = "Maximum"
        
        var particleCount: Int {
            switch self {
            case .low: return 6
            case .medium: return 12
            case .high: return 18
            case .maximum: return 24
            }
        }
        
        var blurRadius: CGFloat {
            switch self {
            case .low: return 5
            case .medium: return 10
            case .high: return 20
            case .maximum: return 30
            }
        }
        
        var layerCount: Int {
            switch self {
            case .low: return 2
            case .medium: return 3
            case .high: return 4
            case .maximum: return 5
            }
        }
        
        var animationPrecision: TimeInterval {
            switch self {
            case .low: return 1.0 / 30.0  // 30fps
            case .medium: return 1.0 / 45.0  // 45fps
            case .high: return 1.0 / 60.0  // 60fps
            case .maximum: return 1.0 / 120.0  // 120fps (ProMotion)
            }
        }
    }
    
    struct PerformanceMetrics {
        var averageFPS: Double = 60.0
        var frameDrops: Int = 0
        var memoryUsage: Double = 0.0
        var cpuUsage: Double = 0.0
        var thermalState: ProcessInfo.ThermalState = .nominal
        var batteryLevel: Float = 1.0
        var isCharging: Bool = false
        
        var performanceScore: Double {
            let fpsScore = min(averageFPS / 60.0, 1.0) * 0.4
            let memoryScore = max(0, 1.0 - memoryUsage / 100.0) * 0.3
            let cpuScore = max(0, 1.0 - cpuUsage / 100.0) * 0.2
            let thermalScore = thermalMultiplier * 0.1
            
            return fpsScore + memoryScore + cpuScore + thermalScore
        }
        
        private var thermalMultiplier: Double {
            switch thermalState {
            case .nominal: return 1.0
            case .fair: return 0.8
            case .serious: return 0.6
            case .critical: return 0.4
            @unknown default: return 0.8
            }
        }
    }
    
    struct FrameRateHistory {
        private var samples: [Double] = []
        private let maxSamples = 60 // 1 second at 60fps
        
        mutating func addSample(_ fps: Double) {
            samples.append(fps)
            if samples.count > maxSamples {
                samples.removeFirst()
            }
        }
        
        var average: Double {
            guard !samples.isEmpty else { return 60.0 }
            return samples.reduce(0, +) / Double(samples.count)
        }
        
        var minimum: Double {
            samples.min() ?? 60.0
        }
        
        var stability: Double {
            guard samples.count > 1 else { return 1.0 }
            let variance = calculateVariance()
            return max(0, 1.0 - variance / 400.0) // Normalize variance
        }
        
        private func calculateVariance() -> Double {
            let mean = average
            let squaredDeviations = samples.map { pow($0 - mean, 2) }
            return squaredDeviations.reduce(0, +) / Double(squaredDeviations.count)
        }
    }
    
    // MARK: - Private State
    
    private var displayLink: CADisplayLink?
    private var frameRateHistory = FrameRateHistory()
    private var lastFrameTime: CFTimeInterval = 0
    private var adaptiveQualityEnabled = true
    private var performanceTimer: Timer?
    private var subscriptions = Set<AnyCancellable>()
    
    // Device capability detection
    private let deviceCapabilities = DeviceCapabilities()
    
    // Performance thresholds
    private let fpsThresholds = (
        excellent: 58.0,
        good: 45.0,
        poor: 30.0
    )
    
    // MARK: - Initialization
    
    init() {
        setupPerformanceMonitoring()
        detectDeviceCapabilities()
        startFrameRateMonitoring()
        
        // Monitor system state changes
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePowerState()
            }
            .store(in: &subscriptions)
        
        // Monitor thermal state
        NotificationCenter.default.publisher(for: .NSProcessInfoThermalStateDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &subscriptions)
    }
    
    deinit {
        stopFrameRateMonitoring()
        performanceTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    func startPerformanceMonitoring() {
        startFrameRateMonitoring()
        startPerformanceTracking()
    }
    
    func stopPerformanceMonitoring() {
        stopFrameRateMonitoring()
        performanceTimer?.invalidate()
    }
    
    func adaptQualityForPerformance() {
        guard adaptiveQualityEnabled else { return }
        
        let score = performanceMetrics.performanceScore
        let newQuality: AnimationQuality
        
        if score > 0.8 && !isLowPowerMode {
            newQuality = deviceCapabilities.supportsProMotion ? .maximum : .high
        } else if score > 0.6 {
            newQuality = .high
        } else if score > 0.4 {
            newQuality = .medium
        } else {
            newQuality = .low
        }
        
        if newQuality != animationQuality {
            print("🎯 Adapting animation quality to \(newQuality.rawValue) (score: \(String(format: "%.2f", score)))")
            animationQuality = newQuality
        }
    }
    
    func setAdaptiveQuality(enabled: Bool) {
        adaptiveQualityEnabled = enabled
    }
    
    func forceQuality(_ quality: AnimationQuality) {
        adaptiveQualityEnabled = false
        animationQuality = quality
    }
    
    func getOptimalAnimationTiming(for duration: TimeInterval) -> Animation {
        let precision = animationQuality.animationPrecision
        let steps = Int(duration / precision)
        
        return .timingCurve(0.4, 0.0, 0.2, 1.0, duration: duration)
            .speed(currentFPS / targetFPS) // Adjust for actual frame rate
    }
    
    func shouldReduceEffects() -> Bool {
        return performanceMetrics.performanceScore < 0.5 || isLowPowerMode
    }
    
    func getPerformanceBudget() -> PerformanceBudget {
        return PerformanceBudget(
            maxParticles: animationQuality.particleCount,
            maxLayers: animationQuality.layerCount,
            blurRadius: shouldReduceEffects() ? animationQuality.blurRadius * 0.5 : animationQuality.blurRadius,
            animationPrecision: animationQuality.animationPrecision,
            enableShadows: !shouldReduceEffects(),
            enableGradients: performanceMetrics.performanceScore > 0.6,
            enableParticles: performanceMetrics.performanceScore > 0.4
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupPerformanceMonitoring() {
        // Initialize performance metrics
        updateSystemMetrics()
    }
    
    private func detectDeviceCapabilities() {
        deviceCapabilities.detectCapabilities()
        
        // Set initial target FPS based on device
        if deviceCapabilities.supportsProMotion {
            targetFPS = 120.0
        } else {
            targetFPS = 60.0
        }
        
        // Set initial quality based on device performance tier
        switch deviceCapabilities.performanceTier {
        case .low:
            animationQuality = .medium
        case .medium:
            animationQuality = .high
        case .high:
            animationQuality = deviceCapabilities.supportsProMotion ? .maximum : .high
        }
    }
    
    private func startFrameRateMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.preferredFramesPerSecond = Int(targetFPS)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopFrameRateMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayLinkCallback(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        
        if lastFrameTime > 0 {
            let deltaTime = currentTime - lastFrameTime
            let fps = 1.0 / deltaTime
            
            // Update frame rate metrics
            frameRateHistory.addSample(fps)
            currentFPS = frameRateHistory.average
            
            // Track frame drops
            if fps < targetFPS * 0.9 { // 90% of target FPS
                performanceMetrics.frameDrops += 1
            }
        }
        
        lastFrameTime = currentTime
        
        // Update performance metrics periodically
        if Int(currentTime * 10) % 10 == 0 { // Every 1 second
            updatePerformanceMetrics()
        }
    }
    
    private func startPerformanceTracking() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSystemMetrics()
                self?.adaptQualityForPerformance()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        performanceMetrics.averageFPS = frameRateHistory.average
        
        // Reset frame drop counter periodically
        if Int(lastFrameTime) % 10 == 0 {
            performanceMetrics.frameDrops = 0
        }
    }
    
    private func updateSystemMetrics() {
        performanceMetrics.memoryUsage = getMemoryUsage()
        performanceMetrics.cpuUsage = getCPUUsage()
        performanceMetrics.thermalState = ProcessInfo.processInfo.thermalState
        performanceMetrics.batteryLevel = getBatteryLevel()
        performanceMetrics.isCharging = isDeviceCharging()
    }
    
    private func updatePowerState() {
        isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerMode {
            // Aggressively reduce quality in low power mode
            animationQuality = .low
            targetFPS = 30.0
        } else {
            // Restore based on performance
            adaptQualityForPerformance()
            targetFPS = deviceCapabilities.supportsProMotion ? 120.0 : 60.0
        }
        
        // Update display link
        displayLink?.preferredFramesPerSecond = Int(targetFPS)
    }
    
    private func updateThermalState() {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .serious, .critical:
            // Reduce quality to prevent overheating
            animationQuality = .low
            targetFPS = 30.0
        case .fair:
            animationQuality = .medium
            targetFPS = 45.0
        case .nominal:
            adaptQualityForPerformance()
            targetFPS = deviceCapabilities.supportsProMotion ? 120.0 : 60.0
        @unknown default:
            break
        }
        
        displayLink?.preferredFramesPerSecond = Int(targetFPS)
    }
    
    // MARK: - System Metrics
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMemoryMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            return (memoryUsageMB / totalMemoryMB) * 100.0
        }
        
        return 0.0
    }
    
    private func getCPUUsage() -> Double {
        var kr: kern_return_t
        var task_info_count: mach_msg_type_number_t
        
        task_info_count = mach_msg_type_number_t(TASK_INFO_MAX)
        var tinfo = [integer_t](repeating: 0, count: Int(task_info_count))
        
        kr = task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), &tinfo, &task_info_count)
        if kr != KERN_SUCCESS {
            return 0.0
        }
        
        var thread_list: thread_act_array_t? = UnsafeMutablePointer(mutating: [thread_act_t]())
        var thread_count: mach_msg_type_number_t = 0
        defer {
            if let thread_list = thread_list {
                vm_deallocate(mach_task_self_, vm_address_t(UnsafePointer(thread_list).pointee), vm_size_t(thread_count))
            }
        }
        
        kr = task_threads(mach_task_self_, &thread_list, &thread_count)
        
        if kr != KERN_SUCCESS {
            return 0.0
        }
        
        var tot_cpu: Double = 0
        
        if let thread_list = thread_list {
            for j in 0..<Int(thread_count) {
                var thread_info_count = mach_msg_type_number_t(THREAD_INFO_MAX)
                var thinfo = [integer_t](repeating: 0, count: Int(thread_info_count))
                kr = thread_info(thread_list[j], thread_flavor_t(THREAD_BASIC_INFO), &thinfo, &thread_info_count)
                if kr != KERN_SUCCESS {
                    return 0.0
                }
                
                let thread_basic_info = convertThreadInfoToThreadBasicInfo(thinfo)
                if thread_basic_info.flags & TH_FLAGS_IDLE == 0 {
                    tot_cpu += Double(thread_basic_info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
        }
        
        return tot_cpu
    }
    
    private func convertThreadInfoToThreadBasicInfo(_ threadInfo: [integer_t]) -> thread_basic_info {
        var result = thread_basic_info()
        
        result.user_time = time_value_t(seconds: threadInfo[0], microseconds: threadInfo[1])
        result.system_time = time_value_t(seconds: threadInfo[2], microseconds: threadInfo[3])
        result.cpu_usage = threadInfo[4]
        result.policy = threadInfo[5]
        result.run_state = threadInfo[6]
        result.flags = threadInfo[7]
        result.suspend_count = threadInfo[8]
        result.sleep_time = threadInfo[9]
        
        return result
    }
    
    private func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    private func isDeviceCharging() -> Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
    }
}

// MARK: - Supporting Types

struct PerformanceBudget {
    let maxParticles: Int
    let maxLayers: Int
    let blurRadius: CGFloat
    let animationPrecision: TimeInterval
    let enableShadows: Bool
    let enableGradients: Bool
    let enableParticles: Bool
}

class DeviceCapabilities {
    enum PerformanceTier {
        case low, medium, high
    }
    
    private(set) var supportsProMotion = false
    private(set) var performanceTier: PerformanceTier = .medium
    private(set) var maxMemoryMB: Int = 0
    private(set) var cpuCoreCount: Int = 0
    
    func detectCapabilities() {
        // Detect ProMotion support
        if let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback)) {
            displayLink.preferredFramesPerSecond = 120
            supportsProMotion = displayLink.preferredFramesPerSecond == 120
            displayLink.invalidate()
        }
        
        // Detect performance tier based on device model
        let deviceModel = UIDevice.current.model
        let processorInfo = ProcessInfo.processInfo
        
        maxMemoryMB = Int(processorInfo.physicalMemory / 1024 / 1024)
        cpuCoreCount = processorInfo.activeProcessorCount
        
        // Simple heuristic based on memory and CPU cores
        if maxMemoryMB >= 6144 && cpuCoreCount >= 6 { // 6GB+ RAM, 6+ cores
            performanceTier = .high
        } else if maxMemoryMB >= 3072 && cpuCoreCount >= 4 { // 3GB+ RAM, 4+ cores
            performanceTier = .medium
        } else {
            performanceTier = .low
        }
    }
    
    @objc private func displayLinkCallback() {
        // Empty callback for ProMotion detection
    }
}

// MARK: - SwiftUI Integration

extension View {
    func optimizedForPerformance(_ manager: AnimationPerformanceManager) -> some View {
        self.modifier(PerformanceOptimizedViewModifier(manager: manager))
    }
}

struct PerformanceOptimizedViewModifier: ViewModifier {
    @ObservedObject var manager: AnimationPerformanceManager
    
    func body(content: Content) -> some View {
        content
            .drawingGroup(opaque: !manager.shouldReduceEffects())
            .animation(
                manager.getOptimalAnimationTiming(for: 0.3),
                value: manager.animationQuality
            )
    }
}