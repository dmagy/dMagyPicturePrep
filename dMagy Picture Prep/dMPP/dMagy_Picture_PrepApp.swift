import SwiftUI
import Foundation
import UniformTypeIdentifiers

// cp-2026-01-25-03(APP) — remove IdentityStore singleton; App owns IdentityStore instance

extension Notification.Name {
    static let dmppOpenImageURL = Notification.Name("dmppOpenImageURL")
  
    static let dmppSaveCurrentPicture = Notification.Name("dmppSaveCurrentPicture")
    static let dmppExportSelectedCrop = Notification.Name("dmppExportSelectedCrop")
    static let dmppExportSelectedCropTo = Notification.Name("dmppExportSelectedCropTo")
    static let dmppDeleteSelectedCrop = Notification.Name("dmppDeleteSelectedCrop")
    static let dmppToggleFaceBoxes = Notification.Name("dmppToggleFaceBoxes")
    static let dmppShowGettingStarted = Notification.Name("dmppShowGettingStarted")
    static let dmppShowDMPPHelp = Notification.Name("dmppShowDMPPHelp")
    static let dmppImportDMPSFlaggedReport = Notification.Name("dmppImportDMPSFlaggedReport")
}

@main
struct dMagy_Picture_PrepApp: App {

    // [APP-STORE] App-wide People/Identity store (single source of truth)
    // NOTE: App owns the instance; do NOT use a singleton.
    @StateObject private var identityStore = DMPPIdentityStore()
    @StateObject private var tagStore = DMPPTagStore()
    @StateObject private var cropStore = DMPPCropStore()
    @StateObject private var locationStore = DMPPLocationStore()
    @StateObject private var archiveStore = DMPPArchiveStore()
    @StateObject private var faceIndexStore = DMPPFaceIndexStore()
    @StateObject private var flaggedReportImportCoordinator = DMPSFlaggedReportImportCoordinator()

    var body: some Scene {

        // ============================================================
        // [APP-MAIN] Main editor window
        // ============================================================
        WindowGroup {
            DMPPArchiveRootGateView()
                .environmentObject(archiveStore)
                .environmentObject(identityStore)
                .environmentObject(tagStore)
                .environmentObject(locationStore)
                .environmentObject(cropStore)
                .environmentObject(faceIndexStore)
            
                // [WIN] Restore window frame between launches
                .background(DMPPWindowAutosave(name: "DMPP.MainWindow.v1"))
                .onOpenURL { url in
                    NotificationCenter.default.post(name: .dmppOpenImageURL, object: url)
                }
        }
        // [CMD] Attach commands at the Scene level.
        // Editor-specific commands post notifications handled by DMPPImageEditorView.
        .commands {
            CommandGroup(after: .newItem) {

  
      

                Button("Save") {
                    NotificationCenter.default.post(name: .dmppSaveCurrentPicture, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])

                Divider()

                Button("Export Selected Crop…") {
                    NotificationCenter.default.post(name: .dmppExportSelectedCrop, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command])

                Button("Export Selected Crop To…") {
                    NotificationCenter.default.post(name: .dmppExportSelectedCropTo, object: nil)
                }

                Divider()

                Button("Import dMPS Flagged Pictures Report…") {
                    NotificationCenter.default.post(name: .dmppImportDMPSFlaggedReport, object: nil)
                }

                Divider()

                Button("Change or Refresh Picture Library Folder…") {
                    archiveStore.promptForArchiveRoot()
                }

                Button("Open Portable Archive Data Folder") {
                    archiveStore.openPortableArchiveDataFolderInFinder()
                }
                .disabled(archiveStore.archiveRootURL == nil)
            }

            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Delete Selected Crop from This Picture") {
                    NotificationCenter.default.post(name: .dmppDeleteSelectedCrop, object: nil)
                }
            }

            CommandMenu("View") {
                Button("Show / Hide Face Boxes") {
                    NotificationCenter.default.post(name: .dmppToggleFaceBoxes, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .option])
            }

            CommandGroup(replacing: .help) {
                Button("dMPP Help") {
                    NotificationCenter.default.post(name: .dmppShowDMPPHelp, object: nil)
                }

                Button("Getting Started") {
                    NotificationCenter.default.post(name: .dmppShowGettingStarted, object: nil)
                }
            }
        }
        // ============================================================
        // [APP-SETTINGS] Settings window (hard-locked)
        // ============================================================
        Settings {
            DMPPSettingsLockGateView()
                .environmentObject(identityStore)
                .environmentObject(archiveStore)
                .environmentObject(tagStore)
                .environmentObject(locationStore)
                .environmentObject(cropStore)
                .environmentObject(faceIndexStore)
        }

        // ============================================================
        // [APP-GETTING-STARTED] Independent Getting Started window
        // ============================================================
        Window("Getting Started", id: "Getting-Started") {
            DMPPGettingStartedChecklistView()
                .environmentObject(archiveStore)
                .environmentObject(identityStore)
                .environmentObject(tagStore)
                .environmentObject(locationStore)
                .environmentObject(cropStore)
                .environmentObject(faceIndexStore)
              //  .background(DMPPWindowAutosave(name: "DMPP.GettingStartedWindow.v1"))
        }
        .defaultSize(width: 460, height: 760)
        Window("dMPP Help", id: "DMPP-Help") {
            DMPPHelpView()
        }

        Window("dMPS Flagged Report", id: "DMPS-Flagged-Report-Import") {
            DMPSFlaggedReportImportView()
                .environmentObject(archiveStore)
                .environmentObject(flaggedReportImportCoordinator)
        }
        .defaultSize(width: 1080, height: 720)
    }
}
// ================================================================
// [ARCH] Archive Root Gate View
// - If Picture Library Folder exists -> show editor
// - If not -> show setup screen + button to select folder
// - Configures portable registry stores once per root change
// ================================================================

private struct DMPPArchiveRootGateView: View {
    @EnvironmentObject var archiveStore: DMPPArchiveStore
    @EnvironmentObject var identityStore: DMPPIdentityStore
    @EnvironmentObject var tagStore: DMPPTagStore
    @EnvironmentObject var locationStore: DMPPLocationStore
    @EnvironmentObject var cropStore: DMPPCropStore
    @EnvironmentObject var faceIndexStore: DMPPFaceIndexStore
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @AppStorage("dmpp.settings.selectedTab")
    private var selectedSettingsTab: String = "general"
    @State private var didOpenGettingStartedThisRun: Bool = false

    @AppStorage("dmpp.gettingStarted.dismissed")
    private var gettingStartedDismissed: Bool = false


    // Track what we've configured so we don't re-run on every redraw
    @State private var lastConfiguredRootPath: String? = nil

    var body: some View {
        Group {
            if let root = archiveStore.archiveRootURL {

                DMPPImageEditorView()
                    .onAppear {
                        configureStoresIfNeeded(for: root)
                        maybeShowGettingStartedChecklist()
                    }
                    .onChange(of: archiveStore.archiveRootURL) { _, newRoot in
                        configureStoresForCurrentRoot(newRoot)
                        maybeShowGettingStartedChecklist()
                    }

            } else {

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Your Picture Library Folder")
                        .font(.title2)

                    Text("Choose the main folder for the full picture collection you plan to prepare. dMPP will save its notes, people, places, tags, and crop choices inside that folder so everything stays together.")
                        .foregroundStyle(.secondary)

                    if let msg = archiveStore.archiveRootStatusMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack(spacing: 10) {
                        Button("Select Picture Library Folder…") {
                            archiveStore.promptForArchiveRoot()
                        }

                        Button("Getting Started…") {
                            openWindow(id: "Getting-Started")
                        }
                    }
                    .padding(.top, 6)

                    Spacer()
                }
                .padding(20)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    maybeShowGettingStartedChecklist()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dmppShowGettingStarted)) { _ in
            openWindow(id: "Getting-Started")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dmppShowDMPPHelp)) { _ in
            openWindow(id: "DMPP-Help")
        }
        .onReceive(NotificationCenter.default.publisher(for: .dmppImportDMPSFlaggedReport)) { _ in
            openWindow(id: "DMPS-Flagged-Report-Import")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {

                Button {
                    selectedSettingsTab = "crops"
                    openSettings()
                } label: {
                    Image(systemName: "crop")
                }
                .help("Settings > Crops")

                Button {
                    selectedSettingsTab = "locations"
                    openSettings()
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                }
                .help("Settings > Locations")

                Button {
                    selectedSettingsTab = "people"
                    openSettings()
                } label: {
                    Image(systemName: "person.2")
                }
                .help("Settings > People")

                Button {
                    selectedSettingsTab = "tags"
                    openSettings()
                } label: {
                    Image(systemName: "tag")
                }
                .help("Settings > Tags")

                Button {
                    selectedSettingsTab = "general"
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings > General")
            }
        }
    }

    // MARK: - [GETTING-STARTED] First-run checklist display

    private func maybeShowGettingStartedChecklist() {
        guard !gettingStartedDismissed else { return }
        guard !didOpenGettingStartedThisRun else { return }

        if shouldOfferGettingStartedChecklist {
            didOpenGettingStartedThisRun = true

            DispatchQueue.main.async {
                openWindow(id: "Getting-Started")
            }
        }
    }

    private var shouldOfferGettingStartedChecklist: Bool {
        if archiveStore.archiveRootURL == nil { return true }
        if !portableArchiveDataExists { return true }
        if identityStore.peopleSortedForUI.count < 3 { return true }
        if locationStore.locations.isEmpty { return true }

        return false
    }

    private var portableArchiveDataExists: Bool {
        guard let url = archiveStore.portableArchiveDataURL else { return false }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: url.path,
            isDirectory: &isDirectory
        )

        return exists && isDirectory.boolValue
    }

    // MARK: - [CFG] Root-driven store configuration

    private func configureStoresForCurrentRoot(_ root: URL?) {
        guard let root else {
            clearStoreConfiguration()
            return
        }
        configureStoresIfNeeded(for: root)
    }

    private func configureStoresIfNeeded(for root: URL) {
        let path = root.path
        guard lastConfiguredRootPath != path else { return }

        // [BOOT] Repair required portable archive folders before stores read/write.
        _ = archiveStore.ensurePortableArchiveStructure(at: root)

        identityStore.configureForArchiveRoot(root)
        tagStore.configureForArchiveRoot(root)
        locationStore.configureForArchiveRoot(root)
        cropStore.configureForArchiveRoot(root)
        faceIndexStore.configureForArchiveRoot(root)

        lastConfiguredRootPath = path
    }

    private func clearStoreConfiguration() {
        identityStore.configureForArchiveRoot(nil)
        tagStore.configureForArchiveRoot(nil)
        locationStore.configureForArchiveRoot(nil)
        cropStore.configureForArchiveRoot(nil)
        faceIndexStore.configureForArchiveRoot(nil)

        lastConfiguredRootPath = nil
    }
}







// ================================================================
// [LOCK] Settings Lock Gate View (HARD LOCK + HEARTBEAT)
// - If another session holds a fresh lock -> block editing
// - Otherwise -> try to claim lock + show Settings UI
// - If temporary lock writing fails -> allow Settings anyway
// - Heartbeat keeps lock fresh while Settings is open when possible
// - Cleanup removes our lock on close
// ================================================================

private struct DMPPSettingsLockGateView: View {

    @EnvironmentObject var archiveStore: DMPPArchiveStore
    @EnvironmentObject var identityStore: DMPPIdentityStore

    @State private var lockBlockMessage: String? = nil
    @State private var canEnterSettings: Bool = false

    // [LOCK] Heartbeat timer for Settings lock
    @State private var settingsLockHeartbeatTimer: Timer? = nil

    // [LOCK] Session identity for this run
    private let session = DMPPSoftLockService.defaultSessionInfo()

    var body: some View {
        Group {
            if canEnterSettings {
                // [SETTINGS] Allowed: show your real Settings UI
                DMPPSettingsView()
                    .environmentObject(identityStore)
                    .onAppear {
                        // [LOCK] When Settings UI becomes visible, start heartbeat.
                        startSettingsLockHeartbeatIfPossible()
                    }
                    .onDisappear {
                        // [LOCK] Cleanup when Settings closes
                        stopSettingsLockHeartbeat()

                        if let root = archiveStore.archiveRootURL {
                            DMPPRegistryLockService.removeLock(
                                root: root,
                                resourceKey: DMPPRegistryLockService.resourceSettings,
                                sessionID: session.sessionID
                            )
                        }
                    }
            } else {
                // [SETTINGS] Blocked
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings are currently being edited")
                        .font(.title2)

                    Text(lockBlockMessage ?? "Another person may be editing shared Settings. Please try again in a moment.")
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("Tip: Coordinate so only one person changes shared Settings at a time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    HStack(spacing: 10) {
                        Button("Check Again") {
                            evaluateLockAndEnterIfPossible()
                        }
                        .keyboardShortcut(.defaultAction)

                        Button("Clear Settings Lock") {
                            clearSettingsLockForCurrentRoot()
                            evaluateLockAndEnterIfPossible()
                        }
                        .help("Use this only if Settings appears locked after dMPP was closed or restarted.")
                    }
                }
                .padding(20)
                .frame(minWidth: 700, minHeight: 360)
            }
        }
        .onAppear {
            evaluateLockAndEnterIfPossible()
        }
        .onDisappear {
            // Defensive: if the whole gate disappears, stop timers.
            stopSettingsLockHeartbeat()
        }
    }

    // ------------------------------------------------------------
    // [LOCK] Evaluate whether Settings should be accessible.
    // If accessible, CLAIM the lock immediately (hard lock behavior).
    // ------------------------------------------------------------
    private func evaluateLockAndEnterIfPossible() {
        lockBlockMessage = nil
        canEnterSettings = false

        guard let root = archiveStore.archiveRootURL else {
            lockBlockMessage = "Settings require a Picture Library Folder to be selected first."
            return
        }

        // Best-effort cleanup so we don’t block on stale sessions.
        DMPPRegistryLockService.pruneStaleLocks(
            root: root,
            resourceKey: DMPPRegistryLockService.resourceSettings
        )

        // If anyone else is actively editing Settings, HARD BLOCK.
        let others = DMPPRegistryLockService.activeOtherSessions(
            root: root,
            resourceKey: DMPPRegistryLockService.resourceSettings,
            currentSessionID: session.sessionID
        )

        if let first = others.first {
            lockBlockMessage =
                "\(first.userDisplayName) on \(first.deviceName) appears to be editing Settings right now.\n\nPlease try again later."
            canEnterSettings = false
            return
        }

        // No other active sessions: claim lock now.
        // If the temporary lock cannot be written, allow Settings anyway.
        // The lock is a coordination aid; it should not make Settings unusable.
        do {
            try DMPPRegistryLockService.upsertLock(
                root: root,
                resourceKey: DMPPRegistryLockService.resourceSettings,
                session: session
            )
            canEnterSettings = true
        } catch {
            print("Settings lock could not be claimed; opening Settings without a lock: \(error)")
            lockBlockMessage = nil
            canEnterSettings = true
        }
    }

    // ------------------------------------------------------------
    // [LOCK] Heartbeat: keep our Settings lock fresh while open
    // ------------------------------------------------------------
    private func startSettingsLockHeartbeatIfPossible() {
        stopSettingsLockHeartbeat() // restart cleanly

        guard let root = archiveStore.archiveRootURL else { return }

        settingsLockHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            do {
                try DMPPRegistryLockService.upsertLock(
                    root: root,
                    resourceKey: DMPPRegistryLockService.resourceSettings,
                    session: session
                )
            } catch {
                // Hard lock is already claimed. If heartbeat fails, don’t crash—just log.
                print("Settings lock heartbeat upsert failed: \(error)")
            }
        }

        // Ensure timer runs during common UI interactions.
        if let t = settingsLockHeartbeatTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func stopSettingsLockHeartbeat() {
        settingsLockHeartbeatTimer?.invalidate()
        settingsLockHeartbeatTimer = nil
    }
    
    private func clearSettingsLockForCurrentRoot() {
        guard let root = archiveStore.archiveRootURL else { return }

        DMPPRegistryLockService.removeLock(
            root: root,
            resourceKey: DMPPRegistryLockService.resourceSettings,
            sessionID: session.sessionID
        )

        // If the blocker was created by a previous app run, our current session ID
        // will not match it. This is a temporary developer escape hatch until the
        // registry lock service exposes a safe stale-lock clearing method.
        DMPPRegistryLockService.pruneStaleLocks(
            root: root,
            resourceKey: DMPPRegistryLockService.resourceSettings,
            freshMinutes: 0
        )
    }
    
}
