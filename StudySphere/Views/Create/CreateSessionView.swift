import SwiftUI
import VISOR
import FamilyControls

@LazyViewModel(CreateSessionViewModel.self)
struct CreateSessionView: View {
  
  var content: some View {
    @Bindable var viewModel = viewModel
    
    return ScrollView {
      VStack(spacing: 24) {
        identityCard(sessionName: $viewModel.state.sessionName)
        
        focusCircleCard(
          radius: $viewModel.state.radiusMeters,
          requireStillness: $viewModel.state.requireStillness
        )
        
        appsBlockedCard(isScreenTimeAuthorized: viewModel.state.isScreenTimeAuthorized)
        
        createSessionButton(
          isCreating: viewModel.state.isCreating,
          isDisabled: viewModel.state.sessionName
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          || viewModel.state.isCreating
        )
      }
      .padding(.horizontal)
      .padding(.vertical, 24)
    }
    .navigationTitle("Create Session")
    .navigationBarTitleDisplayMode(.inline)
  }
  
    // MARK: - Identity card
  
  private func identityCard(sessionName: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("ACTIVE SIGNAL FOUND")
        .font(.caption.weight(.semibold))
        .tracking(2)
        .foregroundStyle(.secondary)
      
      TextField("Name your focus session", text: sessionName)
        .font(.title2.weight(.semibold))
        .textInputAutocapitalization(.sentences)
      
      Text("High-frequency focus for elite learners. Others join your circle from Discover when you go live.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.fill.quaternary)
    )
  }
  
    // MARK: - Focus circle card
  
  private func focusCircleCard(
    radius: Binding<Double>,
    requireStillness: Binding<Bool>
  ) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        Image(systemName: "circle.dashed.inset.filled")
          .font(.title3)
          .foregroundStyle(.tint)
        Text("FOCUS CIRCLE")
          .font(.caption.weight(.semibold))
          .tracking(2)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Radius: \(Int(radius.wrappedValue)) m")
          .font(.subheadline.weight(.medium))
        Slider(value: radius, in: 1...20, step: 1)
      }

      Toggle("Require Stillness", isOn: requireStillness)
        .font(.subheadline)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.fill.quaternary)
    )
  }
  
    // MARK: - Apps blocked card
  
  private func appsBlockedCard(isScreenTimeAuthorized: Bool) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        Image(systemName: "app.badge")
          .font(.title3)
          .foregroundStyle(.tint)
        Text("APPS BLOCKED")
          .font(.caption.weight(.semibold))
          .tracking(2)
          .foregroundStyle(.secondary)
      }
      
      if isScreenTimeAuthorized {
        let apps = viewModel.state.blockedApps.applications.count
        let cats = viewModel.state.blockedApps.categories.count
        let domains = viewModel.state.blockedApps.webDomains.count
        let total = apps + cats + domains

        VStack(alignment: .leading, spacing: 12) {
          Text("Total \(total == cats ? "blocked categories: \(total)" : "blocked \(total) items")")
            .font(.subheadline.weight(.semibold))
          Group {
            Text("Categories: \(cats)")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Button {
          Task { await viewModel.handle(.showAppSelection) }
        } label: {
          HStack {
            Text("Select Apps to Block")
              .font(.subheadline.weight(.medium))
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption.weight(.semibold))
          }
          .frame(maxWidth: .infinity)
        }
        .glassButton(prominent: false)
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text("Keep distractions out of your circle by blocking apps during the session.")
            .font(.caption)
            .foregroundStyle(.secondary)
          
          Button {
            Task { await viewModel.handle(.requestScreenTimeAuth) }
          } label: {
            HStack {
              Text("Authorize Screen Time")
                .font(.subheadline.weight(.medium))
              Spacer()
              Image(systemName: "lock.open")
                .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
          }
          .glassButton()
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(.fill.quaternary)
    )
  }
  
    // MARK: - CTA button
  
  private func createSessionButton(
    isCreating: Bool,
    isDisabled: Bool
  ) -> some View {
    Button {
      Task { await viewModel.handle(.createSession) }
    } label: {
      if isCreating {
        ProgressView()
          .frame(maxWidth: .infinity)
      } else {
        HStack(spacing: 8) {
          Image(systemName: "bolt.fill")
          Text("Create Focus Circle")
            .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
      }
    }
    .glassButton()
    .disabled(isDisabled)
  }
}
