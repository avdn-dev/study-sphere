//
//  BlockedAppViewModel.swift
//  StudySphere
//
//  Created by Yanlin Li  on 15/3/2026.
//

import Foundation
import VISOR
import FamilyControls

@Observable
@ViewModel
final class BlockedAppViewModel {
  
  struct State: Equatable {
    @Bound(\BlockedAppViewModel.screenTimeService) var blockedApps: FamilyActivitySelection = .init()
  }
  
  var state = State()

  
    // MARK: - Private
  
  private let router: Router<AppScene>
  let screenTimeService: any ScreenTimeService
  let permissionsService: any PermissionsService
}
