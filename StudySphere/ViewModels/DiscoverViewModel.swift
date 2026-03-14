import Foundation
import VISOR

@Observable
@ViewModel
final class DiscoverViewModel {

    enum Action {
        case startBrowsing
        case stopBrowsing
//        case joinSession(host: DiscoveredSession)
        case refresh
    }

    struct State: Equatable {
//        @Bound(\DiscoverViewModel.multipeerService) var isBrowsing = false
//        @Bound(\DiscoverViewModel.sessionInteractor) var activeSession: StudySession?
    }

    var state = State()

    func handle(_ action: Action) async {
//        switch action {
//        case .startBrowsing:
//            multipeerService.startBrowsing()
//        case .stopBrowsing:
//            multipeerService.stopBrowsing()
//        case .joinSession(let host):
//            await sessionInteractor.joinSession(host: host)
//            router.present(fullScreen: .activeSession)
//        case .refresh:
//            multipeerService.stopBrowsing()
//            multipeerService.startBrowsing()
//        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    private let multipeerService: any MultipeerService
    private let sessionInteractor: any SessionInteractor
}
