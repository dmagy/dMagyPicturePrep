import SwiftUI
import AppKit

// ================================================================
// DMPPWindowAutosave.swift
// cp-2026-01-21-03 — resilient window frame restore + explicit save
//
// [WIN] Attach as .background(DMPPWindowAutosave(name: "...")) on the
// root view in a WindowGroup.
//
// Why this version:
// - Some SwiftUI layouts can override window sizing after the window appears.
// - We re-apply the saved frame on the next runloop (and again slightly later).
// - We explicitly call saveFrame(usingName:) after resize/end-resize.
// ================================================================

struct DMPPWindowAutosave: NSViewRepresentable {

    let name: String
    var minSize: NSSize = NSSize(width: 900, height: 600)

    func makeNSView(context: Context) -> NSView {
        AutosaveHostView(name: name, minSize: minSize)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No-op.
    }

    // ============================================================
    // [WIN] NSView subclass that hooks NSWindow lifecycle reliably
    // ============================================================
    private final class AutosaveHostView: NSView {

        private let autosaveName: String
        private let desiredMinSize: NSSize

        private var didApply = false
        private var observers: [NSObjectProtocol] = []

        init(name: String, minSize: NSSize) {
            self.autosaveName = name
            self.desiredMinSize = minSize
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        deinit {
            for o in observers { NotificationCenter.default.removeObserver(o) }
            observers.removeAll()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            guard !didApply else { return }
            didApply = true

            // 1) Enable autosave
            window.setFrameAutosaveName(autosaveName)

            // 2) Apply a sensible minimum size (prevents collapsing)
            window.minSize = desiredMinSize

            // 3) Restore any saved frame.
            // SwiftUI can still override sizing right after this, so we re-apply.
            applySavedFrame(window)

            // Re-apply on next runloop (after SwiftUI finishes initial layout)
            DispatchQueue.main.async { [weak window] in
                guard let window else { return }
                self.applySavedFrame(window)
            }

            // And once more very shortly after (cheap insurance)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak window] in
                guard let window else { return }
                self.applySavedFrame(window)
            }

            // 4) Explicitly save frame on resize events (so it definitely persists)
            let nc = NotificationCenter.default

            observers.append(
                nc.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                    guard let self else { return }
                    window.saveFrame(usingName: self.autosaveName)
                }
            )

            observers.append(
                nc.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
                    guard let self else { return }
                    window.saveFrame(usingName: self.autosaveName)
                }
            )
        }

        private func applySavedFrame(_ window: NSWindow) {
            // If no saved frame exists yet, setFrameUsingName returns false.
            _ = window.setFrameUsingName(autosaveName)

            // Re-assert min size (some layouts can reset constraints)
            window.minSize = desiredMinSize
        }
    }
}
