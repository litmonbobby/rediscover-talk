import SwiftUI

/// Glass morphism card component optimized for therapeutic breathing app
/// Features dynamic color transitions and visual depth effects
struct GlassMorphismCard<Content: View>: View {
    let content: Content
    let breathingState: FamilyBreathingManager.BreathingState
    let cornerRadius: CGFloat
    let blur: CGFloat
    let opacity: Double
    
    @State private var animationScale: CGFloat = 1.0
    @State private var backgroundOpacity: Double = 0.1
    
    init(
        breathingState: FamilyBreathingManager.BreathingState = .idle,
        cornerRadius: CGFloat = 16,
        blur: CGFloat = 20,
        opacity: Double = 0.8,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.breathingState = breathingState
        self.cornerRadius = cornerRadius
        self.blur = blur
        self.opacity = opacity
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                ZStack {
                    // Base glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            .regularMaterial,
                            style: FillStyle()
                        )
                    
                    // Therapeutic color overlay
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(therapeuticGradient)
                        .opacity(backgroundOpacity)
                        .animation(.easeInOut(duration: 1.5), value: breathingState)
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .scaleEffect(animationScale)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8),
                value: animationScale
            )
            .onChange(of: breathingState) { newState in
                updateForBreathingState(newState)
            }
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 10,
                x: 0,
                y: 5
            )
    }
    
    // MARK: - Therapeutic Color System
    
    private var therapeuticGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: therapeuticColors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var therapeuticColors: [Color] {
        switch breathingState {
        case .idle:
            return [
                Color.gray.opacity(0.3),
                Color(.systemGray5).opacity(0.2)
            ]
        case .inhaling:
            return [
                Color.blue.opacity(0.4),
                Color.cyan.opacity(0.2)
            ]
        case .holding:
            return [
                Color.purple.opacity(0.4),
                Color.indigo.opacity(0.3)
            ]
        case .exhaling:
            return [
                Color.green.opacity(0.4),
                Color.mint.opacity(0.2)
            ]
        }
    }
    
    // MARK: - State Animations
    
    private func updateForBreathingState(_ state: FamilyBreathingManager.BreathingState) {
        switch state {
        case .idle:
            animationScale = 1.0
            backgroundOpacity = 0.1
            
        case .inhaling:
            animationScale = 1.05
            backgroundOpacity = 0.3
            
        case .holding:
            animationScale = 1.05
            backgroundOpacity = 0.4
            
        case .exhaling:
            animationScale = 0.98
            backgroundOpacity = 0.2
        }
    }
}

// MARK: - Specialized Cards

struct ParticipantStatusCard: View {
    let participants: Set<Participant>
    let isSessionActive: Bool
    @Binding var showDetail: Bool
    
    var body: some View {
        GlassMorphismCard(
            breathingState: isSessionActive ? .holding : .idle,
            cornerRadius: 20
        ) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                    
                    Text("Family Members")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(participants.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                if isSessionActive {
                    HStack(spacing: 8) {
                        ForEach(Array(participants.prefix(4)), id: \.id) { participant in
                            ParticipantIndicator(participant: participant)
                        }
                        
                        if participants.count > 4 {
                            Text("+\(participants.count - 4)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("View All") {
                            showDetail = true
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
}

struct SessionControlsCard: View {
    let isSessionActive: Bool
    let breathingState: FamilyBreathingManager.BreathingState
    @Binding var selectedExercise: BreathingExercise
    let onStartSession: () -> Void
    let onStartBreathing: () -> Void
    
    var body: some View {
        GlassMorphismCard(
            breathingState: breathingState,
            cornerRadius: 20
        ) {
            VStack(spacing: 16) {
                if !isSessionActive {
                    Text("Start a family breathing session")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    Button(action: onStartSession) {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .font(.title3)
                            Text("Start Family Session")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.cyan]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .scaleEffect(breathingState == .idle ? 1.0 : 1.02)
                    .animation(.spring(response: 0.4), value: breathingState)
                } else {
                    ExerciseSelector(selectedExercise: $selectedExercise)
                    
                    HStack(spacing: 12) {
                        Button(action: onStartBreathing) {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                Text("Start Breathing")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                therapeuticButtonGradient
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(breathingState != .idle)
                        .opacity(breathingState != .idle ? 0.6 : 1.0)
                        
                        Button("Stop") {
                            // Implementation for stopping session
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var therapeuticButtonGradient: LinearGradient {
        switch breathingState {
        case .idle:
            return LinearGradient(
                gradient: Gradient(colors: [Color.green, Color.mint]),
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray, Color(.systemGray4)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

struct EncouragementCard: View {
    @Binding var text: String
    @Binding var showEncouragement: Bool
    let onSendEncouragement: () -> Void
    
    var body: some View {
        GlassMorphismCard(
            breathingState: .holding,
            cornerRadius: 20
        ) {
            VStack(spacing: 12) {
                HStack {
                    TextField("Send encouragement...", text: $text)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button(action: onSendEncouragement) {
                        Image(systemName: "paperplane.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                    .disabled(text.isEmpty)
                    .opacity(text.isEmpty ? 0.5 : 1.0)
                }
                
                if showEncouragement {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                        Text("Great breathing, everyone!")
                            .font(.callout)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ParticipantIndicator: View {
    let participant: Participant
    @State private var isConnected = true
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.8),
                            Color.mint.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            
            if isConnected {
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isConnected ? 1.0 : 0.8)
                    .animation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                        value: isConnected
                    )
            }
        }
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
    }
}

struct ExerciseSelector: View {
    @Binding var selectedExercise: BreathingExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Breathing Exercise")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedExercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(Int(selectedExercise.duration / 60)) min • \(selectedExercise.cycles) cycles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(selectedExercise.inhaleTime))s in • \(Int(selectedExercise.holdTime))s hold • \(Int(selectedExercise.exhaleTime))s out")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Change") {
                    // Implementation for exercise selection
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Preview

struct GlassMorphismCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            GlassMorphismCard(breathingState: .inhaling) {
                Text("Inhaling State")
                    .font(.headline)
            }
            
            GlassMorphismCard(breathingState: .holding) {
                Text("Holding State")
                    .font(.headline)
            }
            
            GlassMorphismCard(breathingState: .exhaling) {
                Text("Exhaling State")
                    .font(.headline)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}