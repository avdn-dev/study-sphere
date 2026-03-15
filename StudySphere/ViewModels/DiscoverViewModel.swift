import Foundation
import MultipeerConnectivity
import VISOR

@Observable
@ViewModel
final class DiscoverViewModel {

    enum Action {
        case startBrowsing
        case stopBrowsing
        case joinSession(room: RoomDiscoveryInfo)
        case refresh
    }

    struct State: Equatable {
        var discoveredRooms: [RoomDiscoveryInfo] = []
        var isSearching = false
        var isJoining = false
        var error: String?
    }

    var state = State()

    @Reaction(\DiscoverViewModel.multipeerService.discoveredRooms)
    func syncDiscoveredRooms(rooms: Result<[MCPeerID: RoomDiscoveryInfo], any Error>?) {
        switch rooms {
        case .success(let roomMap):
            state.discoveredRooms = Array(roomMap.values)
            state.error = nil
        case .failure(let error):
            state.error = error.localizedDescription
        case .none:
            break
        }
    }

    func handle(_ action: Action) async {
        switch action {
        case .startBrowsing:
            do {
                state.isSearching = true
                state.error = nil
                try multipeerService.startLookingForRooms(using: profileService.displayName)
            } catch {
                state.isSearching = false
                state.error = error.localizedDescription
            }

        case .stopBrowsing:
            multipeerService.stopLookingForRooms()
            state.isSearching = false

        case .joinSession(let room):
            guard !state.isJoining else { return }
            state.isJoining = true
            state.error = nil

            do {
                guard let profile = profileService.profile else {
                    state.error = "No profile available"
                    state.isJoining = false
                    return
                }

                let accepted = try await studySessionService.joinSession(
                    room: room,
                    profile: profile
                )

                if accepted {
                    multipeerService.stopLookingForRooms()
                    state.isSearching = false
                    router.dismissSheet()
                    router.present(fullScreen: .activeSession)
                } else {
                    state.error = "Join request was rejected"
                }
            } catch {
                state.error = error.localizedDescription
            }
            state.isJoining = false

        case .refresh:
            multipeerService.stopLookingForRooms()
            state.discoveredRooms = []
            do {
                try multipeerService.startLookingForRooms(using: profileService.displayName)
                state.isSearching = true
                state.error = nil
            } catch {
                state.isSearching = false
                state.error = error.localizedDescription
            }
        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    private let multipeerService: any MultipeerService
    private let studySessionService: any StudySessionService
    private let profileService: any ProfileService
}
