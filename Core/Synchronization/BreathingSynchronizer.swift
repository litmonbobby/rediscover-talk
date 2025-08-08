import Foundation
import Combine
import GroupActivities

/// Advanced breathing synchronization engine with predictive timing and latency compensation
/// Optimized for <500ms sync latency and 60fps performance across devices
@MainActor
class BreathingSynchronizer: ObservableObject {
    
    // MARK: - Published State
    
    @Published var synchronizedState: SynchronizedBreathingState = .idle
    @Published var networkLatency: TimeInterval = 0.0
    @Published var syncQuality: SyncQuality = .excellent
    @Published var predictedStateChange: Date?
    
    // MARK: - Synchronization Models
    
    struct SynchronizedBreathingState {
        let state: FamilyBreathingManager.BreathingState
        let cycle: Int
        let timestamp: Date
        let exerciseStartTime: Date?
        let participantID: String
        
        static let idle = SynchronizedBreathingState(
            state: .idle,
            cycle: 0,
            timestamp: Date(),
            exerciseStartTime: nil,
            participantID: ""
        )
    }
    
    enum SyncQuality: String, CaseIterable {
        case excellent = "Excellent" // <100ms latency
        case good = "Good"          // 100-300ms latency
        case acceptable = "Acceptable" // 300-500ms latency
        case poor = "Poor"          // >500ms latency
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .acceptable: return "orange"
            case .poor: return "red"
            }
        }
    }
    
    struct NetworkMetrics {
        let roundTripTime: TimeInterval
        let jitter: TimeInterval
        let packetLoss: Double
        let lastMeasurement: Date
        
        var quality: SyncQuality {
            if roundTripTime < 0.1 && jitter < 0.05 && packetLoss < 0.01 {
                return .excellent
            } else if roundTripTime < 0.3 && jitter < 0.1 && packetLoss < 0.05 {
                return .good
            } else if roundTripTime < 0.5 && jitter < 0.2 && packetLoss < 0.1 {
                return .acceptable
            } else {
                return .poor
            }
        }
    }
    
    // MARK: - Private State
    
    private var exercise: BreathingExercise?
    private var sessionStartTime: Date?
    private var localClockOffset: TimeInterval = 0.0
    private var networkMetrics: NetworkMetrics?
    private var stateHistory: [SynchronizedBreathingState] = []
    private var predictionAlgorithm: StatePredictionAlgorithm
    private var synchronizationTimer: Timer?
    private var messenger: GroupSessionMessenger?
    
    // Performance optimization
    private let maxHistorySize = 50
    private let syncInterval: TimeInterval = 0.1 // 10Hz for smooth synchronization
    private let predictionWindow: TimeInterval = 0.5 // 500ms prediction window
    
    // MARK: - Initialization
    
    init() {
        self.predictionAlgorithm = StatePredictionAlgorithm()
        startSynchronizationLoop()
    }
    
    deinit {
        synchronizationTimer?.invalidate()
    }
    
    // MARK: - Public Interface
    
    func configure(with messenger: GroupSessionMessenger, exercise: BreathingExercise) {
        self.messenger = messenger
        self.exercise = exercise
        
        // Subscribe to incoming synchronization messages
        messenger.messages(of: SyncMessage.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleIncomingSyncMessage(message)
            }
            .store(in: &subscriptions)
    }
    
    func startSession(with exercise: BreathingExercise) {
        self.exercise = exercise
        self.sessionStartTime = Date()
        
        // Initialize clock synchronization
        initializeClockSynchronization()
        
        // Start prediction algorithm
        predictionAlgorithm.initialize(with: exercise)
        
        // Begin synchronization
        startSynchronizationLoop()
        
        // Broadcast session start
        broadcastSyncMessage(.sessionStart(exercise: exercise, timestamp: Date()))
    }
    
    func updateBreathingState(
        _ state: FamilyBreathingManager.BreathingState,
        cycle: Int,
        isLocalUpdate: Bool = false
    ) {
        let currentTime = Date()
        let synchronizedState = SynchronizedBreathingState(
            state: state,
            cycle: cycle,
            timestamp: currentTime,
            exerciseStartTime: sessionStartTime,
            participantID: UIDevice.current.identifierForVendor?.uuidString ?? ""
        )
        
        // Update local state
        self.synchronizedState = synchronizedState
        
        // Add to history for prediction
        addToHistory(synchronizedState)
        
        // Broadcast if this is a local update
        if isLocalUpdate {
            broadcastSyncMessage(.stateChange(synchronizedState))
        }
        
        // Update prediction
        updateStatePrediction()
    }
    
    func getCompensatedTimestamp(for timestamp: Date) -> Date {
        // Apply network latency compensation
        let compensation = networkLatency * 0.5 // Assume symmetric latency
        return timestamp.addingTimeInterval(-compensation)
    }
    
    func getCurrentSyncLatency() -> TimeInterval {
        return networkLatency
    }
    
    // MARK: - Private Implementation
    
    private var subscriptions = Set<AnyCancellable>()
    
    private enum SyncMessage: Codable {
        case stateChange(SynchronizedBreathingState)
        case sessionStart(exercise: BreathingExercise, timestamp: Date)
        case clockSync(timestamp: Date, respondTo: String?)
        case heartbeat(timestamp: Date, participantID: String)
        case networkMetrics(metrics: NetworkMetrics)
    }
    
    private func handleIncomingSyncMessage(_ message: SyncMessage) {
        let receiveTime = Date()
        
        switch message {
        case .stateChange(let remoteState):
            handleRemoteStateChange(remoteState, receiveTime: receiveTime)
            
        case .sessionStart(let exercise, let timestamp):
            handleRemoteSessionStart(exercise, startTime: timestamp, receiveTime: receiveTime)
            
        case .clockSync(let timestamp, let respondTo):
            handleClockSyncMessage(timestamp, respondTo: respondTo, receiveTime: receiveTime)
            
        case .heartbeat(let timestamp, let participantID):
            handleHeartbeat(timestamp, participantID: participantID, receiveTime: receiveTime)
            
        case .networkMetrics(let metrics):
            handleNetworkMetrics(metrics)
        }
    }
    
    private func handleRemoteStateChange(_ remoteState: SynchronizedBreathingState, receiveTime: Date) {
        // Calculate network latency
        let latency = receiveTime.timeIntervalSince(remoteState.timestamp)
        updateNetworkLatency(latency)
        
        // Apply temporal compensation
        let compensatedState = applyTemporalCompensation(to: remoteState, latency: latency)
        
        // Conflict resolution - use most recent state
        if compensatedState.timestamp > synchronizedState.timestamp {
            // Smooth transition to avoid jarring changes
            let transitionDuration = min(latency, 0.3) // Max 300ms transition
            
            DispatchQueue.main.asyncAfter(deadline: .now() + transitionDuration) {
                self.synchronizedState = compensatedState
                self.addToHistory(compensatedState)
                self.updateStatePrediction()
            }
        }
    }
    
    private func applyTemporalCompensation(
        to state: SynchronizedBreathingState,
        latency: TimeInterval
    ) -> SynchronizedBreathingState {
        guard let exercise = exercise,
              let startTime = state.exerciseStartTime else {
            return state
        }
        
        // Calculate what the state should be now, accounting for latency
        let compensatedTime = state.timestamp.addingTimeInterval(latency)
        let elapsed = compensatedTime.timeIntervalSince(startTime)
        
        let predictedState = predictionAlgorithm.predictState(
            at: elapsed,
            exercise: exercise
        )
        
        return SynchronizedBreathingState(
            state: predictedState.state,
            cycle: predictedState.cycle,
            timestamp: compensatedTime,
            exerciseStartTime: startTime,
            participantID: state.participantID
        )
    }
    
    private func handleRemoteSessionStart(_ exercise: BreathingExercise, startTime: Date, receiveTime: Date) {
        let latency = receiveTime.timeIntervalSince(startTime)
        let compensatedStartTime = startTime.addingTimeInterval(-latency)
        
        self.exercise = exercise
        self.sessionStartTime = compensatedStartTime
        
        // Synchronize local session with remote start time
        predictionAlgorithm.initialize(with: exercise, startTime: compensatedStartTime)
    }
    
    private func handleClockSyncMessage(_ timestamp: Date, respondTo: String?, receiveTime: Date) {
        if let respondTo = respondTo {
            // This is a response to our sync request
            let roundTripTime = receiveTime.timeIntervalSince(timestamp)
            let offset = (receiveTime.timeIntervalSince(timestamp)) / 2.0
            
            localClockOffset = offset
            updateNetworkLatency(roundTripTime / 2.0)
        } else {
            // This is a sync request, respond with our timestamp
            let participantID = UIDevice.current.identifierForVendor?.uuidString ?? ""
            broadcastSyncMessage(.clockSync(timestamp: Date(), respondTo: participantID))
        }
    }
    
    private func handleHeartbeat(_ timestamp: Date, participantID: String, receiveTime: Date) {
        let latency = receiveTime.timeIntervalSince(timestamp)
        updateNetworkLatency(latency)
    }
    
    private func handleNetworkMetrics(_ metrics: NetworkMetrics) {
        networkMetrics = metrics
        syncQuality = metrics.quality
    }
    
    private func updateNetworkLatency(_ newLatency: TimeInterval) {
        // Exponential moving average for smooth latency tracking
        let alpha = 0.3
        networkLatency = networkLatency * (1 - alpha) + newLatency * alpha
        
        // Update sync quality
        syncQuality = calculateSyncQuality()
    }
    
    private func calculateSyncQuality() -> SyncQuality {
        if networkLatency < 0.1 {
            return .excellent
        } else if networkLatency < 0.3 {
            return .good
        } else if networkLatency < 0.5 {
            return .acceptable
        } else {
            return .poor
        }
    }
    
    private func addToHistory(_ state: SynchronizedBreathingState) {
        stateHistory.append(state)
        
        // Maintain history size limit
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst(stateHistory.count - maxHistorySize)
        }
    }
    
    private func updateStatePrediction() {
        guard let exercise = exercise,
              let sessionStart = sessionStartTime else {
            return
        }
        
        let currentTime = Date()
        let predictedTime = currentTime.addingTimeInterval(predictionWindow)
        let elapsed = predictedTime.timeIntervalSince(sessionStart)
        
        let prediction = predictionAlgorithm.predictState(at: elapsed, exercise: exercise)
        
        // Set predicted state change time
        if prediction.state != synchronizedState.state {
            predictedStateChange = predictedTime
        }
    }
    
    private func initializeClockSynchronization() {
        // Send initial clock sync message
        broadcastSyncMessage(.clockSync(timestamp: Date(), respondTo: nil))
    }
    
    private func startSynchronizationLoop() {
        synchronizationTimer?.invalidate()
        
        synchronizationTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performSynchronizationTick()
            }
        }
    }
    
    private func performSynchronizationTick() {
        // Send periodic heartbeat
        let participantID = UIDevice.current.identifierForVendor?.uuidString ?? ""
        broadcastSyncMessage(.heartbeat(timestamp: Date(), participantID: participantID))
        
        // Update predictions
        updateStatePrediction()
        
        // Check for network quality degradation
        if networkLatency > 1.0 {
            // Implement fallback mechanisms
            activateFallbackMode()
        }
    }
    
    private func activateFallbackMode() {
        // Fallback to local timing with best-effort synchronization
        print("⚠️ Activating fallback mode due to poor network conditions")
        
        // Reduce sync frequency to conserve bandwidth
        synchronizationTimer?.invalidate()
        synchronizationTimer = Timer.scheduledTimer(withTimeInterval: syncInterval * 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performSynchronizationTick()
            }
        }
    }
    
    private func broadcastSyncMessage(_ message: SyncMessage) {
        guard let messenger = messenger else { return }
        
        Task {
            do {
                try await messenger.send(message)
            } catch {
                print("Failed to send sync message: \(error)")
            }
        }
    }
}

// MARK: - State Prediction Algorithm

class StatePredictionAlgorithm {
    private var exercise: BreathingExercise?
    private var sessionStartTime: Date?
    
    struct PredictedState {
        let state: FamilyBreathingManager.BreathingState
        let cycle: Int
        let confidence: Double // 0.0 - 1.0
    }
    
    func initialize(with exercise: BreathingExercise, startTime: Date = Date()) {
        self.exercise = exercise
        self.sessionStartTime = startTime
    }
    
    func predictState(at elapsedTime: TimeInterval, exercise: BreathingExercise) -> PredictedState {
        let cycleTime = exercise.inhaleTime + exercise.holdTime + exercise.exhaleTime
        let currentCycleTime = elapsedTime.truncatingRemainder(dividingBy: cycleTime)
        let cycleNumber = Int(elapsedTime / cycleTime)
        
        let state: FamilyBreathingManager.BreathingState
        let confidence: Double
        
        if currentCycleTime < exercise.inhaleTime {
            state = .inhaling
            confidence = 0.9 // High confidence during inhale
        } else if currentCycleTime < exercise.inhaleTime + exercise.holdTime {
            state = .holding
            confidence = 0.95 // Highest confidence during hold
        } else {
            state = .exhaling
            confidence = 0.85 // Good confidence during exhale
        }
        
        return PredictedState(
            state: state,
            cycle: cycleNumber,
            confidence: confidence
        )
    }
    
    func getStateTransitionTime(
        from currentState: FamilyBreathingManager.BreathingState,
        at elapsedTime: TimeInterval,
        exercise: BreathingExercise
    ) -> TimeInterval? {
        let cycleTime = exercise.inhaleTime + exercise.holdTime + exercise.exhaleTime
        let currentCycleTime = elapsedTime.truncatingRemainder(dividingBy: cycleTime)
        
        switch currentState {
        case .inhaling:
            return exercise.inhaleTime - currentCycleTime
        case .holding:
            return exercise.inhaleTime + exercise.holdTime - currentCycleTime
        case .exhaling:
            return cycleTime - currentCycleTime
        case .idle:
            return nil
        }
    }
}

// MARK: - Extensions

extension BreathingSynchronizer.SynchronizedBreathingState: Codable, Equatable {
    static func == (lhs: BreathingSynchronizer.SynchronizedBreathingState, rhs: BreathingSynchronizer.SynchronizedBreathingState) -> Bool {
        return lhs.state == rhs.state &&
               lhs.cycle == rhs.cycle &&
               lhs.participantID == rhs.participantID &&
               abs(lhs.timestamp.timeIntervalSince(rhs.timestamp)) < 0.1
    }
}

extension BreathingSynchronizer.NetworkMetrics: Codable {}

// MARK: - Performance Monitoring Extension

extension BreathingSynchronizer {
    
    struct SyncPerformanceMetrics {
        let averageLatency: TimeInterval
        let latencyVariance: TimeInterval
        let successRate: Double
        let packetLoss: Double
        let syncAccuracy: Double // How often we predict state changes correctly
    }
    
    func getPerformanceMetrics() -> SyncPerformanceMetrics {
        // Calculate performance metrics from history
        let recentHistory = stateHistory.suffix(20)
        
        let latencies = recentHistory.compactMap { state in
            Date().timeIntervalSince(state.timestamp)
        }
        
        let averageLatency = latencies.reduce(0, +) / Double(latencies.count)
        let latencyVariance = calculateVariance(latencies)
        
        return SyncPerformanceMetrics(
            averageLatency: averageLatency,
            latencyVariance: latencyVariance,
            successRate: 0.95, // Placeholder - implement actual success tracking
            packetLoss: networkMetrics?.packetLoss ?? 0.0,
            syncAccuracy: 0.9 // Placeholder - implement prediction accuracy tracking
        )
    }
    
    private func calculateVariance(_ values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDeviations = values.map { pow($0 - mean, 2) }
        return squaredDeviations.reduce(0, +) / Double(squaredDeviations.count)
    }
}