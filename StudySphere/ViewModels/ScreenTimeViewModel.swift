//
//  ScreenTimeViewModel.swift
//  StudySphere
//
//  Created by Chris Wong on 14/3/2026.
//

@preconcurrency import FamilyControls
import SwiftUI
import Foundation
import ManagedSettings
import VISOR

@ViewModel
@Observable
final class ScreenTimeViewModel {
    let screenTimeService: ScreenTimeService
    let permissionsService: PermissionsService
    
    struct State: Equatable {
        @Bound(\ScreenTimeViewModel.screenTimeService) var blockedApps: FamilyActivitySelection = .init()
        var isBlockedAppPickerPresented = false
    }
    
    enum Action {
        case openBlockedAppsPicker
    }
    
    func handle(_ action: Action) async {
        switch action {
        case .openBlockedAppsPicker:
            do {
                try await permissionsService.requestScreenTimesPermission()
                updateState(\.isBlockedAppPickerPresented, to: true)
            } catch {
                fatalError("Failed to request screen time permission: \(error)")
            }
        }
    }
    
    var state = State()
}
