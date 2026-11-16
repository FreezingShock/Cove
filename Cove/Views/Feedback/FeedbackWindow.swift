//
//  FeedbackWindow.swift
//  Cove
//
//  Shows the Send Feedback window from Help > Send Feedback…
//  A plain AppKit window hosts the SwiftUI view, so the menu command
//  doesn't need an openWindow environment value.
//

import AppKit
import SwiftUI

final class FeedbackWindow {
    static let shared = FeedbackWindow()

    private var window: NSWindow?

    private init() {}

    /// Opens the window, creating it the first time. Brings it forward
    /// if it's already open.
    func show() {
        if window == nil {
            let controller = NSHostingController(rootView: FeedbackView())
            let window = NSWindow(contentViewController: controller)
            window.title = "Send Feedback"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 520, height: 640))
            window.center()
            self.window = window
        }

        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
