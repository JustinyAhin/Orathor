//
//  OrathorApp.swift
//  Orathor
//
//  Created by Justin Ahinon on 06/03/2026.
//

import SwiftUI

#if !SETAPP
import Sparkle

private let updateController: AppUpdateController = {
    UserDefaults.standard.register(defaults: ["SUEnableAutomaticChecks": true])
    let sparkleController = SPUStandardUpdaterController(
        startingUpdater: !AppRuntime.isRunningTests && !AppRuntime.isDebugBuild,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    return AppUpdateController(updater: sparkleController.updater)
}()
#else
private let updateController = AppUpdateController()
#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var showInDock: Bool {
        AppPreferences.shared.object(forKey: "showInDock") as? Bool ?? false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !AppRuntime.isRunningTests else { return }
        SetappDistribution.configure()
        DiagnosticLogger.shared.logSessionStart()

        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

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
            MainWindowView(viewModel: viewModel, updater: updateController)
        }
        .defaultSize(width: 800, height: 600)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands {
            #if !SETAPP
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updateController)
            }
            #endif
            CommandGroup(replacing: .help) {}
        }

        Window("Welcome to Orathor", id: "onboarding") {
            OnboardingView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(
            AppPreferences.shared.bool(forKey: "hasCompletedOnboarding") ? .suppressed : .presented
        )
        .restorationBehavior(.disabled)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject var updater: AppUpdateController

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!updater.canCheckForUpdates)
    }
}
