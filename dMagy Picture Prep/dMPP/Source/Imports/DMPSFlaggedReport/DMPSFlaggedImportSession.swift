import Foundation

// ================================================================
// DMPSFlaggedImportSession.swift
//
// Purpose:
// - Defines the transient in-memory session created from a parsed dMPS
//   Flagged Pictures Report.
//
// Dependencies & Effects:
// - Depends only on Foundation and sibling Phase 1 import types.
// - Performs no file I/O, sidecar writes, tag updates, or UI work.
//
// Data Flow:
// - DMPSFlaggedReportParser decodes a report and creates session items.
// - Each session item holds original report data, validation status, and
//   placeholder path-resolution state.
//
// Section Index:
// - Import Session
// - Session Item
// - Convenience Summaries
// ================================================================

// MARK: - Import Session

struct DMPSFlaggedImportSession: Identifiable, Equatable {
    var id: UUID
    var sourceReportURL: URL?
    var report: DMPSFlaggedReport?
    var createdAt: Date?
    var updatedAt: Date?
    var importedAt: Date
    var topLevelIssues: [DMPSFlaggedReportValidationIssue]
    var items: [DMPSFlaggedImportSessionItem]

    init(
        id: UUID = UUID(),
        sourceReportURL: URL? = nil,
        report: DMPSFlaggedReport? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        importedAt: Date = Date(),
        topLevelIssues: [DMPSFlaggedReportValidationIssue] = [],
        items: [DMPSFlaggedImportSessionItem] = []
    ) {
        self.id = id
        self.sourceReportURL = sourceReportURL
        self.report = report
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.importedAt = importedAt
        self.topLevelIssues = topLevelIssues
        self.items = items
    }
}

// MARK: - Session Item

struct DMPSFlaggedImportSessionItem: Identifiable, Equatable {
    var id: String
    var reportItem: DMPSFlaggedReportItem
    var validationStatus: DMPSFlaggedReportItemValidationStatus
    var validationIssues: [DMPSFlaggedReportValidationIssue]
    var pathResolution: DMPSFlaggedResolvedPath
}

// MARK: - Convenience Summaries

extension DMPSFlaggedImportSession {
    var validationSummary: DMPSFlaggedReportValidationSummary {
        DMPSFlaggedReportValidationSummary(
            topLevelIssues: topLevelIssues,
            items: items
        )
    }

    var hasBlockingErrors: Bool {
        validationSummary.errorCount > 0
    }
}
