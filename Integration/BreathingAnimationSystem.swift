import SwiftUI
import GroupActivities
import Combine

/// Complete integrated breathing animation system with SharePlay synchronization
/// Demonstrates the full implementation of therapeutic animations with 60fps performance
struct BreathingAnimationSystem: View {
    
    // MARK: - Core Managers
    
    @StateObject private var breathingManager = FamilyBreathingManager()
    @StateObject private var synchronizer = BreathingSynchronizer()
    @StateObject private var performanceManager = AnimationPerformanceManager()
    @StateObject private var animationEngine = BreathingAnimationEngine()
    
    // MARK: - State
    
    @State private var selectedExercise = BreathingExercise.familyDefault
    @State private var showPerformanceMetrics = false
    @State private var showSyncDetails = false
    @State private var isSessionActive = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // Therapeutic background with performance optimization
                    TherapeuticBackground(
                        state: breathingManager.breathingState,
                        performanceBudget: performanceManager.getPerformanceBudget()
                    )
                    .ignoresSafeArea()
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // Performance & Sync Status (Development/Debug)
                            if showPerformanceMetrics || showSyncDetails {
                                SystemStatusView(
                                    performanceManager: performanceManager,
                                    synchronizer: synchronizer,
                                    showPerformance: showPerformanceMetrics,
                                    showSync: showSyncDetails
                                )
                            }
                            
                            // Main Breathing Interface
                            VStack(spacing: 20) {
                                // Participant Status
                                ParticipantStatusCard(
                                    participants: breathingManager.currentParticipants,
                                    isSessionActive: breathingManager.isSessionActive,
                                    showDetail: .constant(false)
                                )
                                .padding(.horizontal)
                                
                                // Synchronized Breathing Animation
                                SynchronizedBreathingCircle(
                                    state: breathingManager.breathingState,
                                    cycle: breathingManager.currentCycle,
                                    exercise: selectedExercise,
                                    animationEngine: animationEngine,
                                    syncLatency: .constant(synchronizer.getCurrentSyncLatency())
                                )
                                .frame(
                                    width: min(geometry.size.width - 40, 320),
                                    height: min(geometry.size.width - 40, 320)
                                )
                                .optimizedForPerformance(performanceManager)
                                
                                // Session Controls
                                BreathingControlsView(
                                    breathingManager: breathingManager,
                                    selectedExercise: $selectedExercise,
                                    animationEngine: animationEngine,
                                    synchronizer: synchronizer,
                                    onSessionStart: { exercise in
                                        startIntegratedSession(with: exercise)
                                    }
                                )
                                .padding(.horizontal)
                                
                                // Real-time Metrics (Optional)
                                if isSessionActive {
                                    SessionMetricsView(
                                        synchronizer: synchronizer,
                                        performanceManager: performanceManager
                                    )
                                    .padding(.horizontal)
                                }
                            }
                            
                            Spacer(minLength: 100)
                        }
                    }
                }
            }
            .navigationTitle("Family Breathing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Performance Metrics") {
                            showPerformanceMetrics.toggle()
                        }
                        
                        Button("Sync Details") {
                            showSyncDetails.toggle()
                        }
                        
                        Divider()
                        
                        Button("Force High Quality") {
                            performanceManager.forceQuality(.high)
                        }
                        
                        Button("Enable Adaptive Quality") {
                            performanceManager.setAdaptiveQuality(enabled: true)
                        }
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .task {
                await setupIntegratedSystem()
            }
            .onReceive(breathingManager.$breathingState) { newState in
                handleBreathingStateChange(newState)
            }
            .onReceive(breathingManager.$isSessionActive) { active in
                isSessionActive = active
                if active {
                    performanceManager.startPerformanceMonitoring()
                } else {
                    performanceManager.stopPerformanceMonitoring()
                    animationEngine.stopSynchronization()
                }
            }
        }
    }
    
    // MARK: - Integration Logic
    
    private func setupIntegratedSystem() async {
        // Initialize performance monitoring
        performanceManager.startPerformanceMonitoring()
        
        // Setup GroupActivity listener
        for await session in FamilyBreathingSession.sessions() {
            await configureIntegratedSession(session)
        }
    }
    
    private func configureIntegratedSession(_ session: GroupSession<FamilyBreathingSession>) async {
        // Configure breathing manager
        breathingManager.configureGroupSession(session)
        
        // Configure synchronizer with messenger
        if let messenger = session.messenger {
            synchronizer.configure(with: messenger, exercise: selectedExercise)
        }
        
        // Start synchronized timing
        animationEngine.startSynchronization()
    }
    
    private func startIntegratedSession(with exercise: BreathingExercise) {
        Task {
            // Start SharePlay session
            await breathingManager.startGroupSession()
            
            // Configure synchronizer
            synchronizer.startSession(with: exercise)
            
            // Start breathing exercise
            breathingManager.startBreathingExercise(exercise)
            
            // Start synchronized animations
            animationEngine.startSynchronization()
        }
    }
    
    private func handleBreathingStateChange(_ newState: FamilyBreathingManager.BreathingState) {
        // Update synchronizer
        synchronizer.updateBreathingState(
            newState,
            cycle: breathingManager.currentCycle,
            isLocalUpdate: true
        )
        
        // Update animation engine
        animationEngine.updateBreathingState(
            newState,
            cycle: breathingManager.currentCycle,
            exercise: selectedExercise
        )
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Supporting Views

struct TherapeuticBackground: View {
    let state: FamilyBreathingManager.BreathingState
    let performanceBudget: PerformanceBudget
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: therapeuticGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .animation(.easeInOut(duration: 2.0), value: state)
            
            // Performance-aware particle effects
            if performanceBudget.enableParticles {
                ForEach(0..<performanceBudget.maxParticles, id: \.self) { index in
                    BackgroundParticle(
                        index: index,
                        state: state,
                        enableShadows: performanceBudget.enableShadows
                    )
                }
            }
        }
    }
    
    private var therapeuticGradient: Gradient {
        switch state {
        case .idle:
            return Gradient(colors: [
                Color(.systemGray5).opacity(0.3),
                Color(.systemGray6).opacity(0.2)
            ])
        case .inhaling:
            return Gradient(colors: [
                Color.blue.opacity(0.4),
                Color.cyan.opacity(0.2)
            ])
        case .holding:
            return Gradient(colors: [
                Color.purple.opacity(0.4),
                Color.indigo.opacity(0.3)
            ])
        case .exhaling:
            return Gradient(colors: [
                Color.green.opacity(0.4),
                Color.mint.opacity(0.2)
            ])
        }
    }
}

struct BackgroundParticle: View {
    let index: Int
    let state: FamilyBreathingManager.BreathingState
    let enableShadows: Bool
    
    @State private var position: CGPoint = .zero
    @State private var opacity: Double = 0.1
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: CGFloat.random(in: 4...12))
            .scaleEffect(scale)
            .position(position)
            .shadow(
                color: enableShadows ? Color.white.opacity(0.3) : Color.clear,
                radius: 4
            )
            .onAppear {
                setupRandomPosition()
                startAnimation()
            }
            .onChange(of: state) { _ in
                updateForBreathingState()
            }
    }
    
    private func setupRandomPosition() {
        position = CGPoint(
            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
        )
    }
    
    private func startAnimation() {
        let duration = Double.random(in: 3...6)
        let delay = Double.random(in: 0...2)
        
        withAnimation(
            .easeInOut(duration: duration)
            .repeatForever(autoreverses: true)
            .delay(delay)
        ) {
            opacity = Double.random(in: 0.2...0.4)
            scale = CGFloat.random(in: 0.8...1.2)
        }
    }
    
    private func updateForBreathingState() {
        let targetOpacity: Double
        let targetScale: CGFloat
        
        switch state {
        case .idle:
            targetOpacity = 0.1
            targetScale = 1.0
        case .inhaling:
            targetOpacity = 0.3
            targetScale = 1.2
        case .holding:
            targetOpacity = 0.4
            targetScale = 1.1
        case .exhaling:
            targetOpacity = 0.2
            targetScale = 0.9
        }
        
        withAnimation(.easeInOut(duration: 1.5)) {
            opacity = targetOpacity
            scale = targetScale
        }
    }
}

struct SystemStatusView: View {
    @ObservedObject var performanceManager: AnimationPerformanceManager
    @ObservedObject var synchronizer: BreathingSynchronizer
    let showPerformance: Bool
    let showSync: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if showPerformance {
                PerformanceStatusCard(manager: performanceManager)
            }
            
            if showSync {
                SynchronizationStatusCard(synchronizer: synchronizer)
            }
        }
        .padding(.horizontal)
    }
}

struct PerformanceStatusCard: View {
    @ObservedObject var manager: AnimationPerformanceManager
    
    var body: some View {
        GlassMorphismCard(
            breathingState: .idle,
            cornerRadius: 16
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.blue)
                    Text("Performance")
                        .font(.headline)
                    Spacer()
                    Text(manager.animationQuality.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("FPS")
                            .font(.caption2)
                        Text(String(format: "%.1f", manager.currentFPS))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(fpsColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Score")
                            .font(.caption2)
                        Text(String(format: "%.0f%%", manager.performanceMetrics.performanceScore * 100))
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Thermal")
                            .font(.caption2)
                        Text(thermalStateText)
                            .font(.caption)
                            .foregroundColor(thermalColor)
                    }
                }
            }
        }
    }
    
    private var fpsColor: Color {
        if manager.currentFPS >= 58 {
            return .green
        } else if manager.currentFPS >= 45 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var thermalStateText: String {
        switch manager.performanceMetrics.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Fair"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    private var thermalColor: Color {
        switch manager.performanceMetrics.thermalState {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }
}

struct SynchronizationStatusCard: View {
    @ObservedObject var synchronizer: BreathingSynchronizer
    
    var body: some View {
        GlassMorphismCard(
            breathingState: .idle,
            cornerRadius: 16
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .foregroundColor(.purple)
                    Text("Synchronization")
                        .font(.headline)
                    Spacer()
                    Text(synchronizer.syncQuality.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(syncQualityColor.opacity(0.2))
                        .cornerRadius(8)
                }
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Latency")
                            .font(.caption2)
                        Text(String(format: "%.0fms", synchronizer.networkLatency * 1000))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(latencyColor)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("State")
                            .font(.caption2)
                        Text(synchronizer.synchronizedState.state.rawValue.capitalized)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text("Cycle")
                            .font(.caption2)
                        Text("\(synchronizer.synchronizedState.cycle + 1)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var syncQualityColor: Color {
        switch synchronizer.syncQuality {
        case .excellent: return .green
        case .good: return .blue
        case .acceptable: return .orange
        case .poor: return .red
        }
    }
    
    private var latencyColor: Color {
        let latencyMs = synchronizer.networkLatency * 1000
        if latencyMs < 100 {
            return .green
        } else if latencyMs < 300 {
            return .orange
        } else {
            return .red
        }
    }
}

struct BreathingControlsView: View {
    @ObservedObject var breathingManager: FamilyBreathingManager
    @Binding var selectedExercise: BreathingExercise
    let animationEngine: BreathingAnimationEngine
    let synchronizer: BreathingSynchronizer
    let onSessionStart: (BreathingExercise) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if !breathingManager.isSessionActive {
                Button(action: {
                    onSessionStart(selectedExercise)
                }) {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .font(.title3)
                        Text("Start Family Session")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.cyan]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
            } else {
                GlassMorphismCard(
                    breathingState: breathingManager.breathingState,
                    cornerRadius: 16
                ) {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedExercise.name)
                                    .font(.headline)
                                Text("\(selectedExercise.cycles) cycles • \(Int(selectedExercise.duration / 60)) min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if breathingManager.breathingState == .idle {
                                Button("Start") {
                                    breathingManager.startBreathingExercise(selectedExercise)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SessionMetricsView: View {
    @ObservedObject var synchronizer: BreathingSynchronizer
    @ObservedObject var performanceManager: AnimationPerformanceManager
    
    var body: some View {
        GlassMorphismCard(
            breathingState: .holding,
            cornerRadius: 16
        ) {
            VStack(spacing: 8) {
                Text("Session Metrics")
                    .font(.headline)
                
                HStack {
                    MetricItem(
                        title: "Sync Quality",
                        value: synchronizer.syncQuality.rawValue,
                        color: .purple
                    )
                    
                    Spacer()
                    
                    MetricItem(
                        title: "Animation FPS",
                        value: String(format: "%.0f", performanceManager.currentFPS),
                        color: .blue
                    )
                    
                    Spacer()
                    
                    MetricItem(
                        title: "Network Latency",
                        value: String(format: "%.0fms", synchronizer.networkLatency * 1000),
                        color: .orange
                    )
                }
            }
        }
    }
}

struct MetricItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview

struct BreathingAnimationSystem_Previews: PreviewProvider {
    static var previews: some View {
        BreathingAnimationSystem()
            .preferredColorScheme(.dark)
    }
}