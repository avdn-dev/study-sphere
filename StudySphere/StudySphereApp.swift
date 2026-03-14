import OSLog
import SwiftData
import SwiftUI
import VISOR

@main
struct StudySphereApp: App {

    // MARK: Lifecycle

    init() {
        // 1. SwiftData container and context for profile/session history
        let schema = Schema([SessionHistoryEntryRecord.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        let modelContext = ModelContext(modelContainer)

        // 2. Create services
        let profileService = LiveProfileService(modelContext: modelContext)
        profileService.load()
        let multipeerService = LiveMultipeerService(peerID: profileService.peerID!)
        let nearbyInteractionService = LiveNearbyInteractionService()
        let motionService = LiveMotionService()
        let screenTimeService = LiveScreenTimeService()
        let permissionService = LivePermissionService()

        // 3. Create interactors
        let sessionInteractor = LiveSessionInteractor(
            multipeerService: multipeerService,
            nearbyInteractionService: nearbyInteractionService,
            motionService: motionService,
            screenTimeService: screenTimeService,
            profileService: profileService,
            permissionsService: permissionService)
        let distractionInteractor = LiveDistractionInteractor(
            motionService: motionService,
            screenTimeService: screenTimeService,
            nearbyInteractionService: nearbyInteractionService,
            profileService: profileService)

        // 4. Create root router
        let router = Router<AppScene>(
            level: 0,
            identifierTab: nil,
            logger: Logger(subsystem: "studio.cgc.StudySphere", category: "Router"))
        router.selectedTab = .discover

        // 5. Create ViewModel factories
        let mainTabViewModelFactory = MainTabViewModel.Factory {
            MainTabViewModel(router: router)
        }
        let discoverViewModelFactory: DiscoverViewModel.Factory = .routed { router in
            DiscoverViewModel(
                router: router,
                multipeerService: multipeerService,
                sessionInteractor: sessionInteractor)
        }
        let createSessionViewModelFactory: CreateSessionViewModel.Factory = .routed { router in
            CreateSessionViewModel(
                router: router,
                sessionInteractor: sessionInteractor)
        }
        let activeSessionViewModelFactory: ActiveSessionViewModel.Factory = .routed { router in
            ActiveSessionViewModel(
                router: router,
                sessionInteractor: sessionInteractor,
                distractionInteractor: distractionInteractor,
                nearbyInteractionService: nearbyInteractionService)
        }
        let profileViewModelFactory = ProfileViewModel.Factory {
            ProfileViewModel(profileService: profileService)
        }
        let appSelectionViewModelFactory: AppSelectionViewModel.Factory = .routed { router in
            AppSelectionViewModel(
                router: router,
                screenTimeService: screenTimeService,
                permissionsService: permissionService
            )
        }
        let screenTimeViewModelFactory = ScreenTimeViewModel.Factory {
            ScreenTimeViewModel(screenTimeService: screenTimeService, permissionsService: permissionService)
        }

        // 6. Assign to @State properties
        _router = State(initialValue: router)
        _mainTabViewModelFactory = State(initialValue: mainTabViewModelFactory)
        _discoverViewModelFactory = State(initialValue: discoverViewModelFactory)
        _createSessionViewModelFactory = State(initialValue: createSessionViewModelFactory)
        _activeSessionViewModelFactory = State(initialValue: activeSessionViewModelFactory)
        _profileViewModelFactory = State(initialValue: profileViewModelFactory)
        _appSelectionViewModelFactory = State(initialValue: appSelectionViewModelFactory)
        _profileService = State(initialValue: profileService)
        _screenTimeViewModelFactory = State(initialValue: screenTimeViewModelFactory)
    }

    // MARK: Internal

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(router)
                .environment(mainTabViewModelFactory)
                .environment(discoverViewModelFactory)
                .environment(createSessionViewModelFactory)
                .environment(activeSessionViewModelFactory)
                .environment(profileViewModelFactory)
                .environment(appSelectionViewModelFactory)
                .environment(screenTimeViewModelFactory)
                .task { profileService.load() }
        }
    }

    // MARK: Private

    @State private var router: Router<AppScene>
    @State private var mainTabViewModelFactory: MainTabViewModel.Factory
    @State private var discoverViewModelFactory: DiscoverViewModel.Factory
    @State private var createSessionViewModelFactory: CreateSessionViewModel.Factory
    @State private var activeSessionViewModelFactory: ActiveSessionViewModel.Factory
    @State private var profileViewModelFactory: ProfileViewModel.Factory
    @State private var appSelectionViewModelFactory: AppSelectionViewModel.Factory
    @State private var profileService: LiveProfileService
    @State private var screenTimeViewModelFactory: ScreenTimeViewModel.Factory
}
