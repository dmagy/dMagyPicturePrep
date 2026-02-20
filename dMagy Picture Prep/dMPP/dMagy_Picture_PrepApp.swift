import SwiftUI
import Foundation

// cp-2026-01-25-03(APP) — remove IdentityStore singleton; App owns IdentityStore instance

@main
struct dMagy_Picture_PrepApp: App {

    // [APP-STORE] App-wide People/Identity store (single source of truth)
    // NOTE: App owns the instance; do NOT use a singleton.
    @StateObject private var identityStore = DMPPIdentityStore()
    @StateObject private var tagStore = DMPPTagStore()
    @StateObject private var cropStore = DMPPCropStore()
    @StateObject private var locationStore = DMPPLocationStore()


    // [ARCH] Picture Library Folder store (bookmark + selection)
    @StateObject private var archiveStore = DMPPArchiveStore()

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
                // [WIN] Restore window frame between launches
                .background(DMPPWindowAutosave(name: "DMPP.MainWindow.v1"))
        }
        // [CMD] Attach commands at the Scene level (applies to main window)
        .commands {
            CommandGroup(after: .newItem) {

                Button("Select Picture Library Folder…") {
                    archiveStore.promptForArchiveRoot()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("Open Portable Archive Data Folder") {
                    archiveStore.openPortableArchiveDataFolderInFinder()
                }
                .disabled(archiveStore.archiveRootURL == nil)
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
        }




   
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

    // Track what we've configured so we don't re-run on every redraw
    @State private var lastConfiguredRootPath: String? = nil

    var body: some View {
        Group {
            if let root = archiveStore.archiveRootURL {

                DMPPImageEditorView()
                    .onAppear {
                        configureStoresIfNeeded(for: root)
                    }
                    .onChange(of: archiveStore.archiveRootURL) { _, newRoot in
                        configureStoresForCurrentRoot(newRoot)
                    }

            } else {

                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Your Picture Library Folder")
                        .font(.title2)

                    Text("dMPP needs one top-level folder that contains your pictures. Portable registry data will be stored inside it.")
                        .foregroundStyle(.secondary)

                    if let msg = archiveStore.archiveRootStatusMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button("Select Picture Library Folder…") {
                        archiveStore.promptForArchiveRoot()
                    }
                    .padding(.top, 6)

                    Spacer()
                }
                .padding(20)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    if archiveStore.archiveRootURL == nil && !archiveStore.hasStoredBookmark {
                        archiveStore.promptForArchiveRoot()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
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

        identityStore.configureForArchiveRoot(root)
        tagStore.configureForArchiveRoot(root)
        locationStore.configureForArchiveRoot(root)
        cropStore.configureForArchiveRoot(root)

        lastConfiguredRootPath = path
    }

    private func clearStoreConfiguration() {
        identityStore.configureForArchiveRoot(nil)
        tagStore.configureForArchiveRoot(nil)
        locationStore.configureForArchiveRoot(nil)
        cropStore.configureForArchiveRoot(nil)

        lastConfiguredRootPath = nil
    }
}






// ================================================================
// [LOCK] Settings Lock Gate View (HARD LOCK + HEARTBEAT)
// - If another session holds a fresh lock -> block editing
// - Otherwise -> claim lock + show Settings UI
// - Heartbeat keeps lock fresh while Settings is open
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
                DMPPCropPreferencesView()
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

                    Button("Check Again") {
                        evaluateLockAndEnterIfPossible()
                    }
                    .keyboardShortcut(.defaultAction)
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

        // No other active sessions: claim lock now (best-effort, but treat failure as block).
        do {
            try DMPPRegistryLockService.upsertLock(
                root: root,
                resourceKey: DMPPRegistryLockService.resourceSettings,
                session: session
            )
            canEnterSettings = true
        } catch {
            lockBlockMessage = "Could not claim Settings lock. Please try again.\n\n(\(error.localizedDescription))"
            canEnterSettings = false
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
}



