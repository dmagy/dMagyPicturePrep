import Foundation

// ================================================================
// DMPSFlaggedReportValidation.swift
//
// Purpose:
// - Defines structured validation issues and status values for dMPS
//   Flagged Pictures Report import sessions.
//
// Dependencies & Effects:
// - Depends only on Foundation.
// - Performs no file I/O, sidecar writes, tag updates, or UI work.
//
// Data Flow:
// - DMPSFlaggedReportParser creates validation issues while decoding and
//   validating reports.
// - DMPSFlaggedImportSession summarizes issues for future review UI.
//
// Section Index:
// - Severity
// - Validation Codes
// - Validation Issue
// - Item Status
// - Validation Summary
// ================================================================

// MARK: - Severity

enum DMPSFlaggedReportValidationSeverity: String, Codable, Equatable {
    case info
    case warning
    case error
}

// MARK: - Validation Codes

enum DMPSFlaggedReportValidationCode: String, Codable, Equatable {
    case invalidJSON
    case unsupportedSchema
    case unsupportedSchemaVersion
    case missingItems
    case emptyItems
    case invalidCreatedAt
    case invalidUpdatedAt
    case missingID
    case invalidID
    case duplicateID
    case missingLocator
    case invalidFlaggedAt
    case emptySuggestedReviewNote
    case unexpectedRuntimeFlagState
    case unexpectedSidecarStatusAtFlag
    case suggestedTagsMissingFlagged
    case absolutePathOutsideArchiveRoot
    case imageFileMissing
    case unsupportedImageExtension
}

// MARK: - Validation Issue

struct DMPSFlaggedReportValidationIssue: Codable, Equatable, Identifiable {
    var id: UUID
    var severity: DMPSFlaggedReportValidationSeverity
    var code: DMPSFlaggedReportValidationCode
    var itemID: String?
    var message: String

    init(
        id: UUID = UUID(),
        severity: DMPSFlaggedReportValidationSeverity,
        code: DMPSFlaggedReportValidationCode,
        itemID: String? = nil,
        message: String
    ) {
        self.id = id
        self.severity = severity
        self.code = code
        self.itemID = itemID
        self.message = message
    }
}

// MARK: - Item Status

enum DMPSFlaggedReportItemValidationStatus: String, Codable, Equatable {
    case valid
    case validWithWarnings
    case invalid

    static func from(issues: [DMPSFlaggedReportValidationIssue]) -> Self {
        if issues.contains(where: { $0.severity == .error }) {
            return .invalid
        }

        if issues.contains(where: { $0.severity == .warning }) {
            return .validWithWarnings
        }

        return .valid
    }
}

// MARK: - Validation Summary

struct DMPSFlaggedReportValidationSummary: Codable, Equatable {
    var totalIssueCount: Int
    var errorCount: Int
    var warningCount: Int
    var infoCount: Int
    var invalidItemCount: Int
    var warningItemCount: Int
    var validItemCount: Int

    init(
        topLevelIssues: [DMPSFlaggedReportValidationIssue],
        items: [DMPSFlaggedImportSessionItem]
    ) {
        let allIssues = topLevelIssues + items.flatMap(\.validationIssues)

        totalIssueCount = allIssues.count
        errorCount = allIssues.filter { $0.severity == .error }.count
        warningCount = allIssues.filter { $0.severity == .warning }.count
        infoCount = allIssues.filter { $0.severity == .info }.count
        invalidItemCount = items.filter { $0.validationStatus == .invalid }.count
        warningItemCount = items.filter { $0.validationStatus == .validWithWarnings }.count
        validItemCount = items.filter { $0.validationStatus == .valid }.count
    }
}
