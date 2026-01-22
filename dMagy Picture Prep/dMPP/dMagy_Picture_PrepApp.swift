import SwiftUI

// cp-2026-01-21-01(APP) — window autosave + fix duplicate WindowGroup + commands scope

@main
struct dMagy_Picture_PrepApp: App {

    // [APP-STORE] App-wide People/Identity store (single source of truth)
    @StateObject private var identityStore = DMPPIdentityStore.shared

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
        // [APP-SETTINGS] Settings window
        // ============================================================
        Settings {
            DMPPCropPreferencesView()
                .environmentObject(identityStore)
        }
        // (Leave these commented unless you intentionally want to force sizing.)
        // .defaultSize(width: 980, height: 820)
        // .windowResizability(.contentMinSize)

        // ============================================================
        // [APP-PEOPLE] Dedicated People Manager window
        // ============================================================
        WindowGroup("People Manager", id: "People-Manager") {
            DMPPPeopleManagerView()
                .environmentObject(identityStore)
                // [WIN] Separate autosave key so it doesn't fight the main window
                .background(DMPPWindowAutosave(name: "DMPP.PeopleWindow.v1"))
        }
        // Optional: also include People menu (if you want it globally, keep it here)
        .commands {
            PeopleCommands()
        }
    }
}


// ================================================================
// [ARCH] Picture Library Folder Gate View
// - If Picture Library Folder exists -> show editor
// - If not -> show setup screen + button to select folder
// ================================================================

private struct DMPPArchiveRootGateView: View {
    @EnvironmentObject var archiveStore: DMPPArchiveStore

    var body: some View {
        Group {
            if archiveStore.archiveRootURL != nil {
                // [ARCH] Folder is set: show main editor
                DMPPImageEditorView()
            } else {
                // [ARCH] Folder not set: show setup screen
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
                // [WIN] Don't start tiny; still just a minimum.
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    // [ARCH] Auto-prompt ONLY on true first run (no bookmark saved yet).
                    // If a bookmark exists but is invalid, we show the setup screen and the user can reselect.
                    if archiveStore.archiveRootURL == nil && !archiveStore.hasStoredBookmark {
                        archiveStore.promptForArchiveRoot()
                    }
                }
            }
        }
    }
}


// ================================================================
// [CMD] Commands live outside the App so they can use openWindow cleanly.
// ================================================================

private struct PeopleCommands: Commands {

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("People") {
            Button("Open People Manager") {
                openWindow(id: "People-Manager")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
}
