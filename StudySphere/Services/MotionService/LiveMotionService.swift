import CoreMotion
import Foundation
import VISOR

@Observable
final class LiveMotionService: MotionService {

    // MARK: - State

    var isStationary = true
    var isMonitoring = false

    // MARK: - Control
    
    // TODO: check this
    func requestPermission() async -> Bool {
        guard CMMotionActivityManager.isActivityAvailable() else { return false }
        
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            // Query trick to trigger the prompt
            return await withCheckedContinuation { continuation in
                motionActivityManager.queryActivityStarting(
                    from: .distantPast,
                    to: .now,
                    to: .main
                ) { _, error in
                    if let error, (error as NSError).code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: true)
                    }
                }
            }
        @unknown default:
            return false
        }
    }

    func startMonitoring(sensitivity: Double) {
        guard !isMonitoring else { return }
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        
        isMonitoring = true
        
        motionActivityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let self, let activity else { return }
            let stationary = Self.isStationary(activity: activity, sensitivity: sensitivity)
            Task { @MainActor in
                self.isStationary = stationary
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        motionActivityManager.stopActivityUpdates()
        isMonitoring = false
        isStationary = true
    }

    // MARK: - Private

    private let motionActivityManager = CMMotionActivityManager()
    private let queue = OperationQueue()
    
    private static func isStationary(activity: CMMotionActivity, sensitivity: Double) -> Bool {
        // sensitivity: 0.0 (strict - must be explicitly stationary)
        //              1.0 (loose - treat low-confidence movement as stationary)
        
        if activity.stationary {
            return true
        }
        
        // Unknown activity with low confidence — use sensitivity threshold
        // Higher sensitivity = more likely to treat ambiguous state as stationary
        if activity.unknown {
            return false
        }
        
        // Device is walking, running, cycling, or in automotive — not stationary
        // But if confidence is low and sensitivity is high, still treat as stationary
        if activity.confidence == .low && sensitivity >= 0.6 {
            return true
        }
        
        return false
    }
}
