import NearbyInteraction
import OSLog
import SwiftData
import SwiftUI
import VISOR

@main
struct StudySphereApp: App {

    // MARK: Lifecycle

    init() {
        print("NI supported:", NISession.deviceCapabilities.supportsPreciseDistanceMeasurement)
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
        let audioService = LiveAudioService()

        // 3. Create services (continued) & interactors
        let studySessionService = LiveStudySessionService(
            multipeerService: multipeerService,
            nearbyInteractionService: nearbyInteractionService,
            profileService: profileService
        )
        let sessionInteractor = LiveSessionInteractor(
            multipeerService: multipeerService,
            nearbyInteractionService: nearbyInteractionService,
            motionService: motionService,
            screenTimeService: screenTimeService,
            profileService: profileService,
            permissionsService: permissionService,
            studySessionService: studySessionService)
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
        router.selectedTab = .focus

        // 5. Create ViewModel factories
        let mainTabViewModelFactory = MainTabViewModel.Factory {
            MainTabViewModel(router: router)
        }
        let discoverViewModelFactory: DiscoverViewModel.Factory = .routed { router in
            DiscoverViewModel(
                router: router,
                multipeerService: multipeerService,
                studySessionService: studySessionService,
                profileService: profileService)
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
        let sessionAnalyticsViewModelFactory = SessionAnalyticsViewModel.Factory {
            SessionAnalyticsViewModel(profileService: profileService)
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
        let profileCameraViewModelFactory = ProfileCameraViewModel.Factory {
            ProfileCameraViewModel()
        }

        // 6. Assign to @State properties
        _router = State(initialValue: router)
        _mainTabViewModelFactory = State(initialValue: mainTabViewModelFactory)
        _discoverViewModelFactory = State(initialValue: discoverViewModelFactory)
        _createSessionViewModelFactory = State(initialValue: createSessionViewModelFactory)
        _activeSessionViewModelFactory = State(initialValue: activeSessionViewModelFactory)
        _profileViewModelFactory = State(initialValue: profileViewModelFactory)
        _sessionAnalyticsViewModelFactory = State(initialValue: sessionAnalyticsViewModelFactory)
        _appSelectionViewModelFactory = State(initialValue: appSelectionViewModelFactory)
        _profileService = State(initialValue: profileService)
        _screenTimeViewModelFactory = State(initialValue: screenTimeViewModelFactory)
        _profileCameraViewModelFactory = State(initialValue: profileCameraViewModelFactory)
        _sessionInteractor = State(initialValue: sessionInteractor)
    }

    // MARK: Internal

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(router)
                .environment(mainTabViewModelFactory)
                .environment(discoverViewModelFactory)
                .environment(createSessionViewModelFactory)
                .environment(activeSessionViewModelFactory)
                .environment(profileViewModelFactory)
                .environment(sessionAnalyticsViewModelFactory)
                .environment(appSelectionViewModelFactory)
                .environment(screenTimeViewModelFactory)
                .environment(profileCameraViewModelFactory)
                .environment(profileService)
                .preferredColorScheme(.dark)
                .task { profileService.load() }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        sessionInteractor.handleAppDidEnterBackground()
                    case .active:
                        sessionInteractor.handleAppWillEnterForeground()
                    default:
                        break
                    }
                }
        }
    }

    // MARK: Private

    @State private var router: Router<AppScene>
    @State private var mainTabViewModelFactory: MainTabViewModel.Factory
    @State private var discoverViewModelFactory: DiscoverViewModel.Factory
    @State private var createSessionViewModelFactory: CreateSessionViewModel.Factory
    @State private var activeSessionViewModelFactory: ActiveSessionViewModel.Factory
    @State private var profileViewModelFactory: ProfileViewModel.Factory
    @State private var sessionAnalyticsViewModelFactory: SessionAnalyticsViewModel.Factory
    @State private var appSelectionViewModelFactory: AppSelectionViewModel.Factory
    @State private var profileService: LiveProfileService
    @State private var screenTimeViewModelFactory: ScreenTimeViewModel.Factory
    @State private var profileCameraViewModelFactory: ProfileCameraViewModel.Factory
    @State private var sessionInteractor: LiveSessionInteractor
}
