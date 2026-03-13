import MultipeerConnectivity
import VISOR

@Stubbable
@Spyable
protocol ProfileService: AnyObject {
    var profile: UserProfile? { get }
    var displayName: String { get }
    var peerID: MCPeerID? { get }
    var sessionHistory: [SessionHistoryEntry] { get }

    func load()
    func saveProfile(name: String, avatarSystemName: String)
    func addHistoryEntry(_ entry: SessionHistoryEntry)
    func clearHistory()
}

#if DEBUG
extension SpyProfileService.Call: Equatable {
    public static func == (lhs: SpyProfileService.Call, rhs: SpyProfileService.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
