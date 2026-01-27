import Foundation
import AppKit
import Combine

// ================================================================
// DMPPArchiveStore.swift
// cp-2026-01-18-03B — robust bookmark persistence + resolve + first-run signal
//
// [ARCH] Responsibility:
// - Let user pick an Archive Root folder.
// - Persist access via bookmark (security-scoped when possible).
// - Resolve bookmark to a URL on launch.
// - Provide a single "archiveRootURL" the rest of the app uses.
// - Provide "hasStoredBookmark" so UI knows whether to auto-prompt.
//
// Notes:
// - Some dev/non-sandbox setups can behave differently with security scope.
//   We try security-scoped first and fall back gracefully.
// ================================================================

final class DMPPArchiveStore: ObservableObject {

    // [ARCH] Published root URL once resolved.
    @Published private(set) var archiveRootURL: URL? = nil

    // [ARCH] Status / user-facing messaging hooks.
    @Published var archiveRootStatusMessage: String? = nil

    // [ARCH] UserDefaults key for the bookmark.
    private let bookmarkKey = "DMPP.ArchiveRootBookmark.v1"

    // [ARCH] Track security-scoped access so we can stop it.
    private var isAccessingSecurityScopedResource = false

    init() {
        resolveBookmarkIfPresent()
    }

    deinit {
        stopAccessIfNeeded()
    }

    // ------------------------------------------------------------
    // [ARCH] Public: whether any bookmark data exists in UserDefaults
    // (this is what we use to decide whether to auto-prompt on first run)
    // ------------------------------------------------------------
    var hasStoredBookmark: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    var hasArchiveRoot: Bool {
        archiveRootURL != nil
    }

    // ------------------------------------------------------------
    // [ARCH] Public: prompt user to select archive root folder.
    // ------------------------------------------------------------
    func promptForArchiveRoot() {
        let panel = NSOpenPanel()
        panel.title = "Set Picture Library Folder"
        panel.message = "Select the top-level folder that contains your pictures. dMPP will store portable registry data inside it."
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        // [ARCH] Start picker at current root if we have one; otherwise default to Pictures.
        panel.directoryURL = self.archiveRootURL
            ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first

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
                    self.archiveRootStatusMessage = "Could not set Picture Library Folder: \(error.localizedDescription)"
                }
            }
        }
    }

    func clearArchiveRoot() {
        stopAccessIfNeeded()
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.synchronize()

        DispatchQueue.main.async {
            self.archiveRootURL = nil
            self.archiveRootStatusMessage = nil
        }
    }

    // ------------------------------------------------------------
    // [ARCH] Resolve bookmark on startup (or after set).
    // ------------------------------------------------------------
    func resolveBookmarkIfPresent() {
        stopAccessIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            DispatchQueue.main.async { self.archiveRootURL = nil }
            return
        }

        // Try security-scoped resolve first, then fall back if needed.
        if let url = resolveBookmark(data, options: [.withSecurityScope]) {
            startSecurityScopeIfNeeded(url)
            DispatchQueue.main.async {
                self.archiveRootURL = url
                self.archiveRootStatusMessage = nil
                self.bootstrapPortableArchiveIfPossible(url)   // [BOOT]
            }
            return
        }

        if let url = resolveBookmark(data, options: []) {
            // No security scope; still usable in non-sandbox contexts.
            DispatchQueue.main.async {
                self.archiveRootURL = url
                self.archiveRootStatusMessage = nil
                self.bootstrapPortableArchiveIfPossible(url)   // [BOOT]
            }
            return
        }

        // If we get here, the bookmark is not usable.
        DispatchQueue.main.async {
            self.archiveRootURL = nil
            self.archiveRootStatusMessage = "Picture Library Folder permission needs to be reselected."
        }
    }

    // ------------------------------------------------------------
    // [ARCH] Core: set root, create bookmark, and resolve it.
    // ------------------------------------------------------------
    private func setArchiveRoot(_ url: URL) throws {
        stopAccessIfNeeded()

        // Prefer a security-scoped bookmark; fall back if environment doesn't support it cleanly.
        let bookmark: Data
        do {
            bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            bookmark = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }

        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        UserDefaults.standard.synchronize()

        resolveBookmarkIfPresent()
        bootstrapPortableArchiveIfPossible(url) // [BOOT] immediate creation after user selects root
    }

    // ------------------------------------------------------------
    // [ARCH] Convenience: portable archive folder URL (if root is set)
    // ------------------------------------------------------------
    var portableArchiveDataURL: URL? {
        guard let root = archiveRootURL else { return nil }
        return root.appendingPathComponent(DMPPPortableArchiveBootstrap.portableFolderName, isDirectory: true)
    }

    // ------------------------------------------------------------
    // [ARCH] Convenience: open portable archive folder in Finder
    // ------------------------------------------------------------
    func openPortableArchiveDataFolderInFinder() {
        guard let url = portableArchiveDataURL else {
            DispatchQueue.main.async {
                self.archiveRootStatusMessage = "Picture Library Folder is not set."
            }
            return
        }
        NSWorkspace.shared.open(url)
    }

    
    // ------------------------------------------------------------
    // [BOOT] Ensure portable archive folder structure exists under root
    // ------------------------------------------------------------
    private func bootstrapPortableArchiveIfPossible(_ rootURL: URL) {
        // File IO off the main thread.
        DispatchQueue.global(qos: .utility).async {
            do {
                _ = try DMPPPortableArchiveBootstrap.ensurePortableArchive(at: rootURL)
            } catch {
                DispatchQueue.main.async {
                    // Keep message short; details go to console.
                    self.archiveRootStatusMessage = "Creating portable archive data failed."
                    print("Portable archive bootstrap failed: \(error)")
                }
            }
        }
    }

    // ------------------------------------------------------------
    // [ARCH] Helpers
    // ------------------------------------------------------------
    private func resolveBookmark(_ data: Data, options: URL.BookmarkResolutionOptions) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            // If stale, refresh and store again using same options we resolved with.
            if isStale {
                let refreshed = try url.bookmarkData(
                    options: options.contains(.withSecurityScope) ? [.withSecurityScope] : [],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
                UserDefaults.standard.synchronize()
            }

            return url
        } catch {
            return nil
        }
    }

    private func startSecurityScopeIfNeeded(_ url: URL) {
        // Only attempt to start security scope if we resolved using security scope.
        if url.startAccessingSecurityScopedResource() {
            isAccessingSecurityScopedResource = true
        }
    }

    private func stopAccessIfNeeded() {
        if isAccessingSecurityScopedResource, let url = archiveRootURL {
            url.stopAccessingSecurityScopedResource()
        }
        isAccessingSecurityScopedResource = false
    }
}
