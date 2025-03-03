import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
    }
    
    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state.
        // This can occur for certain types of temporary interruptions or when the user quits the application.
        
        // Make sure to stop any active data collection
        DataCollectorService.shared.stopSession()
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Handle background tasks
        for task in backgroundTasks {
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Handle background refresh
                backgroundTask.setTaskCompletedWithSnapshot(false)
            default:
                // Make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
} 