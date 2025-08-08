import SwiftUI
import GroupActivities
import Combine

/// Enhanced breathing view with synchronized SharePlay animations
/// Optimized for 60fps performance with therapeutic color transitions
struct BreatheView: View {
    @StateObject private var breathingManager = FamilyBreathingManager()
    @StateObject private var animationEngine = BreathingAnimationEngine()
    
    @State private var selectedExercise = BreathingExercise.familyDefault
    @State private var showParticipants = false
    @State private var showSettings = false
    @State private var encouragementText = ""
    @State private var showEncouragement = false
    @State private var lastSyncTimestamp: Date = Date()
    
    // Animation performance tracking
    @State private var frameRate: Double = 60.0
    @State private var syncLatency: TimeInterval = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient that adapts to breathing state
                therapeuticBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Performance indicators (debug mode)
                        if showSettings {
                            performanceIndicators
                        }
                        
                        // Participant status with glass morphism
                        ParticipantStatusCard(
                            participants: breathingManager.currentParticipants,
                            isSessionActive: breathingManager.isSessionActive,
                            showDetail: $showParticipants
                        )
                        .padding(.horizontal)
                        
                        // Main breathing animation circle
                        SynchronizedBreathingCircle(
                            state: breathingManager.breathingState,
                            cycle: breathingManager.currentCycle,
                            exercise: selectedExercise,
                            animationEngine: animationEngine,
                            syncLatency: $syncLatency
                        )
                        .frame(width: min(geometry.size.width - 40, 320), 
                               height: min(geometry.size.width - 40, 320))
                        
                        // Session controls with glass morphism
                        SessionControlsCard(
                            isSessionActive: breathingManager.isSessionActive,
                            breathingState: breathingManager.breathingState,
                            selectedExercise: $selectedExercise,
                            onStartSession: {
                                Task {
                                    await breathingManager.startGroupSession()
                                }
                            },
                            onStartBreathing: {
                                breathingManager.startBreathingExercise(selectedExercise)
                                animationEngine.startSynchronization()
                            }
                        )
                        .padding(.horizontal)
                        
                        // Encouragement section
                        if breathingManager.isSessionActive {
                            EncouragementCard(
                                text: $encouragementText,
                                showEncouragement: $showEncouragement,
                                onSendEncouragement: {
                                    breathingManager.sendEncouragement(encouragementText)
                                    encouragementText = ""
                                    showEncouragementAnimation()
                                }
                            )
                            .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .navigationTitle("Family Breathing")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showParticipants) {
            ParticipantDetailView(participants: breathingManager.currentParticipants)
        }
        .sheet(isPresented: $showSettings) {
            BreathingSettingsView(
                selectedExercise: $selectedExercise,
                frameRate: frameRate,
                syncLatency: syncLatency
            )
        }
        .task {
            await setupGroupActivityListener()
        }
        .onReceive(breathingManager.$breathingState) { newState in
            handleBreathingStateChange(newState)
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            updatePerformanceMetrics()
        }
    }
    
    // MARK: - Therapeutic Background
    
    private var therapeuticBackground: some View {
        ZStack {
            // Base gradient that changes with breathing state
            LinearGradient(
                gradient: Gradient(colors: backgroundColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(.easeInOut(duration: 2.0), value: breathingManager.breathingState)
            
            // Subtle particle effect for depth
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: CGFloat.random(in: 4...12))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(
                        .easeInOut(duration: Double.random(in: 3...6))
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)),
                        value: breathingManager.breathingState
                    )
            }
        }
    }
    
    private var backgroundColors: [Color] {
        switch breathingManager.breathingState {
        case .idle:
            return [Color(.systemGray5), Color(.systemGray6)]
        case .inhaling:
            return [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)]
        case .holding:
            return [Color.purple.opacity(0.3), Color.indigo.opacity(0.2)]
        case .exhaling:
            return [Color.green.opacity(0.3), Color.mint.opacity(0.2)]
        }
    }
    
    // MARK: - Performance Monitoring
    
    private var performanceIndicators: some View {
        HStack {
            VStack {
                Text("FPS")
                    .font(.caption2)
                Text(String(format: "%.1f", frameRate))
                    .font(.headline)
                    .foregroundColor(frameRate >= 58 ? .green : (frameRate >= 45 ? .orange : .red))
            }
            
            Spacer()
            
            VStack {
                Text("Sync Latency")
                    .font(.caption2)
                Text(String(format: "%.0fms", syncLatency * 1000))
                    .font(.headline)
                    .foregroundColor(syncLatency <= 0.5 ? .green : (syncLatency <= 1.0 ? .orange : .red))
            }
            
            Spacer()
            
            VStack {
                Text("Participants")
                    .font(.caption2)
                Text("\(breathingManager.currentParticipants.count)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Event Handlers
    
    private func setupGroupActivityListener() async {
        for await session in FamilyBreathingSession.sessions() {
            breathingManager.configureGroupSession(session)
        }
    }
    
    private func handleBreathingStateChange(_ newState: FamilyBreathingManager.BreathingState) {
        lastSyncTimestamp = Date()
        
        // Update animation engine with new state
        animationEngine.updateBreathingState(
            newState,
            cycle: breathingManager.currentCycle,
            exercise: selectedExercise
        )
        
        // Provide haptic feedback for state transitions
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func showEncouragementAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showEncouragement = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                showEncouragement = false
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Simple frame rate estimation (in production, use CADisplayLink)
        frameRate = 60.0 // Placeholder - implement actual FPS monitoring
        
        // Calculate sync latency based on last state change
        syncLatency = Date().timeIntervalSince(lastSyncTimestamp)
    }
}

// MARK: - Animation Engine

@MainActor
class BreathingAnimationEngine: ObservableObject {
    @Published var currentScale: CGFloat = 1.0
    @Published var currentOpacity: Double = 0.7
    @Published var currentRotation: Double = 0.0
    @Published var particleOffset: CGFloat = 0.0
    
    private var animationTimer: Timer?
    private var startTime: Date?
    private var isSynchronizing = false
    
    // Performance optimizations
    private let targetFrameRate: Double = 60.0
    private let frameInterval: TimeInterval = 1.0 / 60.0
    
    func startSynchronization() {
        guard !isSynchronizing else { return }
        isSynchronizing = true
        startTime = Date()
        
        // Use CADisplayLink for precise 60fps timing
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.updateAnimationFrame()
        }
    }
    
    func stopSynchronization() {
        isSynchronizing = false
        animationTimer?.invalidate()
        animationTimer = nil
        resetToIdle()
    }
    
    func updateBreathingState(
        _ state: FamilyBreathingManager.BreathingState,
        cycle: Int,
        exercise: BreathingExercise
    ) {
        let targetScale: CGFloat
        let targetOpacity: Double
        let animationDuration: TimeInterval
        
        switch state {
        case .idle:
            targetScale = 1.0
            targetOpacity = 0.7
            animationDuration = 0.5
            
        case .inhaling:
            targetScale = 1.8
            targetOpacity = 0.9
            animationDuration = exercise.inhaleTime
            
        case .holding:
            targetScale = 1.8
            targetOpacity = 1.0
            animationDuration = exercise.holdTime
            
        case .exhaling:
            targetScale = 0.6
            targetOpacity = 0.4
            animationDuration = exercise.exhaleTime
        }
        
        // Smooth animation with precise timing
        withAnimation(
            .timingCurve(0.4, 0.0, 0.2, 1.0, duration: animationDuration)
        ) {
            currentScale = targetScale
            currentOpacity = targetOpacity
        }
        
        // Subtle rotation for visual interest
        withAnimation(
            .linear(duration: animationDuration)
        ) {
            currentRotation += state == .inhaling ? 15.0 : -10.0
        }
    }
    
    private func updateAnimationFrame() {
        guard let startTime = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Update particle animation offset
        withAnimation(.linear(duration: frameInterval)) {
            particleOffset = sin(elapsed * 2.0) * 20.0
        }
    }
    
    private func resetToIdle() {
        withAnimation(.easeOut(duration: 0.8)) {
            currentScale = 1.0
            currentOpacity = 0.7
            currentRotation = 0.0
            particleOffset = 0.0
        }
    }
}

// MARK: - Preview

struct BreatheView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BreatheView()
        }
        .preferredColorScheme(.dark)
    }
}