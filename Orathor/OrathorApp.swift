//
//  OrathorApp.swift
//  Orathor
//
//  Created by Justin Ahinon on 06/03/2026.
//

import SwiftUI

@main
struct OrathorApp: App {
    var body: some Scene {
        MenuBarExtra("Orathor", systemImage: "mic.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}
