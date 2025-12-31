import SwiftUI

// cp-2025-12-18-01(APP)

@main
struct dMagy_Picture_PrepApp: App {

    // [APP-STORE] App-wide People/Identity store (single source of truth)
    @StateObject private var identityStore = DMPPIdentityStore.shared


    var body: some Scene {

        // [APP-MAIN] Main editor window
        WindowGroup {
            DMPPImageEditorView()
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

        // [APP-COMMANDS] People menu wiring
     //   .commands {
      //      PeopleCommands()
      //  }
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
