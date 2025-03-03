import Foundation

/// Constants used throughout the app
enum AppConstants {
    /// Sensor data collection constants
    enum SensorCollection {
        /// Frequency of sensor data collection in Hz
        static let sensorFrequency: Double = 50.0
        
        /// Interval between sensor readings in seconds (1/frequency)
        static let sensorInterval: TimeInterval = 1.0 / sensorFrequency
        
        /// Frequency of audio sampling in Hz
        static let audioSampleRate: Double = 16000.0
        
        /// Interval for sending data from Watch to iPhone in seconds
        static let dataTransferInterval: TimeInterval = 0.1
        
        /// Maximum buffer size for sensor data before sending
        static let maxBufferSize: Int = 5
    }
    
    /// Watch connectivity message types
    enum MessageType {
        /// Key for message type in WCSession messages
        static let typeKey = "messageType"
        
        /// Key for payload in WCSession messages
        static let payloadKey = "payload"
        
        /// Message type for sensor data
        static let sensorData = "sensorData"
        
        /// Message type for starting a mapping session
        static let startMapping = "startMapping"
        
        /// Message type for starting a normal session
        static let startNormal = "startNormal"
        
        /// Message type for stopping a session
        static let stopSession = "stopSession"
    }
    
    /// Exercise types supported by the app
    enum ExerciseType: String, CaseIterable, Codable {
        case pushUp = "Push-up"
        case squat = "Squat"
        case sitUp = "Sit-up"
        case lunge = "Lunge"
        
        /// Returns a user-friendly name for the exercise
        var displayName: String {
            return rawValue
        }
    }
} 