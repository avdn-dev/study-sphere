import SwiftUI
import VISOR

// MARK: - AppScene

enum AppScene: @MainActor NavigationScene {
    typealias Push = AppPush
    typealias Sheet = AppSheet
    typealias FullScreen = AppFullScreen
    typealias Tab = AppTab
}

// MARK: - AppTab

enum AppTab: Int, TabDestination {
    case create = 0
    case profile = 1
}

// MARK: - AppPush

enum AppPush: PushDestination {
    case placeholder

    var destinationView: some View {
        switch self {
        case .placeholder:
            EmptyView()
        }
    }
}

// MARK: - AppSheet

enum AppSheet: @MainActor SheetDestination {
    case appSelection
  case profile

    var id: String {
        switch self {
        case .appSelection: "appSelection"
        case .profile:
          "profile"
        }
    }

    var destinationView: some View {
        switch self {
        case .appSelection:
            AppSelectionView()
        case .profile:
          ProfileView()
        }
    }
}

// MARK: - AppFullScreen

enum AppFullScreen: @MainActor FullScreenDestination {
    case activeSession

    var id: String {
        switch self {
        case .activeSession: "activeSession"
        }
    }

    var destinationView: some View {
        switch self {
        case .activeSession:
            ActiveSessionView()
        }
    }
}
