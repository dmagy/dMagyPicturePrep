import SwiftUI

// ================================================================
// DMPSFlaggedTriageActionView.swift
//
// Purpose:
// - Shows the single future batch action for the dMPS Flagged Review Queue
//   triage workflow.
// - Keeps revised Phase 4A explicitly preview-only and no-write.
//
// Dependencies & Effects:
// - Depends on SwiftUI and DMPSFlaggedTriageCoordinator.
// - Displays in-memory summary data only.
// - Performs no file I/O, sidecar writes, tag updates, curator note changes,
//   or image changes.
//
// Data Flow:
// - DMPSFlaggedReportImportView passes the triage coordinator.
// - This view renders the disabled future action and no-write explanation.
//
// Section Index:
// - Action View
// ================================================================

// MARK: - Action View

struct DMPSFlaggedTriageActionView: View {
    @ObservedObject var triageCoordinator: DMPSFlaggedTriageCoordinator

    private var summary: DMPSFlaggedTriageSummary {
        triageCoordinator.summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import triage")
                        .font(.headline)

                    Text("dMPP can bring ready dMPS flagged pictures into your normal dMPP Flagged review workflow.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button("Tag Ready Pictures as Flagged") {
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
            }

            Text("When enabled, dMPP will tag ready pictures as Flagged and add this curator note:")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("\"\(DMPSFlaggedTriageConstants.stableCuratorNote)\"")
                .font(.callout.weight(.semibold))
                .textSelection(.enabled)

            Text("Preview only. No saved information has been changed.")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)

            Text("Future update preview: \(summary.readyForFutureUpdateCount) ready, \(summary.alreadyUpdatedCount) already updated, \(summary.needsAttentionCount) need attention.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}
