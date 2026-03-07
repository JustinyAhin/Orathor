//
//  OrathorApp.swift
//  Orathor
//
//  Created by Justin Ahinon on 06/03/2026.
//

import Sparkle
import SwiftUI

@main
struct OrathorApp: App {
    @State private var viewModel = TranscriptionViewModel()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        MenuBarExtra("Orathor", systemImage: "waveform") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Orathor", id: "main") {
            MainWindowView(viewModel: viewModel)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(
                    viewModel: CheckForUpdatesViewModel(
                        updater: updaterController.updater
                    ),
                    updater: updaterController.updater
                )
            }
        }
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject var viewModel: CheckForUpdatesViewModel
    let updater: SPUUpdater

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}
