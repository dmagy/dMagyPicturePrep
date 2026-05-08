import SwiftUI
import AppKit

// ================================================================
// GettingStartedChecklistView.swift
// Purpose:
// - Presents the Getting Started window for first-run setup and early user guidance.
// - Helps users understand the Picture Library Folder, reusable People/Locations,
//   and the basic review workflow.
//
// Dependencies & Effects:
// - Reads DMPPArchiveStore, DMPPIdentityStore, and DMPPLocationStore.
// - Opens Settings and routes users to Settings tabs through AppStorage.
// - Can prompt for / reveal the Picture Library Folder through DMPPArchiveStore.
//
// Data Flow:
// - Archive, People, and Location state flows in through EnvironmentObject.
// - User actions open Settings, prompt for the archive root, or reveal portable data.
// - The “show automatically” preference is stored in AppStorage.
//
// Section Index:
// - [GETTING-STARTED] Main view
// - [GETTING-STARTED] Section header
// - [GETTING-STARTED] Note row
// - [GETTING-STARTED] Checklist row
// - [GETTING-STARTED] Guide row
// ================================================================

import SwiftUI
import AppKit

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
