import SwiftUI

// ================================================================
// DMPSFlaggedReportImportView.swift
//
// Purpose:
// - Presents a read-only dMPS Flagged Pictures Report import session.
// - Lets the user inspect parsed report items, validation issues, and path
//   classifications without applying metadata changes.
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
// - View renders summary counts, report-level issues, item list, and selected
//   item details.
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

                Text("Inspection only. dMPP has not changed saved information for these pictures.")
                    .font(.callout.weight(.semibold))

                Text("dMagy Picture Show recorded pictures for later review. dMagy Picture Prep can inspect that queue here. No saved picture information has been changed.")
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

            Text("dMPP will parse the report and show validation/path status. Nothing will be applied to your saved information in this phase.")
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

                HStack(spacing: 8) {
                    countPill("Total", coordinator.totalItemCount)
                    countPill("Valid", coordinator.validItemCount)
                    countPill("Warnings", coordinator.warningItemCount)
                    countPill("Invalid", coordinator.invalidItemCount)
                    countPill("Unresolved", coordinator.unresolvedItemCount)
                }

                if !session.topLevelIssues.isEmpty {
                    issueGroup(title: "Report-level issues", issues: session.topLevelIssues)
                }
            }
        }
        .padding(14)
    }

    private func countPill(_ label: String, _ value: Int) -> some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
    }

    // MARK: - Item List

    private var itemList: some View {
        List(selection: $selectedItemID) {
            ForEach(coordinator.currentSession?.items ?? []) { item in
                itemRow(item)
                    .tag(item.id)
            }
        }
        .listStyle(.sidebar)
    }

    private func itemRow(_ item: DMPSFlaggedImportSessionItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: statusSymbol(for: item.validationStatus))
                .foregroundStyle(statusColor(for: item.validationStatus))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName(for: item))
                    .font(.headline)
                    .lineLimit(1)

                Text(statusText(for: item.validationStatus))
                    .font(.caption)
                    .foregroundStyle(statusColor(for: item.validationStatus))

                Text(pathStatusText(for: item.pathResolution.status))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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
                            title: statusText(for: item.validationStatus),
                            message: "Suggested by dMPS, not yet applied by dMPP.",
                            symbolName: statusSymbol(for: item.validationStatus),
                            tint: statusColor(for: item.validationStatus)
                        )

                        detailSection("Report item") {
                            detailRow("Item ID", item.id)
                            detailRow("Flagged at", item.reportItem.flaggedAt ?? "Not provided")
                            detailRow("Flag source", item.reportItem.flagSource ?? "Not provided")
                            detailRow("Runtime state", item.reportItem.runtimeFlagState?.rawValue ?? "Not provided")
                            detailRow("Sidecar status in dMPS", item.reportItem.sidecarStatusAtFlag?.rawValue ?? "Not provided")
                            detailRow("Suggested tags", (item.reportItem.suggestedDMPMSTags ?? []).joined(separator: ", "))
                            detailRow("Suggested review note", item.reportItem.suggestedReviewNote ?? "Not provided")
                        }

                        detailSection("Path") {
                            detailRow("Status", pathStatusText(for: item.pathResolution.status))
                            detailRow("Absolute path", item.reportItem.imageAbsolutePath ?? "Not provided")
                            detailRow("Relative path", item.reportItem.relativePath ?? "Not provided")
                            detailRow("Candidate path", item.pathResolution.candidateURL?.path ?? "Not available")
                            detailRow("File exists", yesNoUnknown(item.pathResolution.fileExists))
                            detailRow("Inside Picture Library Folder", yesNoUnknown(item.pathResolution.isInsideArchiveRoot))
                        }

                        if !item.validationIssues.isEmpty {
                            issueGroup(title: "Item issues", issues: item.validationIssues)
                        }
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

    // MARK: - Formatting Helpers

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
        let createdAt = session.report?.createdAt ?? "unknown created date"
        let updatedAt = session.report?.updatedAt ?? "unknown updated date"
        return "\(createdBy) | Created \(createdAt) | Updated \(updatedAt)"
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

    private func statusText(for status: DMPSFlaggedReportItemValidationStatus) -> String {
        switch status {
        case .valid:
            return "Ready for later review"
        case .validWithWarnings:
            return "Needs attention before review"
        case .invalid:
            return "Cannot be reviewed yet"
        }
    }

    private func statusSymbol(for status: DMPSFlaggedReportItemValidationStatus) -> String {
        switch status {
        case .valid:
            return "checkmark.circle"
        case .validWithWarnings:
            return "exclamationmark.triangle"
        case .invalid:
            return "xmark.octagon"
        }
    }

    private func statusColor(for status: DMPSFlaggedReportItemValidationStatus) -> Color {
        switch status {
        case .valid:
            return .green
        case .validWithWarnings:
            return .orange
        case .invalid:
            return .red
        }
    }

    private func pathStatusText(for status: DMPSFlaggedPathResolutionStatus) -> String {
        switch status {
        case .notResolved:
            return "Not resolved"
        case .hasAbsolutePath:
            return "Found from report path"
        case .hasRelativePath:
            return "Found from relative path"
        case .missingLocator:
            return "No usable path in report"
        case .outsideArchiveRoot:
            return "Outside current Picture Library Folder"
        case .missingFile:
            return "File not found at report path"
        case .unsupportedImageExtension:
            return "Unsupported image type"
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
