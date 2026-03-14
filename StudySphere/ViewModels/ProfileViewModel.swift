import Foundation
import UIKit
import VISOR

@Observable
@ViewModel
final class ProfileViewModel {

    enum Action {
        case loadProfile
        case updateName(String)
        case updateProfileImage(UIImage?)
        case clearHistory
    }

    struct State: Equatable {
        @Bound(\ProfileViewModel.profileService) var profile: UserProfile?
        @Bound(\ProfileViewModel.profileService) var profileImage: UIImage?
        @Bound(\ProfileViewModel.profileService) var sessionHistory: [SessionHistoryEntry] = []
    }

    var state = State()

    var totalFocusTime: TimeInterval {
        state.sessionHistory.reduce(0) { $0 + $1.durationSeconds }
    }

    var totalSessions: Int {
        state.sessionHistory.count
    }

    var averageFocusScore: Double {
        guard !state.sessionHistory.isEmpty else { return 0 }
        return state.sessionHistory.reduce(0) { $0 + $1.focusScore } / Double(state.sessionHistory.count)
    }

    func handle(_ action: Action) async {
        switch action {
        case .loadProfile:
            profileService.load()
        case .updateName(let name):
            profileService.saveProfile(
                name: name,
                avatarImageData: state.profile?.avatarImageData)
        case .updateProfileImage(let image):
            let imageData = image.flatMap { $0.jpegData(compressionQuality: 0.8) }
            profileService.saveProfile(
                name: state.profile?.name ?? "Student",
                avatarImageData: imageData)
        case .clearHistory:
            profileService.clearHistory()
        }
    }

    // MARK: - Private

    private let profileService: any ProfileService
}
