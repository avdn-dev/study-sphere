import AVFoundation
import SwiftUI

/// UIViewRepresentable wrapper for AVCaptureVideoPreviewLayer.
struct CameraPreviewView: UIViewRepresentable {
  class PreviewView: UIView {
    override class var layerClass: AnyClass {
      AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
      layer as! AVCaptureVideoPreviewLayer
    }

    var onTapToFocus: ((CGPoint) -> Void)?
    private var focusIndicator: UIView?
    private var fadeOutWork: DispatchWorkItem?

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
      let point = gesture.location(in: self)
      let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
      onTapToFocus?(devicePoint)
      showFocusIndicator(at: point)
    }

    private func showFocusIndicator(at point: CGPoint) {
      fadeOutWork?.cancel()
      focusIndicator?.layer.removeAllAnimations()
      focusIndicator?.removeFromSuperview()

      let size: CGFloat = 50
      let indicator = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
      indicator.center = point
      indicator.layer.borderColor = UIColor.yellow.cgColor
      indicator.layer.borderWidth = 1.5
      indicator.backgroundColor = .clear
      indicator.isUserInteractionEnabled = false

      indicator.transform = CGAffineTransform(scaleX: 2, y: 2)
      indicator.alpha = 0
      addSubview(indicator)
      focusIndicator = indicator

      UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
        indicator.transform = .identity
        indicator.alpha = 1
      }

      let work = DispatchWorkItem { [weak self] in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
          indicator.alpha = 0
        } completion: { _ in
          indicator.removeFromSuperview()
          if self?.focusIndicator === indicator {
            self?.focusIndicator = nil
          }
        }
      }
      fadeOutWork = work
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
  }

  var cameraViewModel: ProfileCameraViewModel

  func makeUIView(context _: Context) -> PreviewView {
    let view = PreviewView()
    view.previewLayer.session = cameraViewModel.captureSession
    view.previewLayer.videoGravity = .resizeAspect
    view.onTapToFocus = { [weak cameraViewModel] devicePoint in
      Task { await cameraViewModel?.handle(.focus(at: devicePoint)) }
    }
    let tap = UITapGestureRecognizer(target: view, action: #selector(PreviewView.handleTap(_:)))
    view.addGestureRecognizer(tap)
    view.backgroundColor = .black
    return view
  }

  func updateUIView(_: PreviewView, context _: Context) {}
}
