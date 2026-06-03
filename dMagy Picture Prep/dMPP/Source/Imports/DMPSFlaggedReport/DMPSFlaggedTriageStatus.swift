import Foundation

// ================================================================
// DMPSFlaggedTriageStatus.swift
//
// Purpose:
// - Defines the no-write triage/import-plan statuses for dMPS Flagged
//   Review Queue items.
// - Keeps Phase 4A focused on deciding whether dMPP can safely bring dMPS
//   review intent into the normal dMPP Flagged workflow later.
//
// Dependencies & Effects:
// - Depends only on Foundation.
// - Performs no file I/O, sidecar writes, tag updates, curator note changes,
//   or image changes.
//
// Data Flow:
// - DMPSFlaggedTriageCoordinator creates one triage item per imported report
//   item after validation and read-only saved-information inspection.
// - Triage views render the status and no-write future update preview.
//
// Section Index:
// - Constants
// - Triage Status
// - Triage Item
// - Triage Summary
// ================================================================

// MARK: - Constants

enum DMPSFlaggedTriageConstants {
    static let stableCuratorNote = "Flagged in dMagy Picture Show for later review."
}

// MARK: - Triage Status

enum DMPSFlaggedTriageStatus: String, Codable, Equatable {
    case readyToUpdate
    case readyToCreateSavedInformation
    case updatedCuratorNoteOnly
    case alreadyUpdated
    case needsAttention

    var userLabel: String {
        switch self {
        case .readyToUpdate:
            return "Ready to tag as Flagged"
        case .readyToCreateSavedInformation:
            return "Ready to create saved information"
        case .updatedCuratorNoteOnly:
            return "Ready to add review note"
        case .alreadyUpdated:
            return "Already updated"
        case .needsAttention:
            return "Needs attention"
        }
    }
}

// MARK: - Triage Item

struct DMPSFlaggedTriageItem: Identifiable, Equatable {
    var id: String { itemID }

    var itemID: String
    var status: DMPSFlaggedTriageStatus
    var message: String
    var detail: String?
}

// MARK: - Triage Summary

struct DMPSFlaggedTriageSummary: Equatable {
    var totalCount: Int
    var readyToUpdateCount: Int
    var readyToCreateSavedInformationCount: Int
    var updatedCuratorNoteOnlyCount: Int
    var alreadyUpdatedCount: Int
    var needsAttentionCount: Int

    init(items: [DMPSFlaggedTriageItem]) {
        totalCount = items.count
        readyToUpdateCount = items.filter { $0.status == .readyToUpdate }.count
        readyToCreateSavedInformationCount = items.filter { $0.status == .readyToCreateSavedInformation }.count
        updatedCuratorNoteOnlyCount = items.filter { $0.status == .updatedCuratorNoteOnly }.count
        alreadyUpdatedCount = items.filter { $0.status == .alreadyUpdated }.count
        needsAttentionCount = items.filter { $0.status == .needsAttention }.count
    }

    var readyForFutureUpdateCount: Int {
        readyToUpdateCount + readyToCreateSavedInformationCount + updatedCuratorNoteOnlyCount
    }

    static let empty = DMPSFlaggedTriageSummary(items: [])
}
