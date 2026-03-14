import SwiftUI

extension View {
    /// Applies Liquid Glass on iOS 26+ with fallback to bordered button styles on earlier versions.
    func glassButton(prominent: Bool = true) -> some View {
        modifier(GlassButtonModifier(prominent: prominent))
    }
}

private struct GlassButtonModifier: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
          if prominent {
            content
              .buttonStyle(.glassProminent)
          } else{
            content
              .buttonStyle(.glass)
          }
        } else if prominent {
            content
                .buttonStyle(.borderedProminent)
        } else {
            content
                .buttonStyle(.bordered)
        }
    }
}
