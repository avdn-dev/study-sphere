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
        Button("Request Permission") {
            
        }
        Button("Block apps") {
            Task {
                await viewModel.handle(.openBlockedAppsPicker)
            }
        }
        .familyActivityPicker(isPresented: $viewModel.state.isBlockedAppPickerPresented, selection: .init(get: {
            viewModel.state.blockedApps
        }, set: {
            viewModel.screenTimeService.blockedApps = $0
        }))
    }
}
