import Foundation
import VISOR

/// Errors that can occur during audio service operations
enum AudioServiceError: Error, LocalizedError {
    case audioFileNotFound(String)
    case audioSessionSetupFailed
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .audioFileNotFound(let fileName):
            "Audio file not found: \(fileName)"
        case .audioSessionSetupFailed:
            "Failed to setup audio session"
        case .playbackFailed:
            "Failed to play audio"
        }
    }
}

@Stubbable
@Spyable
protocol AudioService: AnyObject {
    /// Whether audio is currently playing
    var isPlaying: Bool { get }

    /// Whether the background audio session is active (silent loop running)
    var isBackgroundAudioActive: Bool { get }

    /// Play audio from the given URL
    func play(url: URL, volume: Float) throws

    /// Stop current playback
    func stop()

    /// Start the background audio session (silent loop to keep audio alive in background)
    func startBackgroundAudio() throws

    /// Stop the background audio session
    func stopBackgroundAudio()
}

#if DEBUG
extension SpyAudioService.Call: @retroactive Equatable {
    public static func == (lhs: SpyAudioService.Call, rhs: SpyAudioService.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
