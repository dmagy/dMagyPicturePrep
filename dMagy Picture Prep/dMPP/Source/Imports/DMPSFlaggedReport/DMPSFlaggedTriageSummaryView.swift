import SwiftUI

// ================================================================
// DMPSFlaggedTriageSummaryView.swift
//
// Purpose:
// - Shows the Phase 4A no-write triage summary for an imported dMPS
//   Flagged Review Queue.
//
// Dependencies & Effects:
// - Depends on SwiftUI and DMPSFlaggedTriageCoordinator.
// - Displays in-memory triage data only.
// - Performs no file I/O, sidecar writes, tag updates, curator note changes,
//   or image changes.
//
// Data Flow:
// - DMPSFlaggedReportImportView passes the current triage coordinator.
// - This view renders the queue/status counts.
//
// Section Index:
// - Summary View
// - Tile
// ================================================================

// MARK: - Summary View

struct DMPSFlaggedTriageSummaryView: View {
    @ObservedObject var triageCoordinator: DMPSFlaggedTriageCoordinator

    private var summary: DMPSFlaggedTriageSummary {
        triageCoordinator.summary
    }

    var body: some View {
        HStack(spacing: 8) {
            summaryTile("\(summary.totalCount)", "pictures in review queue")
            summaryTile("\(summary.readyForFutureUpdateCount)", "ready to tag as Flagged")
            summaryTile("\(summary.alreadyUpdatedCount)", "already updated")
            summaryTile("\(summary.needsAttentionCount)", "needs attention")
        }
    }

    // MARK: - Tile

    private func summaryTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minWidth: 145, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
    }
}
