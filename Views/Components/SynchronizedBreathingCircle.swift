import SwiftUI
import Combine

/// High-performance synchronized breathing circle optimized for 60fps
/// Implements therapeutic color transitions with SharePlay synchronization
struct SynchronizedBreathingCircle: View {
    let state: FamilyBreathingManager.BreathingState
    let cycle: Int
    let exercise: BreathingExercise
    let animationEngine: BreathingAnimationEngine
    @Binding var syncLatency: TimeInterval
    
    @State private var breathingProgress: Double = 0.0
    @State private var pulseIntensity: Double = 0.0
    @State private var particleOpacity: Double = 0.0
    @State private var lastStateChange: Date = Date()
    
    // Performance optimization states
    @State private var animationPhase: AnimationPhase = .idle
    @State private var renderCache: [String: AnyView] = [:]
    
    enum AnimationPhase {
        case idle, inhaling, holding, exhaling, transitioning
    }
    
    var body: some View {
        ZStack {
            // Background blur circle for depth
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            therapeuticColor.opacity(0.1)
                        ]),
                        center: .center,
                        startRadius: 100,
                        endRadius: 200
                    )
                )
                .scaleEffect(animationEngine.currentScale * 1.2)
                .opacity(0.3)
                .blur(radius: 20)
            
            // Main breathing circle with particles
            ZStack {
                // Particle layer for visual richness
                ForEach(0..<12, id: \.self) { index in
                    BreathingParticle(
                        index: index,
                        state: state,
                        progress: breathingProgress,
                        intensity: pulseIntensity,
                        color: therapeuticColor,
                        offset: animationEngine.particleOffset
                    )
                }
                .opacity(particleOpacity)
                
                // Core breathing circle
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: therapeuticGradient,
                            center: .center,
                            startRadius: 20,
                            endRadius: 120
                        )
                    )
                    .scaleEffect(animationEngine.currentScale)
                    .opacity(animationEngine.currentOpacity)
                    .rotationEffect(.degrees(animationEngine.currentRotation))
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                
                // Inner state indicator
                StateIndicatorView(
                    state: state,
                    cycle: cycle,
                    exercise: exercise,
                    progress: breathingProgress
                )
            }
            .scaleEffect(calculateSyncAdjustment())
            
            // Progress ring
            Circle()
                .trim(from: 0, to: breathingProgress)
                .stroke(
                    therapeuticColor.opacity(0.6),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(animationEngine.currentScale * 1.1)
                .animation(.linear(duration: 0.1), value: breathingProgress)
        }
        .animation(
            .timingCurve(0.4, 0.0, 0.2, 1.0, duration: currentAnimationDuration),
            value: animationEngine.currentScale
        )
        .animation(
            .easeInOut(duration: currentAnimationDuration),
            value: animationEngine.currentOpacity
        )
        .onChange(of: state) { newState in
            handleStateChange(newState)
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            updateBreathingProgress()
            updateParticleEffects()
        }
    }
    
    // MARK: - Therapeutic Color System
    
    private var therapeuticColor: Color {
        switch state {
        case .idle: return Color(.systemGray2)
        case .inhaling: return Color.blue
        case .holding: return Color.purple
        case .exhaling: return Color.green
        }
    }
    
    private var therapeuticGradient: Gradient {
        switch state {
        case .idle:
            return Gradient(colors: [
                Color(.systemGray3),
                Color(.systemGray5),
                Color(.systemGray6)
            ])
        case .inhaling:
            return Gradient(colors: [
                Color.cyan.opacity(0.9),
                Color.blue,
                Color.indigo.opacity(0.8)
            ])
        case .holding:
            return Gradient(colors: [
                Color.purple.opacity(0.9),
                Color.indigo,
                Color.blue.opacity(0.8)
            ])
        case .exhaling:
            return Gradient(colors: [
                Color.mint.opacity(0.9),
                Color.green,
                Color.teal.opacity(0.8)
            ])
        }
    }
    
    // MARK: - Animation Logic
    
    private var currentAnimationDuration: TimeInterval {
        switch state {
        case .idle: return 0.8
        case .inhaling: return exercise.inhaleTime
        case .holding: return exercise.holdTime
        case .exhaling: return exercise.exhaleTime
        }
    }
    
    private func calculateSyncAdjustment() -> CGFloat {
        // Adjust scale based on synchronization latency
        let latencyAdjustment = min(syncLatency * 0.1, 0.05)
        return 1.0 + CGFloat(latencyAdjustment)
    }
    
    private func handleStateChange(_ newState: FamilyBreathingManager.BreathingState) {
        lastStateChange = Date()
        animationPhase = .transitioning
        
        // Update sync latency calculation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            syncLatency = Date().timeIntervalSince(lastStateChange)
        }
        
        // Update particle effects based on state
        withAnimation(.easeInOut(duration: 0.5)) {
            particleOpacity = newState == .idle ? 0.0 : 0.8
        }
        
        // Trigger haptic feedback for state transitions
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Update animation phase after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            animationPhase = getAnimationPhase(for: newState)
        }
    }
    
    private func getAnimationPhase(for state: FamilyBreathingManager.BreathingState) -> AnimationPhase {
        switch state {
        case .idle: return .idle
        case .inhaling: return .inhaling
        case .holding: return .holding
        case .exhaling: return .exhaling
        }
    }
    
    private func updateBreathingProgress() {
        let totalCycleTime = exercise.inhaleTime + exercise.holdTime + exercise.exhaleTime
        let totalSessionTime = Double(exercise.cycles) * totalCycleTime
        let currentCycleTime = Double(cycle) * totalCycleTime
        
        // Calculate overall progress
        breathingProgress = min(currentCycleTime / totalSessionTime, 1.0)
        
        // Update pulse intensity based on breathing state
        switch state {
        case .idle:
            pulseIntensity = 0.2
        case .inhaling:
            pulseIntensity = 0.8
        case .holding:
            pulseIntensity = 1.0
        case .exhaling:
            pulseIntensity = 0.4
        }
    }
    
    private func updateParticleEffects() {
        // Smooth particle animation updates for 60fps performance
        if state != .idle {
            let time = Date().timeIntervalSince(lastStateChange)
            let normalizedTime = time / currentAnimationDuration
            
            // Create breathing-like particle movement
            let breathingWave = sin(normalizedTime * .pi * 2) * 0.5 + 0.5
            withAnimation(.linear(duration: 0.016)) {
                particleOpacity = 0.6 + breathingWave * 0.3
            }
        }
    }
}

// MARK: - Supporting Views

struct BreathingParticle: View {
    let index: Int
    let state: FamilyBreathingManager.BreathingState
    let progress: Double
    let intensity: Double
    let color: Color
    let offset: CGFloat
    
    @State private var particleScale: CGFloat = 1.0
    @State private var particleOffset: CGSize = .zero
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.6),
                        color.opacity(0.2),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 10
                )
            )
            .frame(width: particleSize, height: particleSize)
            .scaleEffect(particleScale)
            .offset(particleOffset)
            .position(particlePosition)
            .animation(
                .easeInOut(duration: animationDuration)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1),
                value: state
            )
            .onAppear {
                updateParticleAnimation()
            }
            .onChange(of: state) { _ in
                updateParticleAnimation()
            }
    }
    
    private var particleSize: CGFloat {
        return 4.0 + CGFloat(intensity) * 8.0
    }
    
    private var particlePosition: CGPoint {
        let angle = Double(index) * (2.0 * .pi / 12.0)
        let radius = 80.0 + offset * 0.5
        
        return CGPoint(
            x: cos(angle) * radius,
            y: sin(angle) * radius
        )
    }
    
    private var animationDuration: TimeInterval {
        switch state {
        case .idle: return 2.0
        case .inhaling: return 4.0
        case .holding: return 6.0
        case .exhaling: return 6.0
        }
    }
    
    private func updateParticleAnimation() {
        let targetScale: CGFloat = state == .idle ? 0.5 : (1.0 + CGFloat(intensity) * 0.5)
        let targetOffset = CGSize(
            width: CGFloat.random(in: -5...5),
            height: CGFloat.random(in: -5...5)
        )
        
        withAnimation(.easeInOut(duration: animationDuration)) {
            particleScale = targetScale
            particleOffset = targetOffset
        }
    }
}

struct StateIndicatorView: View {
    let state: FamilyBreathingManager.BreathingState
    let cycle: Int
    let exercise: BreathingExercise
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            // Cycle counter
            Text("Cycle \(cycle + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
            
            // State text with therapeutic messaging
            Text(stateText)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Breathing instruction
            Text(instructionText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 120)
            
            // Mini progress indicator
            if state != .idle {
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 40, height: 2)
                    .cornerRadius(1)
                    .overlay(
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: CGFloat(progress) * 40, height: 2)
                            .cornerRadius(1),
                        alignment: .leading
                    )
            }
        }
    }
    
    private var stateText: String {
        switch state {
        case .idle: return "Ready"
        case .inhaling: return "Breathe In"
        case .holding: return "Hold"
        case .exhaling: return "Breathe Out"
        }
    }
    
    private var instructionText: String {
        switch state {
        case .idle: return "Tap to begin together"
        case .inhaling: return "Fill your lungs slowly and deeply"
        case .holding: return "Hold gently, find your center"
        case .exhaling: return "Release completely, let go"
        }
    }
}

// MARK: - Settings View

struct BreathingSettingsView: View {
    @Binding var selectedExercise: BreathingExercise
    let frameRate: Double
    let syncLatency: TimeInterval
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Performance Metrics") {
                    HStack {
                        Text("Frame Rate")
                        Spacer()
                        Text(String(format: "%.1f fps", frameRate))
                            .foregroundColor(frameRate >= 58 ? .green : .orange)
                    }
                    
                    HStack {
                        Text("Sync Latency")
                        Spacer()
                        Text(String(format: "%.0f ms", syncLatency * 1000))
                            .foregroundColor(syncLatency <= 500 ? .green : .orange)
                    }
                }
                
                Section("Breathing Exercise") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedExercise.name)
                            .font(.headline)
                        
                        HStack {
                            Text("Duration:")
                            Spacer()
                            Text("\(Int(selectedExercise.duration / 60)) minutes")
                        }
                        
                        HStack {
                            Text("Cycles:")
                            Spacer()
                            Text("\(selectedExercise.cycles)")
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Breathing Pattern:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Inhale: \(Int(selectedExercise.inhaleTime))s")
                            Text("Hold: \(Int(selectedExercise.holdTime))s")
                            Text("Exhale: \(Int(selectedExercise.exhaleTime))s")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Section("Therapeutic Colors") {
                    VStack(alignment: .leading, spacing: 12) {
                        ColorIndicator(color: .blue, label: "Inhaling - Calming blue promotes relaxation")
                        ColorIndicator(color: .purple, label: "Holding - Purple enhances focus and mindfulness")
                        ColorIndicator(color: .green, label: "Exhaling - Green provides refreshing release")
                        ColorIndicator(color: .gray, label: "Idle - Neutral gray for preparation")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ColorIndicator: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct SynchronizedBreathingCircle_Previews: PreviewProvider {
    static var previews: some View {
        let animationEngine = BreathingAnimationEngine()
        
        SynchronizedBreathingCircle(
            state: .inhaling,
            cycle: 2,
            exercise: BreathingExercise.familyDefault,
            animationEngine: animationEngine,
            syncLatency: .constant(0.2)
        )
        .frame(width: 300, height: 300)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            animationEngine.startSynchronization()
        }
    }
}