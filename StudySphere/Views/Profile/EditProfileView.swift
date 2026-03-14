import PhotosUI
import SwiftUI
import UIKit
import VISOR

@LazyViewModel(ProfileViewModel.self)
struct EditProfileView: View {
    var onDismiss: () -> Void

    @State private var editedName: String = ""
    @State private var selectedImage: UIImage?
    @State private var showingPhotoOptions = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoFlow: PhotoFlow?

    var content: some View {
        List {
            Section {
                Button {
                    showingPhotoOptions = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarPreviewView

                            Image(systemName: "camera.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(.tint, in: Circle())
                                .offset(x: 2, y: 2)
                        }

                        Text("Change Photo")
                            .font(.footnote)
                            .foregroundStyle(.tint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .glassButton()
                .listRowBackground(Color.clear)
            }

            Section("Name") {
                TextField("Name", text: $editedName)
            }

            Section {
                Button {
                    Task {
                        await viewModel.handle(.updateName(editedName))
                        if selectedImage != nil {
                            await viewModel.handle(.updateProfileImage(selectedImage))
                        }
                        onDismiss()
                    }
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .glassButton()
                .disabled(
                    editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || (!hasNameChange && !hasImageChange)
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let name = viewModel.state.profile?.name {
                editedName = name
            }
        }
        .task {
            await viewModel.handle(.loadProfile)
            editedName = viewModel.state.profile?.name ?? "Student"
        }
        .confirmationDialog("Change Photo", isPresented: $showingPhotoOptions) {
            Button("Choose from Library") {
                showingPhotoPicker = true
            }
            Button("Take Photo") {
                photoFlow = .camera
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let transferable = try? await item.loadTransferable(type: ImageTransferable.self) {
                    photoFlow = .crop(transferable.image)
                }
                selectedPhotoItem = nil
            }
        }
        .fullScreenCover(item: $photoFlow) { flow in
            switch flow {
            case .camera:
                ProfileCameraView(
                    onPhotoCaptured: { image in
                        photoFlow = .crop(image)
                    },
                    onDismiss: { photoFlow = nil }
                )
            case .crop(let image):
                PhotoCropView(
                    image: image,
                    onCropped: { cropped in
                        selectedImage = cropped
                        photoFlow = nil
                    },
                    onCancel: { photoFlow = nil }
                )
            }
        }
    }

    @ViewBuilder
    private var avatarPreviewView: some View {
        if let image = selectedImage ?? viewModel.state.profileImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.secondary)
        }
    }

    private var hasNameChange: Bool {
        editedName != (viewModel.state.profile?.name ?? "Student")
    }

    private var hasImageChange: Bool {
        selectedImage != nil
    }
}

// MARK: - PhotoFlow

extension EditProfileView {
    enum PhotoFlow: Identifiable {
        case camera
        case crop(UIImage)

        var id: String { "photoFlow" }
    }
}
