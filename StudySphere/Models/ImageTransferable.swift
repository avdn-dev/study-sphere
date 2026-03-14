import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Transferable type for loading images from PhotosPicker.
struct ImageTransferable: Transferable {
  let image: UIImage

  static var transferRepresentation: some TransferRepresentation {
    DataRepresentation(importedContentType: .image) { data in
      guard let image = UIImage(data: data) else {
        throw TransferError.importFailed
      }
      return Self(image: image)
    }
  }

  enum TransferError: Error {
    case importFailed
  }
}
