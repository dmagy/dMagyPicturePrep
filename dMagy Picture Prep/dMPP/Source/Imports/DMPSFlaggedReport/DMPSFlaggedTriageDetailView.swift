import SwiftUI

// ================================================================
// DMPSFlaggedTriageDetailView.swift
//
// Purpose:
// - Shows the no-write triage result for one dMPS Flagged Review Queue item.
// - Explains what dMPP can do later without creating a parallel review
//   workflow inside the import window.
//
// Dependencies & Effects:
// - Depends on SwiftUI and DMPSFlaggedTriageStatus types.
// - Displays in-memory triage data only.
// - Performs no file I/O, sidecar writes, tag updates, curator note changes,
//   or image changes.
//
// Data Flow:
// - DMPSFlaggedReportImportView passes the selected item's triage result.
// - This view renders user-facing status, explanation, and future action text.
//
// Section Index:
// - Detail View
// - Future Action
// - Formatting
// ================================================================

// MARK: - Detail View

struct DMPSFlaggedTriageDetailView: View {
    var triageItem: DMPSFlaggedTriageItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What dMPP can do later")
                .font(.headline)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbolName)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.callout.weight(.semibold))

                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)
            }

            futureActionPreview
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    // MARK: - Future Action

    private var futureActionPreview: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Preview only. No saved information has been changed.")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)

            switch status {
            case .readyToUpdate:
                previewLine("Tag this picture as Flagged.")
                previewLine("Add the dMPS review note.")
            case .readyToCreateSavedInformation:
                previewLine("Create saved information for this picture.")
                previewLine("Tag this picture as Flagged and add the dMPS review note.")
            case .updatedCuratorNoteOnly:
                previewLine("Add the dMPS review note.")
            case .alreadyUpdated:
                previewLine("No queue update is needed.")
            case .needsAttention:
                previewLine("No automatic queue update will be made.")
            }
        }
    }

    private func previewLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .padding(.top, 7)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Formatting

    private var status: DMPSFlaggedTriageStatus {
        triageItem?.status ?? .needsAttention
    }

    private var title: String {
        triageItem?.status.userLabel ?? "Needs attention"
    }

    private var message: String {
        triageItem?.message ?? "dMPP will not update this picture from the queue until the issue is resolved."
    }

    private var detail: String? {
        triageItem?.detail
    }

    private var symbolName: String {
        switch status {
        case .readyToUpdate, .readyToCreateSavedInformation, .updatedCuratorNoteOnly:
            return "checkmark.circle"
        case .alreadyUpdated:
            return "checkmark.seal"
        case .needsAttention:
            return "exclamationmark.triangle"
        }
    }

    private var tint: Color {
        switch status {
        case .readyToUpdate, .readyToCreateSavedInformation, .updatedCuratorNoteOnly:
            return .green
        case .alreadyUpdated:
            return .blue
        case .needsAttention:
            return .orange
        }
    }
}
