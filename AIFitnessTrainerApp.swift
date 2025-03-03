import SwiftUI
import AVFoundation
import HealthKit

/// Main entry point for the AI Fitness Trainer Watch App
@main
struct AIFitnessTrainerApp: App {
    /// App delegate for handling app lifecycle events
    @StateObject private var appDelegate = AppDelegate()
    
    // Register the extension delegate
    @WKExtensionDelegateAdaptor(ExtensionDelegate.self) var extensionDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request permissions when the app starts
                    appDelegate.requestPermissions()
                }
        }
    }
}

/// App delegate for handling app lifecycle events
class AppDelegate: NSObject, ObservableObject {
    /// Requests necessary permissions for the app
    func requestPermissions() {
        // Request microphone permission
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            if granted {
                print("Microphone permission granted")
            } else {
                print("Microphone permission denied")
            }
        }
        
        // Request HealthKit permissions
        if HKHealthStore.isHealthDataAvailable() {
            let healthStore = HKHealthStore()
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            
            healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { success, error in
                if success {
                    print("HealthKit permission granted")
                } else {
                    print("HealthKit permission denied: \(String(describing: error))")
                }
            }
        }
    }
}

/// Main content view for the Watch App
struct ContentView: View {
    /// State for the selected exercise type
    @State private var selectedExercise: AppConstants.ExerciseType = .pushUp
    
    /// State for the selected session mode
    @State private var isMappingMode: Bool = true
    
    /// State for navigation
    @State private var isWorkoutActive: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // Exercise type picker
                Section(header: Text("Exercise Type")) {
                    Picker("Exercise", selection: $selectedExercise) {
                        ForEach(AppConstants.ExerciseType.allCases, id: \.self) { exercise in
                            Text(exercise.displayName).tag(exercise)
                        }
                    }
                }
                
                // Session type picker
                Section(header: Text("Session Type")) {
                    Toggle("Mapping Session", isOn: $isMappingMode)
                        .toggleStyle(SwitchToggleStyle())
                    
                    if isMappingMode {
                        Text("Count reps out loud during the workout")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                // Start workout button
                Section {
                    NavigationLink(
                        destination: WorkoutView(
                            exerciseType: selectedExercise,
                            isMappingSession: isMappingMode
                        ),
                        isActive: $isWorkoutActive
                    ) {
                        HStack {
                            Spacer()
                            Text("Start Workout")
                                .foregroundColor(.green)
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("AI Fitness Trainer")
        }
    }
} 