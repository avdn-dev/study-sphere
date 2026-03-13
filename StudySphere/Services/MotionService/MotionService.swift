import Foundation
import VISOR

@Stubbable
@Spyable
protocol MotionService: AnyObject {
    var isStationary: Bool { get }
    var isMonitoring: Bool { get }

    func startMonitoring(sensitivity: Double)
    func stopMonitoring()
}

#if DEBUG
extension SpyMotionService.Call: Equatable {
    public static func == (lhs: SpyMotionService.Call, rhs: SpyMotionService.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
