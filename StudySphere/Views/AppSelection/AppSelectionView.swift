import FamilyControls
import SwiftUI
import Foundation
import ManagedSettings
import VISOR

@LazyViewModel(AppSelectionViewModel.self)
struct AppSelectionView: View {

  @Environment(\.dismiss) var dismiss

    @ViewBuilder
    var content: some View {
      @Bindable var viewModel = viewModel
      NavigationStack {
        VStack {
            if viewModel.state.isScreenTimeAuthorized {
              FamilyActivityPicker(selection:
                  .init(get: {
                viewModel.state.blockedApps
              }, set: {
                  // WEIRD BUG NEEDED TO UPDATE STATE MANUALLY
                viewModel.state.blockedApps = $0
                viewModel.screenTimeService.blockedApps = $0
                viewModel.screenTimeService.applyShields()
              }))
              
            } else {
                ContentUnavailableView(
                    "Screen Time Not Authorized",
                    systemImage: "lock.shield",
                    description: Text("Please authorize Screen Time access to select apps to block."))
            }
        }
        .navigationTitle("Select Apps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()

                }
            }
        }
        Button("Reset") {
          viewModel.screenTimeService.removeShields()
        }
        .glassButton()
      }
    }
}

