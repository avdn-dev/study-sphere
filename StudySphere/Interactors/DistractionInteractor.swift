import Foundation
import VISOR

@Stubbable
@Spyable
protocol DistractionInteractor: AnyObject {
    var participantStatuses: [UUID: ParticipantStatus] { get }
    var distractionEvents: [DistractionEvent] { get }
    var isLocalDeviceDistracted: Bool { get }
    var localDistractionSource: DistractionEvent.Source? { get }

    func startMonitoring(settings: SessionSettings)
    func stopMonitoring()
    func updateRemoteStatus(participantID: UUID, status: ParticipantStatus)
}

#if DEBUG
extension SpyDistractionInteractor.Call: Equatable {
    public static func == (lhs: SpyDistractionInteractor.Call, rhs: SpyDistractionInteractor.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
