import SwiftUI
import AppKit

// ================================================================
// DMPPWindowAutosave.swift
// cp-2026-02-16-01 — Manual window frame save/restore (beats SwiftUI autosave)
// ================================================================
//
// [WIN] Attach as .background(DMPPWindowAutosave(name: "...")) on the
// root view in a WindowGroup.
//
// Why this version:
// - SwiftUI often overrides NSWindow autosave names, so "NSWindow Frame <name>"
//   may never be created even if you call setFrameAutosaveName(...).
// - We store our OWN frame string in UserDefaults under a stable key and restore it.
// - We save on resize AND move, so position persists too.
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

        private var didBindToWindow = false
        private var observers: [NSObjectProtocol] = []

        // Our stable defaults key (NOT the system "NSWindow Frame ..." key)
        private var userDefaultsFrameKey: String { "DMPP.WindowFrame.\(autosaveName)" }

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
            guard !didBindToWindow else { return }
            didBindToWindow = true

            bind(to: window)
        }

        // MARK: - Bind + Restore + Observe

        private func bind(to window: NSWindow) {

            // 1) Minimum size guardrails
            window.minSize = desiredMinSize

            // 2) Restore our saved frame (manual, stable)
            applySavedFrame(window)

            // SwiftUI can override sizing right after first draw,
            // so re-apply a couple times.
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else { return }
                self.applySavedFrame(window)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak window] in
                guard let self, let window else { return }
                self.applySavedFrame(window)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self, weak window] in
                guard let self, let window else { return }
                self.applySavedFrame(window)
            }

            // 3) Save on resize AND move
            installObservers(for: window)
        }

        private func installObservers(for window: NSWindow) {
            let nc = NotificationCenter.default

            // Save while resizing
            observers.append(
                nc.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                    self?.persistCurrentFrame(window)
                }
            )

            observers.append(
                nc.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
                    self?.persistCurrentFrame(window)
                }
            )

            // Save while moving (this is what your current version was missing)
            observers.append(
                nc.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                    self?.persistCurrentFrame(window)
                }
            )

            // Also save when the window is about to close (belt + suspenders)
            observers.append(
                nc.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                    self?.persistCurrentFrame(window)
                }
            )
        }

        // MARK: - Save / Restore (Manual)

        private func applySavedFrame(_ window: NSWindow) {
            window.minSize = desiredMinSize

            guard let frameString = UserDefaults.standard.string(forKey: userDefaultsFrameKey),
                  let rect = NSRectFromString(frameString) as NSRect?
            else {
                return
            }

            // Don’t animate on launch.
            window.setFrame(rect, display: true)
        }

        private func persistCurrentFrame(_ window: NSWindow) {
            window.minSize = desiredMinSize

            let frameString = NSStringFromRect(window.frame)
            UserDefaults.standard.set(frameString, forKey: userDefaultsFrameKey)
        }
    }
}
