//
//  OrathorApp.swift
//  Orathor
//
//  Created by Justin Ahinon on 06/03/2026.
//

import Sparkle
import SwiftUI

private let sparkleController: SPUStandardUpdaterController = {
    UserDefaults.standard.register(defaults: ["SUEnableAutomaticChecks": true])
    return SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
}()

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var showInDock: Bool {
        UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            showMainWindow()
        }
        return true
    }

    private func showMainWindow() {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        }
        if let window = NSApp.windows.first(where: { $0.canBecomeMain && !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard showInDock,
              let window = notification.object as? NSWindow,
              window.canBecomeMain, !(window is NSPanel) else { return }
        DispatchQueue.main.async {
            let hasMainWindows = NSApp.windows.contains {
                $0.isVisible && $0.canBecomeMain && !($0 is NSPanel)
            }
            if !hasMainWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}

@main
struct OrathorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = TranscriptionViewModel()

    #if DEBUG
    private static let devMenuBarIcon: NSImage = {
        let palette = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
        let size = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let config = palette.applying(size)
        let image = NSImage(systemSymbolName: "waveform.badge.exclamationmark", accessibilityDescription: "Orathor Dev")!
            .withSymbolConfiguration(config)!
        image.isTemplate = false
        return image
    }()
    #endif

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            #if DEBUG
            Image(nsImage: Self.devMenuBarIcon)
            #else
            Image(systemName: "waveform")
            #endif
        }
        .menuBarExtraStyle(.window)

        Window("Orathor", id: "main") {
            MainWindowView(viewModel: viewModel, updater: sparkleController.updater)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(
                    viewModel: CheckForUpdatesViewModel(
                        updater: sparkleController.updater
                    ),
                    updater: sparkleController.updater
                )
            }
            CommandGroup(replacing: .help) {}
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
