@preconcurrency import AVFoundation
import UIKit
import VISOR

/// Manages camera session and photo capture for profile photos.
@Observable
@ViewModel
class ProfileCameraViewModel: NSObject {

  enum ZoomGesturePhase {
    case started
    case changed(magnification: CGFloat)
    case ended(magnification: CGFloat)
  }

  enum Action {
    case viewAppeared
    case viewDisappeared
    case capturePhoto
    case switchCamera
    case focus(at: CGPoint)
    case zoomGestureUpdated(ZoomGesturePhase)
    case openSettings
  }

  struct State: Equatable {
    var isCameraDenied = false
    var cameraPosition: AVCaptureDevice.Position = .back
    var isSessionReady = false
    var currentZoomFactor: CGFloat = 1.0
    var isZoomAvailable = false
    var isZoomGestureActive = false
    var error: String?
    var captureError: String?
    var photoCaptureCount = 0
  }

  var state = State()

  override init() {
    super.init()
    Task { await requestPermissionAndSetup() }
  }

  let captureSession = AVCaptureSession()
  let photoOutput = AVCapturePhotoOutput()

  /// The last captured photo (outside State because UIImage is non-Equatable).
  var capturedPhoto: UIImage?

  func handle(_ action: Action) async {
    switch action {
    case .viewAppeared:
      resumeSession()
    case .viewDisappeared:
      stopSession()
    case .capturePhoto:
      capturePhoto()
    case .switchCamera:
      switchCamera()
    case .focus(let point):
      focus(at: point)
    case .openSettings:
      if let url = URL(string: UIApplication.openSettingsURLString) {
        await UIApplication.shared.open(url)
      }
    case .zoomGestureUpdated(let phase):
      switch phase {
      case .started:
        zoomGestureStarted()
      case .changed(let magnification):
        zoomGestureChanged(magnification: magnification)
      case .ended(let magnification):
        zoomGestureEnded(magnification: magnification)
      }
    }
  }

  // MARK: - Permission & Setup

  private func requestPermissionAndSetup() async {
    let granted = await AVCaptureDevice.requestAccess(for: .video)
    if granted {
      await setupSession()
    } else {
      state.isCameraDenied = true
    }
  }

  private func setupSession() async {
    guard !state.isSessionReady else { return }

    let cameraPos = state.cameraPosition

    let success: Bool = await withCheckedContinuation { continuation in
      sessionQueue.async { [captureSession, photoOutput] in
        captureSession.beginConfiguration()

        let videoDevice: AVCaptureDevice? =
          if cameraPos == .back {
            Self.preferredRearCamera()
          } else {
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
          }

        guard
          let videoDevice,
          let videoInput = try? AVCaptureDeviceInput(device: videoDevice)
        else {
          captureSession.commitConfiguration()
          continuation.resume(returning: false)
          return
        }

        captureSession.sessionPreset = .photo

        if captureSession.canAddInput(videoInput) {
          captureSession.addInput(videoInput)
        }

        if captureSession.canAddOutput(photoOutput) {
          captureSession.addOutput(photoOutput)
        }

        captureSession.commitConfiguration()

        if let connection = photoOutput.connection(with: .video) {
          connection.isVideoMirrored = (cameraPos == .front)
        }

        captureSession.startRunning()
        self.updateZoomState(for: videoDevice)
        continuation.resume(returning: true)
      }
    }

    if success {
      state.isSessionReady = true
      observeSessionNotifications()
    } else {
      state.error = "Could not access camera"
    }
  }

  // MARK: - Photo Capture

  private func capturePhoto() {
    guard state.isSessionReady else { return }
    let settings = AVCapturePhotoSettings()
    photoOutput.capturePhoto(with: settings, delegate: self)
  }

  // MARK: - Camera Switch

  private func switchCamera() {
    guard state.isSessionReady else { return }

    let newPosition: AVCaptureDevice.Position = (state.cameraPosition == .back) ? .front : .back

    sessionQueue.async { [captureSession, photoOutput] in
      let newDevice: AVCaptureDevice? =
        if newPosition == .back {
          Self.preferredRearCamera()
        } else {
          AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }

      guard
        let newDevice,
        let newInput = try? AVCaptureDeviceInput(device: newDevice)
      else { return }

      captureSession.beginConfiguration()

      for input in captureSession.inputs {
        if let deviceInput = input as? AVCaptureDeviceInput,
           deviceInput.device.hasMediaType(.video)
        {
          captureSession.removeInput(deviceInput)
        }
      }

      captureSession.sessionPreset = .photo

      if captureSession.canAddInput(newInput) {
        captureSession.addInput(newInput)
      }

      captureSession.commitConfiguration()

      if let connection = photoOutput.connection(with: .video) {
        connection.isVideoMirrored = (newPosition == .front)
      }

      self.updateZoomState(for: newDevice)

      Task { @MainActor [weak self] in
        self?.state.cameraPosition = newPosition
      }
    }
  }

  // MARK: - Session Lifecycle

  private func stopSession() {
    sessionQueue.async { [captureSession] in
      captureSession.stopRunning()
    }
  }

  private func resumeSession() {
    guard state.isSessionReady else { return }
    sessionQueue.async { [captureSession] in
      if !captureSession.isRunning {
        captureSession.startRunning()
      }
    }
  }

  // MARK: - Focus

  private func focus(at devicePoint: CGPoint) {
    withVideoDevice { device in
      if device.isFocusPointOfInterestSupported {
        device.focusPointOfInterest = devicePoint
        device.focusMode = .autoFocus
      }
      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = devicePoint
        device.exposureMode = .autoExpose
      }
    }
  }

  // MARK: - Zoom

  private func zoomGestureStarted() {
    state.isZoomGestureActive = true
    baseZoomFactor = state.currentZoomFactor
  }

  private func zoomGestureChanged(magnification: CGFloat) {
    let newFactor = baseZoomFactor * magnification
    let clamped = min(max(newFactor, minZoomFactor), maxZoomFactor)
    state.currentZoomFactor = clamped
    applyZoom(userZoom: clamped)
  }

  private func zoomGestureEnded(magnification: CGFloat) {
    let newFactor = baseZoomFactor * magnification
    let clamped = min(max(newFactor, minZoomFactor), maxZoomFactor)
    state.currentZoomFactor = clamped
    applyZoom(userZoom: clamped)
    state.isZoomGestureActive = false
  }

  // MARK: - Private

  private var baseZoomFactor: CGFloat = 1.0
  private var minZoomFactor: CGFloat = 1.0
  private var maxZoomFactor: CGFloat = 1.0
  private var wideAngleZoomFactor: CGFloat = 1.0

  private let sessionQueue = DispatchQueue(label: "profileCamera.session")

  private var interruptionObserver: Any?
  private var interruptionEndedObserver: Any?
  private var runtimeErrorObserver: Any?

  private func applyZoom(userZoom: CGFloat) {
    let wideZoom = wideAngleZoomFactor
    withVideoDevice { device in
      let deviceZoom = userZoom * wideZoom
      device.videoZoomFactor = Swift.max(
        device.minAvailableVideoZoomFactor,
        Swift.min(deviceZoom, device.maxAvailableVideoZoomFactor))
    }
  }

  private func withVideoDevice(_ body: @Sendable @escaping (AVCaptureDevice) -> Void) {
    sessionQueue.async { [captureSession] in
      guard
        let device = captureSession.inputs
          .compactMap({ $0 as? AVCaptureDeviceInput })
          .first(where: { $0.device.hasMediaType(.video) })?
          .device
      else { return }

      do {
        try device.lockForConfiguration()
        body(device)
        device.unlockForConfiguration()
      } catch {}
    }
  }

  private nonisolated static func preferredRearCamera() -> AVCaptureDevice? {
    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInWideAngleCamera,
      ],
      mediaType: .video,
      position: .back)
    return discovery.devices.first
  }

  private nonisolated func updateZoomState(
    for device: AVCaptureDevice,
    userZoom: CGFloat = 1.0)
  {
    let wideZoom = CGFloat(
      device.virtualDeviceSwitchOverVideoZoomFactors.first?.doubleValue ?? 1.0)

    do {
      try device.lockForConfiguration()
      let deviceZoom = userZoom * wideZoom
      device.videoZoomFactor = Swift.max(
        device.minAvailableVideoZoomFactor,
        Swift.min(deviceZoom, device.maxAvailableVideoZoomFactor))
      device.unlockForConfiguration()
    } catch {}

    let zoomAvailable = device.maxAvailableVideoZoomFactor > device.minAvailableVideoZoomFactor
    let minZoom = device.minAvailableVideoZoomFactor / wideZoom
    let maxZoom = device.maxAvailableVideoZoomFactor / wideZoom
    let clamped = Swift.min(Swift.max(userZoom, minZoom), maxZoom)

    Task { @MainActor [weak self] in
      guard let self else { return }
      self.state.isZoomAvailable = zoomAvailable
      self.wideAngleZoomFactor = wideZoom
      self.minZoomFactor = minZoom
      self.maxZoomFactor = maxZoom
      self.state.currentZoomFactor = clamped
      self.baseZoomFactor = clamped
    }
  }

  // MARK: - Session Notifications

  private func observeSessionNotifications() {
    interruptionEndedObserver = NotificationCenter.default.addObserver(
      forName: AVCaptureSession.interruptionEndedNotification,
      object: captureSession,
      queue: .main) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.resumeSession()
        }
      }

    runtimeErrorObserver = NotificationCenter.default.addObserver(
      forName: AVCaptureSession.runtimeErrorNotification,
      object: captureSession,
      queue: .main) { [weak self] notification in
        let avError = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
        MainActor.assumeIsolated {
          guard let self else { return }
          if avError?.code == .mediaServicesWereReset {
            Task { await self.requestPermissionAndSetup() }
          } else {
            self.resumeSession()
          }
        }
      }
  }

  private func removeSessionNotifications() {
    [interruptionEndedObserver, runtimeErrorObserver]
      .compactMap { $0 }
      .forEach { NotificationCenter.default.removeObserver($0) }
    interruptionEndedObserver = nil
    runtimeErrorObserver = nil
  }

  @MainActor
  deinit {
    removeSessionNotifications()
  }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension ProfileCameraViewModel: AVCapturePhotoCaptureDelegate {
  nonisolated func photoOutput(
    _: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: (any Error)?)
  {
    let errorDescription = error?.localizedDescription
    let photoData = photo.fileDataRepresentation()
    Task { @MainActor [weak self] in
      guard let self else { return }

      if let errorDescription {
        self.state.captureError = errorDescription
        return
      }

      guard let data = photoData, let image = UIImage(data: data) else {
        self.state.captureError = "Failed to capture photo"
        return
      }

      self.capturedPhoto = image
      self.state.photoCaptureCount += 1
    }
  }
}
