import SwiftUI

/// Main view for the workout session on the Apple Watch
struct WorkoutView: View {
    // MARK: - Properties
    
    /// The type of exercise being performed
    let exerciseType: AppConstants.ExerciseType
    
    /// Flag indicating if this is a mapping session
    let isMappingSession: Bool
    
    /// State for the current rep count
    @State private var repCount: Int = 0
    
    /// State for the workout timer
    @State private var elapsedTime: TimeInterval = 0
    
    /// Timer for updating the elapsed time
    @State private var timer: Timer? = nil
    
    /// State for the workout status
    @State private var isWorkoutActive: Bool = false
    
    /// State for the countdown before starting
    @State private var countdownValue: Int = 3
    
    /// State for showing the countdown
    @State private var isCountingDown: Bool = false
    
    /// State for showing feedback that collection has started
    @State private var showStartedFeedback: Bool = false
    
    /// Reference to the data collector service
    private let dataCollector = DataCollectorService.shared
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 10) {
                // Exercise type and session type
                Text(exerciseType.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(isMappingSession ? "Mapping Session" : "Workout Session")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Rep counter
                Text("\(repCount)")
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                
                Text("REPS")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Timer
                Text(timeString(from: elapsedTime))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Start/Stop button
                Button(action: isWorkoutActive ? stopWorkout : startCountdown) {
                    Text(isWorkoutActive ? "Stop" : "Start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isWorkoutActive ? .red : .green)
                .disabled(isCountingDown)
            }
            .padding()
            .opacity(isCountingDown ? 0.3 : 1.0)
            
            // Countdown overlay
            if isCountingDown {
                Text("\(countdownValue)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .transition(.scale)
            }
            
            // Started feedback overlay
            if showStartedFeedback {
                Text("Data Collection Started!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.8))
                    )
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: isCountingDown)
        .animation(.easeInOut, value: showStartedFeedback)
        .onAppear {
            setupCallbacks()
        }
        .onDisappear {
            // Make sure to stop the workout if the view disappears
            if isWorkoutActive {
                stopWorkout()
            }
        }
    }
    
    // MARK: - Methods
    
    /// Sets up callbacks from the data collector
    private func setupCallbacks() {
        dataCollector.onDataCollectionStarted = {
            // Show started feedback briefly
            showStartedFeedback = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showStartedFeedback = false
            }
        }
    }
    
    /// Starts the countdown before beginning the workout
    private func startCountdown() {
        // Reset countdown
        countdownValue = 3
        isCountingDown = true
        
        // Create a timer for the countdown
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownValue > 1 {
                countdownValue -= 1
            } else {
                // Countdown finished, start the workout
                timer.invalidate()
                isCountingDown = false
                startWorkout()
            }
        }
    }
    
    /// Starts the workout and data collection
    private func startWorkout() {
        // Reset counters
        repCount = 0
        elapsedTime = 0
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsedTime += 0.1
        }
        
        // Start data collection
        if isMappingSession {
            dataCollector.startMappingSession()
        } else {
            dataCollector.startNormalSession()
        }
        
        // Update state
        isWorkoutActive = true
    }
    
    /// Stops the workout and data collection
    private func stopWorkout() {
        // Stop the timer
        timer?.invalidate()
        timer = nil
        
        // Stop data collection
        dataCollector.stopSession()
        
        // Update state
        isWorkoutActive = false
    }
    
    /// Formats a time interval as a string
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let tenths = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 10)
        
        return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
    }
}

// MARK: - Preview

struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutView(
            exerciseType: .pushUp,
            isMappingSession: true
        )
    }
} 