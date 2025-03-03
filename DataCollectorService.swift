import Foundation
import CoreMotion
import HealthKit
import AVFoundation
import WatchConnectivity
import os.log

/// Service responsible for collecting sensor data from the Apple Watch
class DataCollectorService: NSObject {
    // MARK: - Properties
    
    /// Singleton instance
    static let shared = DataCollectorService()
    
    /// Logger for debugging
    private let logger = Logger(subsystem: "com.aifitnessapp.watchapp", category: "DataCollector")
    
    /// Motion manager for accelerometer and gyroscope data
    private let motionManager = CMMotionManager()
    
    /// Health store for heart rate data
    private let healthStore = HKHealthStore()
    
    /// Audio engine for recording audio
    private var audioEngine: AVAudioEngine?
    
    /// Audio input node
    private var inputNode: AVAudioInputNode?
    
    /// Buffer for collecting sensor data before sending
    private var dataBuffer: [SensorData] = []
    
    /// Timer for sending data to the iPhone
    private var transferTimer: Timer?
    
    /// Timer for collecting sensor data
    private var sensorTimer: Timer?
    
    /// Current collection mode
    private(set) var isInMappingMode = false
    
    /// Flag indicating if collection is active
    private(set) var isCollecting = false
    
    /// Last recorded heart rate
    private var lastHeartRate: Double = 0
    
    /// Watch connectivity session
    private var session: WCSession?
    
    /// Peak audio level in the current sample
    private var currentAudioPeak: Double = 0
    
    /// Completion handler for when data collection starts
    var onDataCollectionStarted: (() -> Void)?
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupHealthKitPermissions()
        checkSensorAvailability()
    }
    
    // MARK: - Setup Methods
    
    /// Sets up the watch connectivity session
    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            logger.info("Watch connectivity session activated")
        } else {
            logger.error("Watch connectivity is not supported on this device")
        }
    }
    
    /// Requests permissions for HealthKit
    private func setupHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit is not available on this device")
            return
        }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { success, error in
            if success {
                self.logger.info("HealthKit authorization successful")
            } else {
                self.logger.error("HealthKit authorization failed: \(String(describing: error))")
            }
        }
    }
    
    /// Checks if required sensors are available
    private func checkSensorAvailability() {
        if !motionManager.isAccelerometerAvailable {
            logger.warning("Accelerometer is not available on this device")
        }
        
        if !motionManager.isGyroAvailable {
            logger.warning("Gyroscope is not available on this device")
        }
        
        // Check if microphone is available
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            if audioSession.recordPermission != .granted {
                logger.warning("Microphone permission not granted")
            }
        } catch {
            logger.error("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Starts collecting data in mapping mode (with audio)
    func startMappingSession() {
        logger.info("Starting mapping session (with audio)")
        isInMappingMode = true
        startDataCollection()
    }
    
    /// Starts collecting data in normal mode (without audio)
    func startNormalSession() {
        logger.info("Starting normal session (without audio)")
        isInMappingMode = false
        startDataCollection()
    }
    
    /// Stops the current data collection session
    func stopSession() {
        guard isCollecting else { return }
        
        logger.info("Stopping data collection session")
        isCollecting = false
        
        // Stop motion updates
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        
        // Stop heart rate monitoring
        // (HealthKit queries are one-time, so no need to stop)
        
        // Stop audio recording if in mapping mode
        if isInMappingMode {
            stopAudioRecording()
        }
        
        // Stop timers
        sensorTimer?.invalidate()
        sensorTimer = nil
        
        transferTimer?.invalidate()
        transferTimer = nil
        
        // Clear buffer
        dataBuffer.removeAll()
        
        // Send stop message to iPhone
        sendMessage(type: AppConstants.MessageType.stopSession, payload: [:])
    }
    
    // MARK: - Private Methods
    
    /// Starts collecting data from all sensors
    private func startDataCollection() {
        guard !isCollecting else {
            logger.warning("Data collection already in progress")
            return
        }
        
        logger.info("Starting data collection")
        isCollecting = true
        
        // Start motion updates
        startMotionUpdates()
        
        // Start heart rate monitoring
        startHeartRateMonitoring()
        
        // Start audio recording if in mapping mode
        if isInMappingMode {
            startAudioRecording()
        }
        
        // Create timer for collecting sensor data
        sensorTimer = Timer.scheduledTimer(
            timeInterval: AppConstants.SensorCollection.sensorInterval,
            target: self,
            selector: #selector(collectSensorData),
            userInfo: nil,
            repeats: true
        )
        
        // Create timer for sending data to iPhone
        transferTimer = Timer.scheduledTimer(
            timeInterval: AppConstants.SensorCollection.dataTransferInterval,
            target: self,
            selector: #selector(sendBufferedData),
            userInfo: nil,
            repeats: true
        )
        
        // Send start message to iPhone
        let messageType = isInMappingMode ? 
            AppConstants.MessageType.startMapping : 
            AppConstants.MessageType.startNormal
        
        sendMessage(type: messageType, payload: [:])
        
        // Notify that data collection has started
        DispatchQueue.main.async {
            self.onDataCollectionStarted?()
        }
        
        logger.info("Data collection started successfully")
    }
    
    /// Starts collecting motion data (accelerometer and gyroscope)
    private func startMotionUpdates() {
        // Configure and start accelerometer
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = AppConstants.SensorCollection.sensorInterval
            motionManager.startAccelerometerUpdates()
        }
        
        // Configure and start gyroscope
        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = AppConstants.SensorCollection.sensorInterval
            motionManager.startGyroUpdates()
        }
    }
    
    /// Starts monitoring heart rate
    private func startHeartRateMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)
        
        // Create a query to receive heart rate updates
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            // Process the latest heart rate sample
            if let sample = samples.last {
                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                self?.lastHeartRate = heartRate
            }
        }
        
        // Set up the query to update with new heart rate data
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            guard let samples = samples as? [HKQuantitySample] else { return }
            
            // Process the latest heart rate sample
            if let sample = samples.last {
                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                self?.lastHeartRate = heartRate
            }
        }
        
        // Execute the query
        healthStore.execute(query)
    }
    
    /// Starts recording audio
    private func startAudioRecording() {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else { return }
        
        // Get the input node
        inputNode = audioEngine.inputNode
        
        guard let inputNode = inputNode else { return }
        
        // Configure the audio format
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AppConstants.SensorCollection.audioSampleRate,
            channels: 1,
            interleaved: false
        )
        
        // Install a tap on the input node to process audio
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // Calculate the peak audio level from the buffer
            guard let self = self else { return }
            
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            
            var peak: Float = 0.0
            
            // Find the peak amplitude in the buffer
            if let channelData = channelData {
                for i in 0..<frameLength {
                    let sample = abs(channelData[i])
                    if sample > peak {
                        peak = sample
                    }
                }
            }
            
            // Update the current audio peak
            self.currentAudioPeak = Double(peak)
        }
        
        // Start the audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Could not start audio engine: \(error.localizedDescription)")
        }
    }
    
    /// Stops recording audio
    private func stopAudioRecording() {
        // Remove the tap from the input node
        inputNode?.removeTap(onBus: 0)
        
        // Stop the audio engine
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        currentAudioPeak = 0
    }
    
    /// Collects sensor data at regular intervals
    @objc private func collectSensorData() {
        // Get accelerometer data
        var accX: Double = 0
        var accY: Double = 0
        var accZ: Double = 0
        
        if let accelerometerData = motionManager.accelerometerData {
            accX = accelerometerData.acceleration.x
            accY = accelerometerData.acceleration.y
            accZ = accelerometerData.acceleration.z
        }
        
        // Get gyroscope data
        var gyroX: Double = 0
        var gyroY: Double = 0
        var gyroZ: Double = 0
        
        if let gyroData = motionManager.gyroData {
            gyroX = gyroData.rotationRate.x
            gyroY = gyroData.rotationRate.y
            gyroZ = gyroData.rotationRate.z
        }
        
        // Create sensor data object
        let sensorData = SensorData(
            timestamp: Date().timeIntervalSince1970,
            accX: accX,
            accY: accY,
            accZ: accZ,
            gyroX: gyroX,
            gyroY: gyroY,
            gyroZ: gyroZ,
            heartRate: lastHeartRate,
            audioPeak: isInMappingMode ? currentAudioPeak : nil
        )
        
        // Add to buffer
        dataBuffer.append(sensorData)
        
        // Check if we need to perform local rep detection
        performLocalRepDetection(with: sensorData)
    }
    
    /// Performs simple local rep detection as a fallback
    private func performLocalRepDetection(with data: SensorData) {
        // Simple peak detection on Z-axis acceleration
        // This is a placeholder for a more sophisticated algorithm
        // that would be implemented in a real app
        
        // In a real implementation, you would:
        // 1. Maintain a window of recent accelerometer readings
        // 2. Apply a low-pass filter to smooth the data
        // 3. Detect peaks that exceed a certain threshold
        // 4. Apply time-based constraints (e.g., minimum time between reps)
        
        // For now, we'll just print a message when a potential rep is detected
        if abs(data.accZ) > 1.5 {
            print("Potential rep detected locally!")
        }
    }
    
    /// Sends buffered data to the iPhone
    @objc private func sendBufferedData() {
        guard !dataBuffer.isEmpty else { return }
        
        // Convert data to JSON format
        let jsonArray = dataBuffer.map { $0.toJSON() }
        
        // Send the data to the iPhone
        sendMessage(
            type: AppConstants.MessageType.sensorData,
            payload: ["data": jsonArray]
        )
        
        // Clear the buffer
        dataBuffer.removeAll()
    }
    
    /// Sends a message to the iPhone
    private func sendMessage(type: String, payload: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("Watch connectivity session is not reachable")
            return
        }
        
        // Create the message dictionary
        var message: [String: Any] = [
            AppConstants.MessageType.typeKey: type
        ]
        
        // Add the payload if it's not empty
        if !payload.isEmpty {
            message[AppConstants.MessageType.payloadKey] = payload
        }
        
        // Send the message
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate

extension DataCollectorService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let messageType = message[AppConstants.MessageType.typeKey] as? String else { return }
        
        switch messageType {
        case AppConstants.MessageType.startMapping:
            startMappingSession()
            
        case AppConstants.MessageType.startNormal:
            startNormalSession()
            
        case AppConstants.MessageType.stopSession:
            stopSession()
            
        default:
            print("Unknown message type: \(messageType)")
        }
    }
} 