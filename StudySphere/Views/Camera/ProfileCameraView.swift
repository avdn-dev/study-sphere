import SwiftUI
import VISOR

@LazyViewModel(ProfileCameraViewModel.self)
struct ProfileCameraView: View {
  var onPhotoCaptured: (UIImage) -> Void
  var onDismiss: () -> Void

  var content: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      if viewModel.state.isCameraDenied {
        permissionDeniedView
      } else if viewModel.state.isSessionReady {
        cameraContentView
      } else if let error = viewModel.state.error {
        Text(error)
          .foregroundStyle(.white)
      } else {
        ProgressView()
          .tint(.white)
      }
    }
    .onChange(of: viewModel.state.photoCaptureCount) { _, _ in
      if let photo = viewModel.capturedPhoto {
        onPhotoCaptured(photo)
      }
    }
    .statusBarHidden()
  }

  // MARK: - Camera Content

  @ViewBuilder
  private var cameraContentView: some View {
    VStack(spacing: 0) {
      // Top bar
      HStack {
        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
        }

        Spacer()

        if viewModel.state.isZoomAvailable {
          Text(zoomLabel)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2), in: Capsule())
        }

        Spacer()

        Button {
          Task { await viewModel.handle(.switchCamera) }
        } label: {
          Image(systemName: "camera.rotate")
            .font(.title2)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
        }
      }
      .padding(.horizontal)

      // Camera preview
      CameraPreviewView(cameraViewModel: viewModel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 4)
        .gesture(
          MagnifyGesture()
            .onChanged { value in
              Task {
                await viewModel.handle(
                  .zoomGestureUpdated(.changed(magnification: value.magnification)))
              }
            }
            .onEnded { value in
              Task {
                await viewModel.handle(
                  .zoomGestureUpdated(.ended(magnification: value.magnification)))
              }
            }
        )
        .simultaneousGesture(
          MagnifyGesture()
            .onChanged { _ in
              if !viewModel.state.isZoomGestureActive {
                Task { await viewModel.handle(.zoomGestureUpdated(.started)) }
              }
            }
        )

      Spacer()

      // Capture button
      Button {
        Task { await viewModel.handle(.capturePhoto) }
      } label: {
        ZStack {
          Circle()
            .fill(.white)
            .frame(width: 72, height: 72)
          Circle()
            .stroke(.white.opacity(0.5), lineWidth: 4)
            .frame(width: 80, height: 80)
        }
      }
      .padding(.bottom, 40)
    }
  }

  // MARK: - Permission Denied

  @ViewBuilder
  private var permissionDeniedView: some View {
    VStack(spacing: 16) {
      Image(systemName: "camera.fill")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)

      Text("Camera Access Required")
        .font(.title3.bold())
        .foregroundStyle(.white)

      Text("Allow camera access in Settings to take a profile photo.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)

      Button("Open Settings") {
        Task { await viewModel.handle(.openSettings) }
      }
      .glassButton()
      .padding(.top, 8)

      Button("Cancel") {
        onDismiss()
      }
      .foregroundStyle(.white)
    }
  }

  // MARK: - Helpers

  private var zoomLabel: String {
    let factor = viewModel.state.currentZoomFactor
    if factor < 1 {
      return String(format: "%.1fx", factor)
    } else {
      return String(format: "%.0fx", factor)
    }
  }
}
