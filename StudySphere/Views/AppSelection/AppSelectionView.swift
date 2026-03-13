import FamilyControls
import SwiftUI
import VISOR

@LazyViewModel(AppSelectionViewModel.self)
struct AppSelectionView: View {

    @State private var selection = FamilyActivitySelection()

    var content: some View {
        NavigationStack {
            VStack {
                if viewModel.state.isAuthorized {
                    FamilyActivityPicker(selection: $selection)
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
                        Task { await viewModel.handle(.done) }
                    }
                }
            }
        }
    }
}

