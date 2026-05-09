import SwiftUI
import AppKit

// ================================================================
// GettingStartedChecklistView.swift
// Purpose:
// - Presents a short Getting Started window for first-run setup and early user guidance.
// - Focuses on the minimum setup needed for dMPP to become useful quickly.
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
// - [GETTING-STARTED] Header
// - [GETTING-STARTED] Sections
// - [GETTING-STARTED] Row helpers
// ================================================================

// ================================================================
// MARK: - [GETTING-STARTED] Main view
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

    private var archiveStatusText: String {
        if let folderName = archiveStore.archiveRootURL?.lastPathComponent {
            return "Your Picture Library Folder: \(folderName)"
        }

        return "No Picture Library Folder selected."
    }

    private var peopleStatusText: String {
        "You currently have \(countText(peopleCount, singular: "saved person", plural: "saved people"))."
    }

    private var locationStatusText: String {
        "You currently have \(countText(locationCount, singular: "saved location", plural: "saved locations"))."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBlock

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    beforeYouBeginSection
                    reusableBasicsSection
                    startReviewingSection
                    laterSection
                }
                .padding(.vertical, 14)
            }

            Divider()

            footerBlock
        }
        .padding(18)
        .frame(
            minWidth: 390,
            idealWidth: 440,
            maxWidth: .infinity,
            minHeight: 560,
            idealHeight: 680,
            maxHeight: .infinity,
            alignment: .topLeading
        )
    }

    // ============================================================
    // MARK: - [GETTING-STARTED] Header
    // ============================================================

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to dMagy Picture Prep")
                    .font(.title3.weight(.semibold))

                Text("This guide helps you do the small amount of setup that makes dMPP useful right away: choose your picture library, add key people, add saved locations, then start reviewing pictures.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("You can close this window and return to it from Help > Getting Started.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 16)
    }

    private var footerBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("Show at startup", isOn: showAutomaticallyBinding)
                .toggleStyle(.checkbox)
                .help("When enabled, dMPP opens this guide when the app starts.")

            Spacer(minLength: 8)

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 12)
    }

    // ============================================================
    // MARK: - [GETTING-STARTED] Sections
    // ============================================================

    private var beforeYouBeginSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "Before you begin",
                subtitle: "dMPP works with pictures in regular folders and saves portable metadata beside them."
            )

            checklistRow(
                isComplete: archiveStore.archiveRootURL != nil,
                title: "Picture Library Folder",
                detail: "Choose the top-level folder that contains your picture folders. dMPP creates or uses “dMagy Portable Archive Data” inside that folder for shared People, Locations, Tags, and Crop choices.",
                status: archiveStatusText,
                actionTitle: archiveStore.archiveRootURL == nil ? "Choose Folder…" : "Change or Refresh…",
                actionIsDisabled: false
            ) {
                archiveStore.promptForArchiveRoot()
            }

            noteRow(
                title: "Using Apple Photos?",
                text: "dMPP does not work directly inside the Apple Photos library. If your pictures are in Photos, export them to regular folders first, then choose that folder structure as your Picture Library Folder."
            )

            noteRow(
                title: "Original pictures are safe",
                text: "dMPP does not edit your original pictures. It saves picture information in small .dmpms.json sidecar files next to each picture."
            )
        }
    }

    private var reusableBasicsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "Set up reusable basics",
                subtitle: "People and Locations make dMPP faster and more meaningful as you review pictures."
            )

            checklistRow(
                isComplete: peopleCount >= 3,
                title: "Add key People",
                detail: "Start with yourself and a few people who appear often in your pictures. This makes people tagging, Suggested mode, and age clues more useful right away.",
                status: peopleStatusText,
                actionTitle: "Open People Settings",
                actionIcon: "person.2",
                actionIsDisabled: archiveStore.archiveRootURL == nil
            ) {
                selectedSettingsTab = "people"
                openSettings()
            }

            checklistRow(
                isComplete: locationCount >= 1,
                title: "Add saved Locations",
                detail: "Add at least one place where you often take pictures, such as home, church, school, or a favorite family location.",
                status: locationStatusText,
                actionTitle: "Open Location Settings",
                actionIcon: "mappin.and.ellipse",
                actionIsDisabled: archiveStore.archiveRootURL == nil
            ) {
                selectedSettingsTab = "locations"
                openSettings()
            }
        }
    }

    private var startReviewingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "Start reviewing pictures",
                subtitle: "Once the basics are in place, choose a working folder in the main editor and review pictures from top to bottom."
            )

            guideRow(
                title: "Open a working folder",
                detail: "Use Choose Folder in the main editor to choose a folder inside your Picture Library Folder. dMPP will begin with a picture in that folder so you can start reviewing."
            )

            guideRow(
                title: "Fill in what you know",
                detail: "Add or confirm the title, date, people, location, tags, and crops when they are useful. You do not have to know everything for every picture."
            )

            guideRow(
                title: "Click Next Picture",
                detail: "The usual workflow is to review the current picture, then click Next Picture. dMPP saves your changes before moving forward."
            )
        }
    }

    private var laterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "Explore more later",
                subtitle: "You do not need to master every feature before you start."
            )

            guideRow(
                title: "Use section help as you go",
                detail: "The editor includes help for Dates, People, Locations, and Crops. Use those when a specific question comes up."
            )

            guideRow(
                title: "Review Settings when needed",
                detail: "Tags, Crops, People, Locations, and other options can be adjusted later. Start simple and refine as your archive grows."
            )
        }
    }

    // ============================================================
    // MARK: - [GETTING-STARTED] Row helpers
    // ============================================================

    @ViewBuilder
    private func sectionHeader(
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

    @ViewBuilder
    private func noteRow(
        title: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: "info.circle")
                .font(.headline)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func checklistRow(
        isComplete: Bool,
        title: String,
        detail: String,
        status: String,
        actionTitle: String,
        actionIcon: String? = nil,
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

                Button {
                    action()
                } label: {
                    if let actionIcon {
                        Label(actionTitle, systemImage: actionIcon)
                    } else {
                        Text(actionTitle)
                    }
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

    @ViewBuilder
    private func guideRow(
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.right.circle")
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

    private func countText(_ count: Int, singular: String, plural: String) -> String {
        count == 1 ? "1 \(singular)" : "\(count) \(plural)"
    }
}
