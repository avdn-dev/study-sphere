import Foundation
import VISOR

@Stubbable
@Spyable
protocol SessionInteractor: AnyObject {
    var activeSession: StudySession? { get }
    var participants: [Participant] { get }
    var isHost: Bool { get }
  @StubbableDefault(StudySessionPhase.idle)
    var phase: StudySessionPhase { get }
    var elapsedTime: TimeInterval? { get }
    var isCalibrated: Bool { get }
    var isScreenTimeAuthorized: Bool { get }

    func createSession(settings: SessionSettings) async
    func startSession() async
    func endSession() async
//    func joinSession(host: DiscoveredSession) async
    func leaveSession() async
    func leaveSessionGracefully() async
    func requestScreenTimeAuthorization() async throws
    func handleAppDidEnterBackground()
    func handleAppWillEnterForeground()
}

#if DEBUG
extension SpySessionInteractor.Call: Equatable {
    public static func == (lhs: SpySessionInteractor.Call, rhs: SpySessionInteractor.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
