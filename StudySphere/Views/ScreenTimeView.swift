//
//  ScreenTimeView.swift
//  StudySphere
//
//  Created by Chris Wong on 14/3/2026.
//

import FamilyControls
import SwiftUI
import Foundation
import ManagedSettings
import VISOR

@LazyViewModel(ScreenTimeViewModel.self)
struct ScreenTimeView: View {
    @ViewBuilder
    var content: some View {
        @Bindable var viewModel = viewModel
        Button("Block apps") {
            Task {
                await viewModel.handle(.openBlockedAppsPicker)
            }
        }
        .glassButton()
        .familyActivityPicker(isPresented: $viewModel.state.isBlockedAppPickerPresented, selection: .init(get: {
            viewModel.state.blockedApps
        }, set: {
            // WEIRD BUG NEEDED TO UPDATE STATE MANUALLY
            viewModel.state.blockedApps = $0
            viewModel.screenTimeService.blockedApps = $0
            viewModel.screenTimeService.applyShields()
        }))
        Button("Stop blocking") {
            viewModel.screenTimeService.removeShields()
        }
        .glassButton()
    }
}
