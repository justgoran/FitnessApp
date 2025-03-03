# AI Fitness Trainer

A groundbreaking watchOS + iOS app prototype that uses machine learning to count exercise repetitions without requiring the user to count out loud.

## Overview

AI Fitness Trainer uses the sensors in an Apple Watch to track and count exercise repetitions. The app works in two modes:

1. **Mapping Mode**: During the first session for a particular exercise, the user counts reps out loud. The app collects audio, accelerometer, gyroscope, and heart rate data to "learn" the signature of that exercise.

2. **Normal Mode**: After calibration, the app can silently count reps using only sensor data, without requiring audio input.

## Features

- **Data Collection**: Collects accelerometer, gyroscope, and heart rate data from the Apple Watch at 50 Hz.
- **Audio Processing**: During mapping sessions, records audio at 16 kHz to detect when the user counts reps.
- **Real-time Streaming**: Streams data from the Watch to the iPhone every 0.1 seconds for low-latency processing.
- **Pattern Recognition**: Uses the mapping session data to recognize repetition patterns in subsequent workouts.
- **Visualization**: Displays sensor data in real-time on the iPhone for debugging and analysis.
- **Fallback Detection**: Includes a simple on-device rep detection algorithm as a fallback.

## Technical Details

### watchOS App

- **DataCollector**: Core service that collects sensor data and streams it to the iPhone.
- **WorkoutView**: UI for starting/stopping workouts and displaying rep counts.

### iOS App

- **DataReceiver**: Service that receives and processes data from the Apple Watch.
- **DataAnalyzer**: Analyzes sensor data to detect repetitions using pattern matching.
- **WorkoutView**: UI for displaying workout data and visualizing sensor readings.

## Requirements

- iOS 15.0+ / watchOS 8.0+
- Xcode 13.0+
- Apple Watch Series 4 or newer (for better sensor accuracy)

## Getting Started

1. Clone the repository
2. Open the project in Xcode
3. Build and run the app on your iPhone and Apple Watch
4. Start with a mapping session for your exercise of choice
5. After completing the mapping session, you can use normal mode for future workouts

## Future Enhancements

- Persistent storage of exercise patterns
- Support for more exercise types
- Machine learning model to improve rep detection accuracy
- Workout history and statistics
- Integration with Apple Health
- Social sharing features

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Apple for providing the CoreMotion, HealthKit, and WatchConnectivity frameworks
- The open source community for inspiration and guidance 