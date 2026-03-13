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
    case discover = 0
    case create = 1
    case profile = 2
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

    var id: String {
        switch self {
        case .appSelection: "appSelection"
        }
    }

    var destinationView: some View {
        switch self {
        case .appSelection:
            AppSelectionView()
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
