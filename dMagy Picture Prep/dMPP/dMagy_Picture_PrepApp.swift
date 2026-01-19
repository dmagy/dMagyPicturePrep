import SwiftUI

// cp-2025-12-18-01(APP)

@main
struct dMagy_Picture_PrepApp: App {

    // [APP-STORE] App-wide People/Identity store (single source of truth)
    @StateObject private var identityStore = DMPPIdentityStore.shared

    // [ARCH] Archive Root store (bookmark + selection)
    @StateObject private var archiveStore = DMPPArchiveStore()


    var body: some Scene {

        // [APP-MAIN] Main editor window
        WindowGroup {
            DMPPArchiveRootGateView()
                .environmentObject(archiveStore)
                .environmentObject(identityStore)
        }


        // [APP-SETTINGS] Settings window (you already have this; keep as-is if different)
        Settings {
            DMPPCropPreferencesView()
                .environmentObject(identityStore)
        }
        .defaultSize(width: 980, height: 820)
        .windowResizability(.contentMinSize)

        // [APP-PEOPLE] Dedicated People Manager window
        WindowGroup("Details", id: "People-Manager") {
            
            DMPPPeopleManagerView()
                .environmentObject(identityStore)
        }
        .defaultSize(width: 900, height: 650)

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

    }
}


// ================================================================
// [ARCH] Archive Root Gate View
// - If Archive Root exists -> show editor
// - If not -> show setup screen + button to select root
// ================================================================

private struct DMPPArchiveRootGateView: View {
    @EnvironmentObject var archiveStore: DMPPArchiveStore

    var body: some View {
        Group {
            if let _ = archiveStore.archiveRootURL {
                // [ARCH] Root is set: show main editor
                DMPPImageEditorView()
            } else {
                // [ARCH] Root not set: show setup screen
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
                .frame(minWidth: 520, minHeight: 240)
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


// [CMD] Commands live outside the App so they can use openWindow cleanly.
private struct PeopleCommands: Commands {

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("People") {
            Button("Open People Manager") {
                // [CMD-OPEN] This is the actual fix: uses the WindowGroup id above.
                openWindow(id: "People-Manager")
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }
    }
}
