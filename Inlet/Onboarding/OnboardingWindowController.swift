//
//  OnboardingWindowController.swift
//  Inlet
//
//  Owns the setup window. It is an AppKit window hosting the SwiftUI flow, so
//  the app's menu commands can open it without an environment value.
//
//  Two ways in:
//  - First launch: `showOnFirstLaunch()` opens it once, until setup finishes.
//  - Help menu: `show()` always opens it at the first screen.
//

import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {

    /// The one controller for the app.
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private var model: OnboardingModel?
    /// The app's installed apps and saved layout. Set once at launch, so
    /// the groups step can show counts and write the choice.
    private var library: AppLibrary?
    private var layoutStore: LayoutStore?

    /// Hands over the app's shared objects. AppDelegate calls this before
    /// the first-launch check.
    func configure(library: AppLibrary, layoutStore: LayoutStore) {
        self.library = library
        self.layoutStore = layoutStore
    }

    /// Opens setup on launch, unless the user already finished it.
    static func showOnFirstLaunch() {
        guard !OnboardingModel.isCompleted else { return }
        shared.show()
    }

    /// Opens setup at its first screen. If it is already open, brings it forward.
    func show() {
        if let window, window.isVisible {
            bringToFront(window)
            return
        }

        // A new model each time, so reopening from Help starts over at Welcome.
        let model = OnboardingModel(layoutStore: layoutStore, library: library)
        model.onRequestFront = { [weak self] in
            self?.bringToFront()
        }

        let root = OnboardingView(model: model, onClose: { [weak self] in
            self?.close()
        })
        .inletAppearance()

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: OnboardingView.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Inlet Setup"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        // The SwiftUI view draws its own glass and rounded corners.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: root)
        window.center()

        self.model = model
        self.window = window
        bringToFront(window)
    }

    /// Closes the window. Called after the user finishes setup.
    func close() {
        window?.close()
    }

    private func bringToFront(_ window: NSWindow? = nil) {
        guard let target = window ?? self.window else { return }
        NSApp.activate()
        target.makeKeyAndOrderFront(nil)
    }

    /// Ends any practice hooks so the real overlay gets its hotkeys back, even
    /// if the user closes the window with the red button mid-step.
    func windowWillClose(_ notification: Notification) {
        model?.endTrial()
        model = nil
    }
}
