import MultipeerConnectivity
import UIKit
import VISOR

@Stubbable
@Spyable
protocol ProfileService: AnyObject {
    var profile: UserProfile? { get }
    var profileImage: UIImage? { get }
    var displayName: String { get }
    var peerID: MCPeerID? { get }
    var sessionHistory: [SessionHistoryEntry] { get }

    func load()
    func saveProfile(name: String, avatarImageData: Data?)
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
