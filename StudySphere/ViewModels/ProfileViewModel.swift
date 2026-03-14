import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers
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
            let imageData = image.flatMap { Self.prepareForStorage($0) }
            profileService.saveProfile(
                name: state.profile?.name ?? "Student",
                avatarImageData: imageData)
        case .clearHistory:
            profileService.clearHistory()
        }
    }

    // MARK: - Private

    private let profileService: any ProfileService

    /// Resizes to 400x400 and encodes as HEIC (with JPEG fallback).
    private static func prepareForStorage(_ image: UIImage) -> Data? {
        let targetSize: CGFloat = 400
        let resized: UIImage
        if image.size.width != targetSize || image.size.height != targetSize {
            let renderer = UIGraphicsImageRenderer(
                size: CGSize(width: targetSize, height: targetSize))
            resized = renderer.image { _ in
                image.draw(in: CGRect(
                    origin: .zero,
                    size: CGSize(width: targetSize, height: targetSize)))
            }
        } else {
            resized = image
        }

        if let heic = heicData(from: resized) {
            return heic
        }
        return resized.jpegData(compressionQuality: 0.8)
    }

    private static func heicData(from image: UIImage, compressionQuality: CGFloat = 0.8) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.heic.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, cgImage,
            [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
