//
//  EditProfileView.swift
//  StudySphere
//
//  Created by Yanlin Li  on 14/3/2026.
//

import SwiftUI
import UIKit
import VISOR

@LazyViewModel(ProfileViewModel.self)
struct EditProfileView: View {
    var onDismiss: () -> Void

    @State private var editedName: String = "Student"
    @State private var selectedImage: UIImage?

    var content: some View {
        List {
            Section {
                Button {
                    // Scaffold: connect your image picker / PHPickerViewController here.
                    // When the user picks an image, set `selectedImage = chosenImage`.
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
                .buttonStyle(.plain)
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
                .buttonStyle(.borderedProminent)
                .disabled(
                    editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || (!hasNameChange && !hasImageChange)
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Edit Profile")
        .task {
            await viewModel.handle(.loadProfile)
            editedName = viewModel.state.profile?.name ?? "Student"
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
            Image(systemName: "person.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.secondary)
        }
    }

    private var hasNameChange: Bool {
        editedName != (viewModel.state.profile?.name ?? "Student")
    }

    /// True when the user has picked an image in this session (scaffold: set when your picker returns).
    private var hasImageChange: Bool {
        selectedImage != nil
    }
}
