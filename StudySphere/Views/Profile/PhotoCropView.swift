import SwiftUI

/// Interactive circle crop view for profile photos.
/// Displays the image behind a circular mask with drag and pinch-to-zoom gestures.
struct PhotoCropView: View {
  let image: UIImage
  let onCropped: (UIImage) -> Void
  let onCancel: () -> Void

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var cropDiameter: CGFloat = 0

  var body: some View {
    NavigationStack {
      GeometryReader { geo in
        let diameter = max(min(geo.size.width, geo.size.height) - 48, 1)

        ZStack {
          Color.black.ignoresSafeArea()

          Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .offset(offset)
            .clipShape(Circle())
            .overlay(
              Circle()
                .strokeBorder(.white.opacity(0.6), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .gesture(magnifyGesture)
        .onAppear { cropDiameter = diameter }
      }
      .navigationTitle("Crop Photo")
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { onCancel() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Use Photo") {
            onCropped(performCrop())
          }
          .bold()
        }
      }
    }
  }

  // MARK: - Gestures

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        offset = CGSize(
          width: lastOffset.width + value.translation.width,
          height: lastOffset.height + value.translation.height
        )
      }
      .onEnded { _ in
        lastOffset = offset
      }
  }

  private var magnifyGesture: some Gesture {
    MagnifyGesture()
      .onChanged { value in
        scale = max(1.0, lastScale * value.magnification)
      }
      .onEnded { value in
        scale = max(1.0, lastScale * value.magnification)
        lastScale = scale
      }
  }

  // MARK: - Crop

  private func performCrop() -> UIImage {
    let normalized = normalizeOrientation(image)
    let imgSize = normalized.size
    let aspect = imgSize.width / imgSize.height

    // Base rendered size (scaledToFill in cropDiameter x cropDiameter)
    let renderedW: CGFloat
    let renderedH: CGFloat
    if aspect >= 1 {
      renderedW = cropDiameter * aspect
      renderedH = cropDiameter
    } else {
      renderedW = cropDiameter
      renderedH = cropDiameter / aspect
    }

    // After user scale
    let displayW = renderedW * scale
    let displayH = renderedH * scale

    // Crop center in display coordinates (origin = top-left of displayed image)
    let cropCenterX = displayW / 2 - offset.width
    let cropCenterY = displayH / 2 - offset.height

    // Crop rect in display coordinates
    let cropX = cropCenterX - cropDiameter / 2
    let cropY = cropCenterY - cropDiameter / 2

    // Convert to pixel coordinates
    let pxPerPtX = imgSize.width / displayW
    let pxPerPtY = imgSize.height / displayH

    var pixelRect = CGRect(
      x: cropX * pxPerPtX,
      y: cropY * pxPerPtY,
      width: cropDiameter * pxPerPtX,
      height: cropDiameter * pxPerPtY
    )

    // Clamp to image bounds
    pixelRect = pixelRect.intersection(CGRect(origin: .zero, size: imgSize))

    guard !pixelRect.isEmpty,
          let cgImage = normalized.cgImage?.cropping(to: pixelRect)
    else {
      return normalized
    }

    // Resize to 400x400
    let outputSize: CGFloat = 400
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
    return renderer.image { _ in
      UIImage(cgImage: cgImage).draw(
        in: CGRect(origin: .zero, size: CGSize(width: outputSize, height: outputSize)))
    }
  }

  private func normalizeOrientation(_ img: UIImage) -> UIImage {
    guard img.imageOrientation != .up else { return img }
    let renderer = UIGraphicsImageRenderer(size: img.size)
    return renderer.image { _ in img.draw(at: .zero) }
  }
}
