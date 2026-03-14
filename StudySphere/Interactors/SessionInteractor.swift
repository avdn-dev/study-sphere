import Foundation
import VISOR

@Stubbable
@Spyable
protocol SessionInteractor: AnyObject {
    var activeSession: StudySession? { get }
    var participants: [Participant] { get }
    var isHost: Bool { get }
    var remainingTime: TimeInterval? { get }
    var isCalibrated: Bool { get }
    var isScreenTimeAuthorized: Bool { get }

    func createSession(settings: SessionSettings) async
    func startSession() async
    func endSession() async
//    func joinSession(host: DiscoveredSession) async
    func leaveSession() async
    func requestScreenTimeAuthorization() async throws
}

#if DEBUG
extension SpySessionInteractor.Call: Equatable {
    public static func == (lhs: SpySessionInteractor.Call, rhs: SpySessionInteractor.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
