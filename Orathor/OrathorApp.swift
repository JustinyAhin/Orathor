//
//  OrathorApp.swift
//  Orathor
//
//  Created by Justin Ahinon on 06/03/2026.
//

import SwiftUI

@main
struct OrathorApp: App {
    @State private var viewModel = TranscriptionViewModel()

    var body: some Scene {
        MenuBarExtra("Orathor", systemImage: "waveform") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
