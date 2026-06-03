import AppKit
import SwiftUI

// ================================================================
// DMPSFlaggedReportImportView.swift
//
// Purpose:
// - Presents a read-only dMPS Flagged Review Queue import triage session.
// - Lets the user inspect which queue items can safely be brought into the
//   normal dMPP Flagged review workflow later.
//
// Dependencies & Effects:
// - Reads DMPSFlaggedReportImportCoordinator and DMPPArchiveStore from the
//   environment.
// - Can ask the coordinator to open a report picker.
// - Does not modify sidecars, original images, tags, curator notes, or durable
//   relink mappings.
//
// Data Flow:
// - Coordinator publishes a DMPSFlaggedImportSession.
// - View renders triage counts, report-level issues, item list, and selected
//   item details, including read-only current saved-information inspection.
//
// Section Index:
// - Main View
// - Empty State
// - Session View
// - Summary
// - Item List
// - Detail Pane
// - Formatting Helpers
// ================================================================

// MARK: - Main View

struct DMPSFlaggedReportImportView: View {
    @EnvironmentObject private var archiveStore: DMPPArchiveStore
    @EnvironmentObject private var coordinator: DMPSFlaggedReportImportCoordinator
    @State private var selectedItemID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            if coordinator.currentSession == nil {
                emptyState
            } else {
                sessionView
            }
        }
        .frame(minWidth: 940, idealWidth: 1080, minHeight: 620, idealHeight: 720)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flag")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("dMPS Flagged Review Queue")
                    .font(.title3.weight(.semibold))

                Text("Import triage only. dMPP has not changed saved information for these pictures.")
                    .font(.callout.weight(.semibold))

                Text("dMagy Picture Show recorded pictures for later review. dMagy Picture Prep can check whether they can safely enter your normal Flagged review workflow.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                importReviewQueue()
            } label: {
                Label("Import Review Queue…", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let importErrorMessage = coordinator.importErrorMessage {
                statusBanner(
                    title: "Import needs attention",
                    message: importErrorMessage,
                    symbolName: "exclamationmark.triangle",
                    tint: .yellow
                )
            }

            Text("Import a dMPS Flagged Review Queue file exported by dMagy Picture Show.")
                .font(.headline)

            Text("dMPP will parse the queue and show which pictures can safely be tagged later. Nothing will be applied to your saved information in this phase.")
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if archiveStore.archiveRootURL == nil {
                    Button("Choose Picture Library Folder…") {
                        archiveStore.promptForArchiveRoot()
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Session View

    private var sessionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            summaryView

            Divider()

            HSplitView {
                itemList
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 430)

                detailPane
                    .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - Summary

    private var summaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let importErrorMessage = coordinator.importErrorMessage {
                statusBanner(
                    title: "Import needs attention",
                    message: importErrorMessage,
                    symbolName: "exclamationmark.triangle",
                    tint: .yellow
                )
            }

            if let session = coordinator.currentSession {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.sourceReportURL?.lastPathComponent ?? "Imported report")
                            .font(.headline)

                        Text(reportMetadataText(session))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    Button("Clear") {
                        coordinator.clearSession()
                        selectedItemID = nil
                    }
                }

                DMPSFlaggedTriageSummaryView(
                    triageCoordinator: coordinator.triageCoordinator
                )

                DMPSFlaggedTriageActionView(
                    triageCoordinator: coordinator.triageCoordinator
                )

                if !session.topLevelIssues.isEmpty {
                    issueGroup(title: "Report-level issues", issues: session.topLevelIssues)
                }
            }
        }
        .padding(14)
    }

    // MARK: - Item List

    private var itemList: some View {
        List(selection: $selectedItemID) {
            ForEach(coordinator.currentSession?.items ?? []) { item in
                itemRow(item)
                    .tag(item.id)
                    .contextMenu {
                        itemContextMenu(for: item)
                    }
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func itemContextMenu(for item: DMPSFlaggedImportSessionItem) -> some View {
        if let url = pictureURL(for: item), FileManager.default.fileExists(atPath: url.path) {
            Button("Show Picture in Finder") {
                revealInFinder(url)
            }
        } else {
            Button("Show Picture in Finder") {
            }
            .disabled(true)
        }

        if let path = originalPathText(for: item) {
            Button("Copy Original Path") {
                copyToPasteboard(path)
            }
        }
    }

    private func itemRow(_ item: DMPSFlaggedImportSessionItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: reviewStatusSymbol(for: item))
                .foregroundStyle(reviewStatusColor(for: item))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName(for: item))
                    .font(.headline)
                    .lineLimit(1)

                Text(itemRowStatusText(for: item))
                    .font(.caption)
                    .foregroundStyle(reviewStatusColor(for: item))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        Group {
            if let item = selectedItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(displayName(for: item))
                            .font(.title3.weight(.semibold))

                        statusBanner(
                            title: reviewStatusTitle(for: item),
                            message: reviewStatusMessage(for: item),
                            symbolName: reviewStatusSymbol(for: item),
                            tint: reviewStatusColor(for: item)
                        )

                        sidecarDetailSection(for: item)

                        DMPSFlaggedTriageDetailView(
                            triageItem: coordinator.triageCoordinator.triageItem(for: item.id)
                        )

                        advancedDetailsSection(for: item)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "flag")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Select an item to inspect its report details.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func detailSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not provided" : value)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func issueGroup(
        title: String,
        issues: [DMPSFlaggedReportValidationIssue]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: issueSymbol(for: issue.severity))
                        .foregroundStyle(issueColor(for: issue.severity))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.code.rawValue)
                            .font(.caption.weight(.semibold))
                        Text(issue.message)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func statusBanner(
        title: String,
        message: String,
        symbolName: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.headline)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    private func sidecarDetailSection(for item: DMPSFlaggedImportSessionItem) -> some View {
        detailSection("Current saved information") {
            Text("dMPP is reading current saved information only. No saved information has been changed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let inspection = coordinator.sidecarInspection(for: item.id) {
                statusBanner(
                    title: sidecarStatusText(for: inspection),
                    message: readinessText(for: inspection.readiness),
                    symbolName: sidecarStatusSymbol(for: inspection.status),
                    tint: sidecarStatusColor(for: inspection.status)
                )

                detailRow("Flagged tag", inspection.containsFlaggedTag ? "Already saved in dMPP" : "Not yet added")
                detailRow("dMPS review note", reviewNoteStatus(for: inspection))
                detailRow("Current tags", inspection.currentTags.isEmpty ? "None" : inspection.currentTags.joined(separator: ", "))
                detailRow("Curator notes", inspection.curatorNotesPreview ?? "No curator notes")

                if let errorMessage = inspection.errorMessage, !errorMessage.isEmpty {
                    detailRow("Read error", errorMessage)
                }
            } else {
                detailRow("Saved information status", "Not inspected")
            }
        }
    }

    private func advancedDetailsSection(for item: DMPSFlaggedImportSessionItem) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                advancedSection("Report") {
                    advancedDetailRow("Report item ID", item.id)
                    advancedDetailRow("Flagged date", item.reportItem.flaggedAt ?? "Not provided")
                    advancedDetailRow("Source app/status", item.reportItem.sidecarStatusAtFlag?.rawValue ?? "Not provided")
                }

                advancedSection("Picture") {
                    advancedDetailRow("Image path", item.pathResolution.candidateURL?.path ?? item.reportItem.imageAbsolutePath ?? "Not available")
                    advancedDetailRow("File exists", yesNoUnknown(item.pathResolution.fileExists))
                    advancedDetailRow("Inside Picture Library Folder", yesNoUnknown(item.pathResolution.isInsideArchiveRoot))
                }

                if let inspection = coordinator.sidecarInspection(for: item.id) {
                    advancedSection("Saved information") {
                        advancedDetailRow("Information file path", inspection.sidecarURL?.path ?? "Not available")
                        advancedDetailRow("Saved filename", inspection.sourceFile ?? "Not available")
                        advancedDetailRow("Expected filename", inspection.expectedSourceFile ?? "Not available")
                        advancedDetailRow("Filename matches", yesNoUnknown(inspection.sourceFileMatches))
                    }
                }

                if !item.validationIssues.isEmpty {
                    issueGroup(title: "Item issues", issues: item.validationIssues)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.secondary.opacity(0.07))
            )
        } label: {
            Label("Advanced details", systemImage: "info.circle")
                .font(.headline)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    private func advancedSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 5) {
                content()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func advancedDetailRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not provided" : value)
                .font(.caption)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Formatting Helpers

    private func itemNeedsAttention(_ item: DMPSFlaggedImportSessionItem) -> Bool {
        coordinator.triageCoordinator.triageItem(for: item.id)?.status == .needsAttention
            || coordinator.triageCoordinator.triageItem(for: item.id) == nil
    }

    private func importReviewQueue() {
        if coordinator.importReport(archiveRootURL: archiveStore.archiveRootURL) {
            selectedItemID = coordinator.currentSession?.items.first?.id
        }
    }

    private var selectedItem: DMPSFlaggedImportSessionItem? {
        guard let session = coordinator.currentSession else { return nil }

        if let selectedItemID,
           let item = session.items.first(where: { $0.id == selectedItemID }) {
            return item
        }

        return session.items.first
    }

    private func reportMetadataText(_ session: DMPSFlaggedImportSession) -> String {
        let createdBy = session.report?.createdBy ?? "Unknown source"
        return "Imported from \(createdBy). Inspection only."
    }

    private func displayName(for item: DMPSFlaggedImportSessionItem) -> String {
        if let filename = item.reportItem.filename, !filename.isEmpty {
            return filename
        }

        if let path = item.reportItem.imageAbsolutePath ?? item.reportItem.relativePath {
            return URL(fileURLWithPath: path).lastPathComponent
        }

        return "Untitled report item"
    }

    private func pictureURL(for item: DMPSFlaggedImportSessionItem) -> URL? {
        item.pathResolution.candidateURL
    }

    private func originalPathText(for item: DMPSFlaggedImportSessionItem) -> String? {
        if let candidatePath = item.pathResolution.candidateURL?.path, !candidatePath.isEmpty {
            return candidatePath
        }

        if let absolutePath = item.reportItem.imageAbsolutePath, !absolutePath.isEmpty {
            return absolutePath
        }

        if let relativePath = item.reportItem.relativePath, !relativePath.isEmpty {
            return relativePath
        }

        return nil
    }

    private func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func reviewStatusMessage(for item: DMPSFlaggedImportSessionItem) -> String {
        coordinator.triageCoordinator.triageItem(for: item.id)?.message
            ?? "dMPP is checking whether this dMPS flagged picture can safely enter your normal Flagged review workflow."
    }

    private func reviewStatusTitle(for item: DMPSFlaggedImportSessionItem) -> String {
        coordinator.triageCoordinator.triageItem(for: item.id)?.status.userLabel
            ?? "Import triage"
    }

    private func reviewStatusSymbol(for item: DMPSFlaggedImportSessionItem) -> String {
        switch coordinator.triageCoordinator.triageItem(for: item.id)?.status {
        case .readyToUpdate, .readyToCreateSavedInformation, .updatedCuratorNoteOnly:
            return "checkmark.circle"
        case .alreadyUpdated:
            return "checkmark.seal"
        case .needsAttention, nil:
            return "exclamationmark.triangle"
        }
    }

    private func reviewStatusColor(for item: DMPSFlaggedImportSessionItem) -> Color {
        switch coordinator.triageCoordinator.triageItem(for: item.id)?.status {
        case .readyToUpdate, .readyToCreateSavedInformation, .updatedCuratorNoteOnly:
            return .green
        case .alreadyUpdated:
            return .blue
        case .needsAttention, nil:
            return .orange
        }
    }

    private func reviewNoteStatus(for inspection: DMPSFlaggedSidecarInspectionResult) -> String {
        inspection.curatorNotesContainsStableDMPSReviewNote ? "Already saved" : "Not yet added"
    }

    private func itemRowStatusText(for item: DMPSFlaggedImportSessionItem) -> String {
        coordinator.triageCoordinator.triageItem(for: item.id)?.status.userLabel ?? "Import triage"
    }

    private func sidecarStatusText(for inspection: DMPSFlaggedSidecarInspectionResult) -> String {
        switch inspection.status {
        case .notInspected:
            return "Needs attention"
        case .unresolvedImage:
            return "Needs attention"
        case .imageMissing:
            return "Needs attention"
        case .sidecarMissing:
            return "Needs saved information file"
        case .sidecarInvalid:
            return "Needs review"
        case .sidecarValid:
            return inspection.containsFlaggedTag ? "Previously flagged in dMPP" : "Ready to update"
        case .sourceFileMismatch:
            return "Needs review"
        case .readError:
            return "Needs review"
        }
    }

    private func readinessText(for readiness: DMPSFlaggedSidecarReadiness) -> String {
        switch readiness {
        case .readyForFutureApply:
            return "dMPP can read the current saved information for this picture. No saved information has been changed."
        case .alreadyFlagged:
            return "The Flagged tag is already saved in dMPP. No saved information has been changed."
        case .needsSidecar:
            return "A saved information file would be needed before future review actions."
        case .needsRepair:
            return "This saved information needs attention before future review actions."
        case .needsResolvedImage:
            return "The picture path needs to be resolved before saved information can be inspected."
        }
    }

    private func sidecarStatusSymbol(for status: DMPSFlaggedSidecarInspectionStatus) -> String {
        switch status {
        case .sidecarValid:
            return "checkmark.circle"
        case .sidecarMissing, .unresolvedImage, .imageMissing, .sourceFileMismatch:
            return "exclamationmark.triangle"
        case .sidecarInvalid, .readError:
            return "xmark.octagon"
        case .notInspected:
            return "info.circle"
        }
    }

    private func sidecarStatusColor(for status: DMPSFlaggedSidecarInspectionStatus) -> Color {
        switch status {
        case .sidecarValid:
            return .green
        case .sidecarMissing, .unresolvedImage, .imageMissing, .sourceFileMismatch:
            return .orange
        case .sidecarInvalid, .readError:
            return .red
        case .notInspected:
            return .blue
        }
    }

    private func issueSymbol(for severity: DMPSFlaggedReportValidationSeverity) -> String {
        switch severity {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }

    private func issueColor(for severity: DMPSFlaggedReportValidationSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }

    private func yesNoUnknown(_ value: Bool?) -> String {
        guard let value else { return "Unknown" }
        return value ? "Yes" : "No"
    }
}
