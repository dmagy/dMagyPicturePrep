import SwiftUI

@main
struct dMagy_Picture_PrepApp: App {

    var body: some Scene {

        // Main editor window
        WindowGroup {
            DMPPImageEditorView()
        }

        // Standard macOS Settings / Preferences window (⌘,)
        Settings {
            DMPPCropPreferencesView()
                .frame(minWidth: 420, idealWidth: 480, maxWidth: 520,
                       minHeight: 320, idealHeight: 360, maxHeight: 480)
        }
    }
}
