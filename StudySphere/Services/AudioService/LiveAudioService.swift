import AudioToolbox
import AVFoundation
import Foundation

@Observable
final class LiveAudioService: AudioService {

    // MARK: - State

    private(set) var isPlaying = false
    private(set) var isBackgroundAudioActive = false

    // MARK: - Lifecycle

    init() {
        observeInterruptions()
    }

    // MARK: - Playback

    func play(url: URL, volume: Float = 1.0) throws {
        stop()

        try configureAudioSession()

        let player = try AVAudioPlayer(contentsOf: url)
        player.volume = max(0.0, min(1.0, volume))
        player.prepareToPlay()
        audioPlayer = player
        isPlaying = true
        player.play()

        // Auto-stop after duration
        let duration = player.duration
        playbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    // MARK: - Background Audio

    func startBackgroundAudio() throws {
        guard !isBackgroundAudioActive else { return }

        try configureAudioSession()

        guard let silentURL = Bundle.main.url(forResource: "silent-loop", withExtension: "wav") else {
            throw AudioServiceError.audioFileNotFound("silent-loop.wav")
        }

        let player = try AVAudioPlayer(contentsOf: silentURL)
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        silentPlayer = player
        isBackgroundAudioActive = true
    }

    func stopBackgroundAudio() {
        silentPlayer?.stop()
        silentPlayer = nil
        isBackgroundAudioActive = false

        // Only deactivate session if nothing else is playing
        if !isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - Private

    private var audioPlayer: AVAudioPlayer?
    private var silentPlayer: AVAudioPlayer?
    private var playbackTask: Task<Void, Never>?

    private func configureAudioSession() throws {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            throw AudioServiceError.audioSessionSetupFailed
        }
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            guard
                let info = notification.userInfo,
                let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                type == .ended
            else { return }

            Task { @MainActor [weak self] in
                self?.resumeAfterInterruption()
            }
        }
    }

    private func resumeAfterInterruption() {
        if isBackgroundAudioActive {
            silentPlayer?.play()
        }
        if isPlaying {
            audioPlayer?.prepareToPlay()
        }
    }
}
