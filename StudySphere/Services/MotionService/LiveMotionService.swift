import CoreMotion
import Foundation
import VISOR

@Observable
final class LiveMotionService: MotionService {

    // MARK: - State

    var isStationary = true
    var isMonitoring = false

    // MARK: - Control

    func startMonitoring(sensitivity: Double) {
        // TODO: Start CMMotionActivityManager updates
    }

    func stopMonitoring() {
        // TODO: Stop CMMotionActivityManager updates
    }

    // MARK: - Private

    private let motionActivityManager = CMMotionActivityManager()
}
