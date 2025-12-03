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
                .frame(minWidth: 420,
                                      idealWidth: 440,
                       maxWidth: 480,
                                     minHeight: 700,
                                      idealHeight: 740)
                               .padding()
                       }
                       .windowResizability(.contentSize)
    }
}
