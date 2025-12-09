import SwiftUI

@main
struct dMagy_Picture_PrepApp: App {
    
    @Environment(\.openWindow) private var openWindow


    var body: some Scene {

        // Main editor window
        WindowGroup {
            DMPPImageEditorView()
        }
        
        // New People Manager window
          WindowGroup("People Manager", id: "People-Manager") {
              DMPPPeopleManagerView()
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
        
        // New commands
           .commands {
               CommandMenu("People") {
                   Button("Open People Manager…") {
                       openWindow(id: "PeopleManager")
                   }
                   .keyboardShortcut("P", modifiers: [.command, .option])
               }
           }
        
    }
}
