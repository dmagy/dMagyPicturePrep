import Foundation
import AppKit
import Combine

// ================================================================
// DMPPArchiveStore.swift
// Purpose: Owns Picture Library Folder selection, bookmark persistence,
// security-scoped access, and portable archive bootstrap.
//
// Dependencies & Effects:
// - Uses NSOpenPanel / NSAlert for user-facing folder selection.
// - Uses DMPPPortableArchiveBootstrap to create/read portable archive data.
// - Writes bookmark data to UserDefaults.
// - Publishes archiveRootURL and archiveRootStatusMessage for UI.
//
// Data Flow:
// - User chooses Picture Library Folder.
// - Store saves bookmark.
// - Store resolves bookmark and starts security-scoped access when possible.
// - Store bootstraps “dMagy Portable Archive Data” under the selected root.
//
// Section Index:
// - [ARCH] Public state and entry points
// - [ARCH-SAFE] Safe folder change flow
// - [BOOT] Portable archive bootstrap
// - [ARCH-HELPERS] Bookmark and security-scope helpers
// ================================================================

final class DMPPArchiveStore: ObservableObject {

    // ============================================================
    // MARK: - [ARCH] Published State
    // ============================================================

    @Published private(set) var archiveRootURL: URL? = nil
    @Published var archiveRootStatusMessage: String? = nil

    private let bookmarkKey = "DMPP.ArchiveRootBookmark.v1"
    private var isAccessingSecurityScopedResource = false

    init() {
        resolveBookmarkIfPresent()
    }

    deinit {
        stopAccessIfNeeded()
    }

    var hasStoredBookmark: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    var hasArchiveRoot: Bool {
        archiveRootURL != nil
    }

    // ============================================================
    // MARK: - [ARCH-SAFE] Public Folder Selection Entry Point
    // ============================================================

    func promptForArchiveRoot() {
        guard archiveRootURL != nil else {
            presentArchiveRootPicker(mode: .firstSelection)
            return
        }

        switch askWhatUserIsTryingToDo() {
        case .refreshAccess:
            presentArchiveRootPicker(mode: .refreshAccess)

        case .chooseDifferentFolder:
            presentArchiveRootPicker(mode: .chooseDifferentFolder)

        case .cancel:
            return
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

    // ============================================================
    // MARK: - [ARCH] Resolve Bookmark
    // ============================================================

    func resolveBookmarkIfPresent() {
        stopAccessIfNeeded()

        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
            DispatchQueue.main.async { self.archiveRootURL = nil }
            return
        }

        if let url = resolveBookmark(data, options: [.withSecurityScope]) {
            startSecurityScopeIfNeeded(url)
            DispatchQueue.main.async {
                self.archiveRootURL = url
                self.archiveRootStatusMessage = nil
                self.bootstrapPortableArchiveIfPossible(url)
            }
            return
        }

        if let url = resolveBookmark(data, options: []) {
            DispatchQueue.main.async {
                self.archiveRootURL = url
                self.archiveRootStatusMessage = nil
                self.bootstrapPortableArchiveIfPossible(url)
            }
            return
        }

        DispatchQueue.main.async {
            self.archiveRootURL = nil
            self.archiveRootStatusMessage = "Picture Library Folder permission needs to be reselected."
        }
    }

    // ============================================================
    // MARK: - [ARCH] Portable Archive Convenience
    // ============================================================

    var portableArchiveDataURL: URL? {
        guard let root = archiveRootURL else { return nil }
        return root.appendingPathComponent(DMPPPortableArchiveBootstrap.portableFolderName, isDirectory: true)
    }

    func openPortableArchiveDataFolderInFinder() {
        guard let url = portableArchiveDataURL else {
            DispatchQueue.main.async {
                self.archiveRootStatusMessage = "Picture Library Folder is not set."
            }
            return
        }

        NSWorkspace.shared.open(url)
    }

    // ============================================================
    // MARK: - [ARCH-SAFE] Folder Selection Flow
    // ============================================================

    private enum ArchiveRootPickerMode {
        case firstSelection
        case refreshAccess
        case chooseDifferentFolder
    }

    private enum ArchiveRootChangeChoice {
        case refreshAccess
        case chooseDifferentFolder
        case cancel
    }

    private enum MissingPortableDataChoice {
        case createNew
        case chooseDifferentFolder
        case cancel
    }

    private func presentArchiveRootPicker(mode: ArchiveRootPickerMode) {
        let previousRoot = archiveRootURL

        let panel = NSOpenPanel()
        panel.title = panelTitle(for: mode)
        panel.message = panelMessage(for: mode)
        panel.prompt = "Select"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        panel.directoryURL = archiveRootURL
            ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first

        panel.begin { [weak self] response in
            guard let self else { return }
            guard response == .OK, let selectedURL = panel.url else { return }

            let selectedIsDifferentFromPrevious = !self.urlsReferToSamePath(selectedURL, previousRoot)
            let selectedHasPortableData = self.portableArchiveDataExists(at: selectedURL)

            if previousRoot != nil,
               selectedIsDifferentFromPrevious,
               !selectedHasPortableData {

                switch self.askAboutMissingPortableArchiveData(selectedURL: selectedURL) {
                case .createNew:
                    self.commitArchiveRootSelection(selectedURL)

                case .chooseDifferentFolder:
                    self.presentArchiveRootPicker(mode: .chooseDifferentFolder)

                case .cancel:
                    return
                }

            } else {
                self.commitArchiveRootSelection(selectedURL)
            }
        }
    }

    private func commitArchiveRootSelection(_ url: URL) {
        do {
            try setArchiveRoot(url)

            DispatchQueue.main.async {
                self.archiveRootStatusMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.archiveRootStatusMessage = "Could not set Picture Library Folder: \(error.localizedDescription)"
            }
        }
    }

    private func askWhatUserIsTryingToDo() -> ArchiveRootChangeChoice {
        let alert = NSAlert()
        alert.messageText = "Changing Picture Library Folder"
        alert.informativeText = """
        dMPP uses this folder to find your pictures and store shared People, Locations, Tags, and Crop settings in “\(DMPPPortableArchiveBootstrap.portableFolderName).”

        What are you trying to do?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Refresh Access")
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .refreshAccess

        case .alertSecondButtonReturn:
            return .chooseDifferentFolder

        default:
            return .cancel
        }
    }

    private func askAboutMissingPortableArchiveData(selectedURL: URL) -> MissingPortableDataChoice {
        let alert = NSAlert()
        alert.messageText = "No portable archive data found"
        alert.informativeText = """
        This folder does not contain “\(DMPPPortableArchiveBootstrap.portableFolderName).”

        If this is a new picture library, dMPP can create it.

        If you expected your saved People, Locations, Tags, and Crop settings to appear, you may have selected the wrong folder.

        Selected folder:
        \(selectedURL.path)
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Create New Portable Archive Data")
        alert.addButton(withTitle: "Choose Different Folder")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .createNew

        case .alertSecondButtonReturn:
            return .chooseDifferentFolder

        default:
            return .cancel
        }
    }

    private func panelTitle(for mode: ArchiveRootPickerMode) -> String {
        switch mode {
        case .firstSelection:
            return "Set Picture Library Folder"
        case .refreshAccess:
            return "Refresh Picture Library Folder Access"
        case .chooseDifferentFolder:
            return "Choose Picture Library Folder"
        }
    }

    private func panelMessage(for mode: ArchiveRootPickerMode) -> String {
        switch mode {
        case .firstSelection:
            return "Select the top-level folder that contains your pictures. dMPP will store portable registry data inside it."

        case .refreshAccess:
            return "Select the same Picture Library Folder again to refresh macOS access."

        case .chooseDifferentFolder:
            return "Select the top-level folder that contains your pictures. If this folder does not already contain portable archive data, dMPP will ask before creating it."
        }
    }

    // ============================================================
    // MARK: - [ARCH] Core Set Root
    // ============================================================

    private func setArchiveRoot(_ url: URL) throws {
        stopAccessIfNeeded()

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
        bootstrapPortableArchiveIfPossible(url)
    }

    // ------------------------------------------------------------
    // [BOOT] Ensure portable archive folder structure exists under root
    // ------------------------------------------------------------

    @discardableResult
    func ensurePortableArchiveStructure(at rootURL: URL) -> Bool {
        do {
            _ = try DMPPPortableArchiveBootstrap.ensurePortableArchive(at: rootURL)
            return true
        } catch {
            DispatchQueue.main.async {
                self.archiveRootStatusMessage = "dMPP could not create its support folders inside your Picture Library Folder."
            }

            print("Portable archive bootstrap failed: \(error)")
            return false
        }
    }

    @discardableResult
    func ensurePortableArchiveStructureForCurrentRoot() -> Bool {
        guard let rootURL = archiveRootURL else {
            DispatchQueue.main.async {
                self.archiveRootStatusMessage = "Picture Library Folder is not set."
            }
            return false
        }

        return ensurePortableArchiveStructure(at: rootURL)
    }





    private func bootstrapPortableArchiveIfPossible(_ rootURL: URL) {
        // File IO off the main thread for normal bookmark restoration.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.ensurePortableArchiveStructure(at: rootURL)
        }
    }

    // ============================================================
    // MARK: - [ARCH-HELPERS] Bookmark / Security Scope / Paths
    // ============================================================

    private func resolveBookmark(_ data: Data, options: URL.BookmarkResolutionOptions) -> URL? {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

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

    private func portableArchiveDataExists(at root: URL) -> Bool {
        let portableURL = root.appendingPathComponent(
            DMPPPortableArchiveBootstrap.portableFolderName,
            isDirectory: true
        )

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: portableURL.path,
            isDirectory: &isDirectory
        )

        return exists && isDirectory.boolValue
    }

    private func urlsReferToSamePath(_ lhs: URL?, _ rhs: URL?) -> Bool {
        guard let lhs, let rhs else { return false }

        return lhs.standardizedFileURL.path == rhs.standardizedFileURL.path
    }
}
