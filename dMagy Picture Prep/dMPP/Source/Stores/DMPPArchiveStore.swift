import Foundation
import AppKit
import Combine

// ================================================================
// DMPPArchiveStore.swift
// cp-2026-01-18-03A — archive root selection + bookmark persistence (fixes Combine + actor issues)
//
// [ARCH] Responsibility:
// - Let user pick an Archive Root folder (once).
// - Persist access via security-scoped bookmark (works with sandbox).
// - Resolve bookmark to a URL on launch.
// - Provide a single "archiveRootURL" the rest of the app uses.
// - Caller can bootstrap portable archive data after selection/resolve.
// ================================================================

final class DMPPArchiveStore: ObservableObject {

    // [ARCH] Published root URL once resolved.
    @Published private(set) var archiveRootURL: URL? = nil

    // [ARCH] Status / user-facing messaging hooks.
    @Published var archiveRootStatusMessage: String? = nil

    // [ARCH] UserDefaults key for the security-scoped bookmark.
    private let bookmarkKey = "DMPP.ArchiveRootBookmark.v1"

    // [ARCH] Track security-scoped access so we can stop it.
    private var isAccessingSecurityScopedResource = false

    init() {
        // Attempt to resolve bookmark immediately on app launch.
        // If it fails, UI can prompt user to select root.
        resolveBookmarkIfPresent()
    }

    deinit {
        // deinit is nonisolated; keep cleanup non-actor to avoid warnings/errors.
        stopAccessIfNeeded()
    }

    // ------------------------------------------------------------
    // [ARCH] Public: do we already have a root?
    // ------------------------------------------------------------
    var hasArchiveRoot: Bool {
        archiveRootURL != nil
    }

    // ------------------------------------------------------------
    // [ARCH] Public: prompt user to select archive root folder.
    // ------------------------------------------------------------
    func promptForArchiveRoot() {
        let panel = NSOpenPanel()
        panel.title = "Choose Your Photo Archive Root"
        panel.message = "Select the top-level folder that contains your photo archive. dMPP will store portable registry data inside it."
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        // Optional nicety: try to start in Pictures
        panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first

        panel.begin { [weak self] response in
            guard let self else { return }
            guard response == .OK, let url = panel.url else { return }

            do {
                try self.setArchiveRoot(url)
                DispatchQueue.main.async {
                    self.archiveRootStatusMessage = nil
                }
            } catch {
                DispatchQueue.main.async {
                    self.archiveRootStatusMessage = "Could not set Archive Root: \(error.localizedDescription)"
                }
            }
        }
    }

    // ------------------------------------------------------------
    // [ARCH] Optional: clear root + bookmark (for troubleshooting).
    // ------------------------------------------------------------
    func clearArchiveRoot() {
        stopAccessIfNeeded()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        DispatchQueue.main.async {
            self.archiveRootURL = nil
        }
    }

    // ------------------------------------------------------------
    // [ARCH] Resolve bookmark on startup (or after set).
    // ------------------------------------------------------------
    func resolveBookmarkIfPresent() {
        stopAccessIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            DispatchQueue.main.async {
                self.archiveRootURL = nil
            }
            return
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                // Re-save bookmark if stale.
                let refreshed = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            }

            // Start security-scoped access (required for sandbox).
            if url.startAccessingSecurityScopedResource() {
                isAccessingSecurityScopedResource = true
            }

            DispatchQueue.main.async {
                self.archiveRootURL = url
            }

        } catch {
            DispatchQueue.main.async {
                self.archiveRootURL = nil
                self.archiveRootStatusMessage = "Archive Root permission needs to be reselected."
            }
        }
    }

    // ------------------------------------------------------------
    // [ARCH] Core: set root, create bookmark, and resolve it.
    // ------------------------------------------------------------
    private func setArchiveRoot(_ url: URL) throws {
        // Stop any previous access.
        stopAccessIfNeeded()

        // Create security-scoped bookmark (safe even if not sandboxed).
        let bookmark = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)

        // Resolve immediately to confirm it works.
        resolveBookmarkIfPresent()
    }

    // ------------------------------------------------------------
    // [ARCH] Cleanup
    // ------------------------------------------------------------
    private func stopAccessIfNeeded() {
        if isAccessingSecurityScopedResource, let url = archiveRootURL {
            url.stopAccessingSecurityScopedResource()
        }
        isAccessingSecurityScopedResource = false
    }
}
