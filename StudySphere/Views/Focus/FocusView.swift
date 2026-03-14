import SwiftUI
import VISOR

struct FocusView: View {

    @Environment(Router<AppScene>.self) private var router

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.8))

                Text("Ready to Focus?")
                    .font(.title)
                    .bold()
                    .foregroundStyle(.white)

                Text("Start a session or join one nearby")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(spacing: 20) {
                Button {
                    router.present(sheet: .createSession)
                } label: {
                    Label("Start a new session", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.white.opacity(0.2))
                    Text("OR")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.white.opacity(0.2))
                }

                Button {
                    router.present(sheet: .discover)
                } label: {
                    Label("Join an existing session", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.04, green: 0.09, blue: 0.16))
        .navigationTitle("Focus")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            Button("Profile", systemImage: "person.crop.circle.fill") {
                router.present(sheet: .profile)
            }
        }
    }
}
