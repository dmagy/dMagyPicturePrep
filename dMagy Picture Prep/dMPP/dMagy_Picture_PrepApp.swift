import SwiftUI
import Foundation
import UniformTypeIdentifiers

// cp-2026-01-25-03(APP) — remove IdentityStore singleton; App owns IdentityStore instance

extension Notification.Name {
    static let dmppOpenImageURL = Notification.Name("dmppOpenImageURL")
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
        // [CMD] Attach commands at the Scene level (applies to main window)
        .commands {
            CommandGroup(after: .newItem) {

                Button("Open…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    panel.allowedContentTypes = [.jpeg, .png, .heic, .tiff]

                    if panel.runModal() == .OK, let url = panel.url {
                        NotificationCenter.default.post(name: .dmppOpenImageURL, object: url)
                    }
                }
                .keyboardShortcut("o", modifiers: [.command])

                Divider()

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

                    Text("dMPP needs one top-level folder that contains your pictures. Portable registry data will be stored inside it.")
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
// MARK: - [GETTING-STARTED] First-run setup + first-use checklist
// Guides new users through setup, then helps them explore the core dMPP workflow.
// Stage 1: no sidecar scanning, no wizard, no blocking workflow.
// ================================================================

struct DMPPGettingStartedChecklistView: View {
    @EnvironmentObject var archiveStore: DMPPArchiveStore
    @EnvironmentObject var identityStore: DMPPIdentityStore
    @EnvironmentObject var locationStore: DMPPLocationStore

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    @AppStorage("dmpp.gettingStarted.dismissed")
    private var gettingStartedDismissed: Bool = false

    @AppStorage("dmpp.settings.selectedTab")
    private var selectedSettingsTab: String = "general"

    private var showAutomaticallyBinding: Binding<Bool> {
        Binding<Bool>(
            get: { !gettingStartedDismissed },
            set: { newValue in
                gettingStartedDismissed = !newValue
            }
        )
    }

    private var peopleCount: Int {
        identityStore.peopleSortedForUI.count
    }

    private var locationCount: Int {
        locationStore.locations.count
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ============================================================
            // Header / Welcome
            // ============================================================
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to dMagy Picture Prep")
                        .font(.title3.weight(.semibold))

                    Text("This guide introduces dMagy Picture Prep (dMPP) and helps you get started successfully. It walks you through setup, your first few pictures, and a few helpful tips to watch for as you keep reviewing.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Keep this window open next to the app and come back to these prompts as you find matching pictures.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Remember: your original pictures are never modified. dMPP saves picture information in small metadata sidecar files next to each picture. These files use the picture’s name with .dmpms.json added to the end.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    checklistSectionHeader(
                        "Set up your picture library",
                        subtitle: "Start by choosing the folder dMPP will use as the home for your pictures and shared archive data."
                    )

                    checklistRow(
                        isComplete: archiveStore.archiveRootURL != nil,
                        title: "Choose your Picture Library Folder",
                        detail: "Choose a folder in your normal file structure that contains all of your picture folders. This lets dMPP create one shared “dMagy Portable Archive Data” folder for your people, locations, tags, and crop choices.",
                        status: archiveStore.archiveRootURL?.path ?? "No Picture Library Folder selected.",
                        actionTitle: "Choose Folder…",
                        actionIsDisabled: false
                    ) {
                        archiveStore.promptForArchiveRoot()
                    }

                    checklistNote(
                        title: "Using Apple Photos?",
                        text: "dMPP works with pictures stored in regular folders. It does not work directly inside the Apple Photos library. If your pictures are in Photos, export them to regular folders first so dMPP can create sidecar files and use its full feature set."
                    )

                    checklistRow(
                        isComplete: portableArchiveDataExists,
                        title: "Confirm portable archive data",
                        detail: "dMPP stores shared People, Locations, Tags, and Crop settings in “dMagy Portable Archive Data.” This folder lives inside your Picture Library Folder and travels with your picture library. Click Show in Finder to see it.",
                        status: archiveStore.portableArchiveDataURL?.path ?? "Choose a Picture Library Folder first.",
                        actionTitle: "Show in Finder",
                        actionIsDisabled: archiveStore.portableArchiveDataURL == nil
                    ) {
                        archiveStore.openPortableArchiveDataFolderInFinder()
                    }

                    checklistSectionHeader(
                        "Start setting up your reusable basics",
                        subtitle: "These customize dMPP for your pictures and make reviewing faster and more consistent. dMPP becomes more helpful as you teach it the reusable building blocks of your picture library: your people, your locations, your tags, and your crop choices."
                    )

                    checklistRow(
                        isComplete: peopleCount >= 3,
                        title: "People",
                        detail: "Using Settings > People, add at least yourself, a friend, and a relative who appear often in your pictures. This makes age calculations and people tagging more useful right away.",
                        status: peopleCount == 1 ? "1 saved person" : "\(peopleCount) saved people",
                        actionTitle: "Open People Settings",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        selectedSettingsTab = "people"
                        openSettings()
                    }

                    checklistRow(
                        isComplete: locationCount >= 1,
                        title: "Locations",
                        detail: "Using Settings > Locations, add at least one saved location where you often take pictures, such as your home, school, church, or a favorite family place.",
                        status: locationCount == 1 ? "1 saved location" : "\(locationCount) saved locations",
                        actionTitle: "Open Location Settings",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        selectedSettingsTab = "locations"
                        openSettings()
                    }

                    checklistSectionHeader(
                        "Start the dMPP picture review flow",
                        subtitle: "Start with the default editor flow. Review the current picture from top to bottom, then click Next Picture. dMPP automatically saves your changes as it moves forward."
                    )

                    guideRow(
                        title: "Open a working folder",
                        detail: "Choose your Picture Library Folder or a folder inside it. dMPP will begin with a picture in that folder so you can start reviewing.",
                        note: "Start here when you are ready to review pictures.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    guideRow(
                        title: "Crop your picture with the default crops",
                        detail: "Start with the default Landscape 16:9 and Portrait 4:5 crops. Adjust the size of each crop with the vertical slider and the position by dragging the crop box. dMPP crops virtually and does not edit your original picture.",
                        note: "Use this to prepare pictures for display or future output.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    guideRow(
                        title: "Title and Description",
                        detail: "Give the picture a useful title and, if helpful, a short description. Unlike file names, picture titles do not need to be unique.",
                        note: "The title defaults to the picture’s file name.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    guideRow(
                        title: "Date Taken or Era",
                        detail: "Use what you know. Exact dates are helpful, but a year, decade, or date range is better than leaving the picture undated. Dates also help dMPP estimate people’s ages when birth years are available.",
                        note: "This defaults to the date from the original picture file metadata if available.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    guideRow(
                        title: "Tags",
                        detail: "Select any tags that help describe or filter the picture. More tags can be added in Settings > Tags.",
                        note: "Use tags when they help organize or filter your library.",
                        actionTitle: "Add or Edit Tags",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        selectedSettingsTab = "tags"
                        openSettings()
                    }

                    guideRow(
                        title: "People",
                        detail: "dMPP defaults to Suggested mode, which can find face slots right away. Add the people in the picture. As you save identified people over time, dMPP will begin suggesting matches.",
                        note: "Use Manual when faces are missed, unclear, or when you want full control.",
                        actionTitle: "Add More People",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        selectedSettingsTab = "people"
                        openSettings()
                    }

                    guideRow(
                        title: "Location",
                        detail: "Try selecting a saved location you entered earlier. For pictures with GPS, you can clear the location and use Reset to GPS to see how dMPP fills the address from the picture.",
                        note: "Use locations when place matters for the picture.",
                        actionTitle: "Add More Locations",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        selectedSettingsTab = "locations"
                        openSettings()
                    }

                    guideRow(
                        title: "Click Next Picture",
                        detail: "When you click Next Picture, dMPP saves your changes for the current picture and moves forward. This creates or updates the picture’s metadata sidecar file without changing the original image.",
                        note: "This is the usual review workflow.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    checklistSectionHeader(
                        "Watch for these picture types",
                        subtitle: "You do not need to hunt for these right away. When one comes up, use it to learn another part of dMPP."
                    )

                    guideRow(
                        title: "Large group picture",
                        detail: "For reunions, class photos, wedding groups, or other large pictures, Manual mode lets you add people row by row, left to right.",
                        note: "Try this when Suggested mode is not the right fit.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    guideRow(
                        title: "Picture that needs an extra crop",
                        detail: "Use New Crop when the default crops are not enough. Crops describe how the picture should be framed later; they do not change the original image.",
                        note: "Try this when you have a matching picture.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    guideRow(
                        title: "Recent phone photo with GPS",
                        detail: "Use Reset to GPS to fill the address, then compare it with a saved location. Saved locations help turn raw address data into meaningful places like Home, Grandma’s House, Church, or School.",
                        note: "Try this when you have a matching picture.",
                        actionTitle: "Continue Reviewing",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        NSApp.activate(ignoringOtherApps: true)
                    }

                    checklistSectionHeader(
                        "Come back later",
                        subtitle: "This checklist can stay open beside the editor. Use it as a guide while you learn the app, then turn off automatic display when you no longer need it."
                    )

                    guideRow(
                        title: "Review Settings when you are ready",
                        detail: "People, Locations, Tags, and Crop choices can all be managed in Settings. You do not need to master everything before you start reviewing pictures.",
                        note: "Open Settings when you want to tune the reusable pieces.",
                        actionTitle: "Open Settings",
                        actionIsDisabled: archiveStore.archiveRootURL == nil
                    ) {
                        selectedSettingsTab = "general"
                        openSettings()
                    }
                }
                .padding(.vertical, 14)
            }

            Divider()

            HStack(alignment: .top, spacing: 10) {
                Toggle("Show automatically until setup is complete", isOn: showAutomaticallyBinding)
                    .toggleStyle(.checkbox)
                    .help("When enabled, dMPP opens this checklist automatically while setup is incomplete.")

                Spacer(minLength: 8)

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 12)
        }
        .padding(18)
        .frame(
            minWidth: 390,
            idealWidth: 440,
            maxWidth: .infinity,
            minHeight: 620,
            idealHeight: 760,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    // ============================================================
    // MARK: - [GETTING-STARTED] Section header
    // ============================================================

    @ViewBuilder
    private func checklistSectionHeader(
        _ title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.semibold))

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    // ============================================================
    // MARK: - [GETTING-STARTED] Note row
    // ============================================================

    @ViewBuilder
    private func checklistNote(
        title: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.22), lineWidth: 1)
        )
    }

    // ============================================================
    // MARK: - [GETTING-STARTED] Checklist row
    // ============================================================

    @ViewBuilder
    private func checklistRow(
        isComplete: Bool,
        title: String,
        detail: String,
        status: String,
        actionTitle: String,
        actionIsDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isComplete ? Color.accentColor : Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)

                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            HStack {
                Spacer(minLength: 0)

                Button(actionTitle) {
                    action()
                }
                .disabled(actionIsDisabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
    
    // ============================================================
    // MARK: - [GETTING-STARTED] Guide row
    // Use for learning prompts that are not true completion tasks.
    // ============================================================

    @ViewBuilder
    private func guideRow(
        title: String,
        detail: String,
        note: String? = nil,
        actionTitle: String,
        actionIsDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)

                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack {
                Spacer(minLength: 0)

                Button(actionTitle) {
                    action()
                }
                .disabled(actionIsDisabled)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.10), lineWidth: 1)
        )
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



