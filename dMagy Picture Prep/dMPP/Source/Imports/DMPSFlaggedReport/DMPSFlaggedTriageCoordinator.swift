import Combine
import Foundation

// ================================================================
// DMPSFlaggedTriageCoordinator.swift
//
// Purpose:
// - Builds the no-write Phase 4A triage/import plan for a dMPS Flagged
//   Review Queue session.
// - Classifies which queue items can safely be brought into the normal dMPP
//   Flagged review workflow later.
//
// Dependencies & Effects:
// - Depends on Phase 1-3 import/session/inspection types.
// - Stores triage results only in memory.
// - Performs no file I/O, sidecar writes, tag updates, curator note changes,
//   or image changes.
//
// Data Flow:
// - DMPSFlaggedReportImportCoordinator resets the triage plan after import,
//   read-only saved-information inspection, and clearing.
// - DMPSFlaggedReportImportView and small triage subviews render the plan.
//
// Section Index:
// - Published State
// - Session Lifecycle
// - Lookup
// - Classification
// - Messages
// ================================================================

@MainActor
final class DMPSFlaggedTriageCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var triageItems: [String: DMPSFlaggedTriageItem] = [:]

    var summary: DMPSFlaggedTriageSummary {
        DMPSFlaggedTriageSummary(items: Array(triageItems.values))
    }

    // MARK: - Session Lifecycle

    func reset(
        for session: DMPSFlaggedImportSession?,
        inspections: [String: DMPSFlaggedSidecarInspectionResult]
    ) {
        guard let session else {
            clear()
            return
        }

        var nextItems: [String: DMPSFlaggedTriageItem] = [:]

        for item in session.items {
            nextItems[item.id] = Self.classify(
                item: item,
                inspection: inspections[item.id]
            )
        }

        triageItems = nextItems
    }

    func clear() {
        triageItems = [:]
    }

    // MARK: - Lookup

    func triageItem(for itemID: String) -> DMPSFlaggedTriageItem? {
        triageItems[itemID]
    }

    // MARK: - Classification

    static func classify(
        item: DMPSFlaggedImportSessionItem,
        inspection: DMPSFlaggedSidecarInspectionResult?
    ) -> DMPSFlaggedTriageItem {
        guard item.validationStatus == .valid else {
            return needsAttention(
                itemID: item.id,
                message: genericNeedsAttentionMessage,
                detail: firstIssueMessage(from: item)
            )
        }

        switch item.pathResolution.status {
        case .outsideArchiveRoot:
            return needsAttention(
                itemID: item.id,
                message: "This picture is outside your current Picture Library Folder, so dMPP will not create saved information for it from this queue.",
                detail: "To prepare it in dMPP, manually move or copy it into your Picture Library Folder, then review it there."
            )
        case .missingFile:
            return needsAttention(
                itemID: item.id,
                message: "dMPP could not find the original picture at the location listed in the queue.",
                detail: "Find or restore the picture, then open it in dMPP to review it."
            )
        case .unsupportedImageExtension:
            return needsAttention(
                itemID: item.id,
                message: "This picture type is not supported by this import workflow.",
                detail: genericNeedsAttentionDetail
            )
        case .missingLocator, .notResolved:
            return needsAttention(
                itemID: item.id,
                message: "dMPP could not find a usable picture location in this queue item.",
                detail: genericNeedsAttentionDetail
            )
        case .hasAbsolutePath, .hasRelativePath:
            break
        }

        if item.pathResolution.fileExists == false {
            return needsAttention(
                itemID: item.id,
                message: "dMPP could not find the original picture at the location listed in the queue.",
                detail: "Find or restore the picture, then open it in dMPP to review it."
            )
        }

        guard item.pathResolution.isInsideArchiveRoot == true else {
            return needsAttention(
                itemID: item.id,
                message: "This picture is outside your current Picture Library Folder, so dMPP will not create saved information for it from this queue.",
                detail: "To prepare it in dMPP, manually move or copy it into your Picture Library Folder, then review it there."
            )
        }

        guard let inspection else {
            return needsAttention(
                itemID: item.id,
                message: "dMPP has not inspected the current saved information for this picture yet.",
                detail: genericNeedsAttentionDetail
            )
        }

        switch inspection.status {
        case .sidecarMissing:
            return DMPSFlaggedTriageItem(
                itemID: item.id,
                status: .readyToCreateSavedInformation,
                message: "No saved information exists yet. dMPP can create it because this picture is inside your Picture Library Folder.",
                detail: "Preview only. No saved information has been changed."
            )
        case .sidecarValid:
            return validSavedInformationItem(itemID: item.id, inspection: inspection)
        case .sourceFileMismatch:
            return needsAttention(
                itemID: item.id,
                message: "The saved information for this picture appears to belong to a different picture.",
                detail: "dMPP will not update it from this queue. Open the picture in dMPP to inspect the saved information before making changes."
            )
        case .sidecarInvalid, .readError:
            return needsAttention(
                itemID: item.id,
                message: "dMPP found saved information for this picture but could not read it.",
                detail: "Open the picture in dMPP to inspect or repair the saved information before updating it from this queue."
            )
        case .imageMissing:
            return needsAttention(
                itemID: item.id,
                message: "dMPP could not find the original picture at the location listed in the queue.",
                detail: "Find or restore the picture, then open it in dMPP to review it."
            )
        case .unresolvedImage, .notInspected:
            return needsAttention(
                itemID: item.id,
                message: genericNeedsAttentionMessage,
                detail: inspection.errorMessage ?? genericNeedsAttentionDetail
            )
        }
    }

    // MARK: - Messages

    private static let genericNeedsAttentionMessage = "dMPP will not update this picture from the queue until the issue is resolved."
    private static let genericNeedsAttentionDetail = "Find or open the picture in dMPP to see what needs attention."

    private static func validSavedInformationItem(
        itemID: String,
        inspection: DMPSFlaggedSidecarInspectionResult
    ) -> DMPSFlaggedTriageItem {
        let hasStableNote = inspection.curatorNotesContainsStableDMPSReviewNote

        if inspection.containsFlaggedTag && hasStableNote {
            return DMPSFlaggedTriageItem(
                itemID: itemID,
                status: .alreadyUpdated,
                message: "This picture is already marked as Flagged with the dMPS review note.",
                detail: "No queue update is needed."
            )
        }

        if inspection.containsFlaggedTag {
            return DMPSFlaggedTriageItem(
                itemID: itemID,
                status: .updatedCuratorNoteOnly,
                message: "This picture is already Flagged. dMPP can add the dMPS review note later.",
                detail: "Preview only. No saved information has been changed."
            )
        }

        return DMPSFlaggedTriageItem(
            itemID: itemID,
            status: .readyToUpdate,
            message: "dMPP can safely mark this picture as Flagged.",
            detail: "Preview only. No saved information has been changed."
        )
    }

    private static func needsAttention(
        itemID: String,
        message: String,
        detail: String?
    ) -> DMPSFlaggedTriageItem {
        DMPSFlaggedTriageItem(
            itemID: itemID,
            status: .needsAttention,
            message: message,
            detail: detail
        )
    }

    private static func firstIssueMessage(from item: DMPSFlaggedImportSessionItem) -> String? {
        item.validationIssues.first?.message ?? genericNeedsAttentionDetail
    }
}
