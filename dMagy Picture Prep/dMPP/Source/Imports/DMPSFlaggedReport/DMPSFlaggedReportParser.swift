import Foundation

// ================================================================
// DMPSFlaggedReportParser.swift
//
// Purpose:
// - Parses dMPS Flagged Pictures Report JSON into a Phase 1 import session.
// - Validates report shape and item readiness without applying metadata.
//
// Dependencies & Effects:
// - Depends only on Foundation and sibling Phase 1 import types.
// - Reads a report file only when parse(fileURL:) is called.
// - Does not open file pickers, inspect sidecars, write sidecars, update tags,
//   append curator notes, or build UI.
//
// Data Flow:
// - JSON data/file URL enters the parser.
// - Parser decodes DMPSFlaggedReport, validates it, classifies item paths,
//   and returns DMPSFlaggedImportSession.
//
// Section Index:
// - Parser Configuration
// - Public Parse API
// - Session Construction
// - Top-Level Validation
// - Item Validation
// - Helpers
// ================================================================

// MARK: - Parser Configuration

struct DMPSFlaggedReportParser {
    var archiveRootURL: URL?
    var fileManager: FileManager
    var now: () -> Date

    init(
        archiveRootURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init
    ) {
        self.archiveRootURL = archiveRootURL
        self.fileManager = fileManager
        self.now = now
    }

    // MARK: - Public Parse API

    func parse(data: Data) -> DMPSFlaggedImportSession {
        do {
            let decoder = JSONDecoder()
            let report = try decoder.decode(DMPSFlaggedReport.self, from: data)
            return makeSession(report: report, sourceReportURL: nil)
        } catch {
            return DMPSFlaggedImportSession(
                importedAt: now(),
                topLevelIssues: [
                    DMPSFlaggedReportValidationIssue(
                        severity: .error,
                        code: .invalidJSON,
                        message: "Report is not valid dMPS Flagged Pictures Report JSON: \(error.localizedDescription)"
                    )
                ]
            )
        }
    }

    func parse(fileURL: URL) throws -> DMPSFlaggedImportSession {
        let data = try Data(contentsOf: fileURL)
        var session = parse(data: data)
        session.sourceReportURL = fileURL
        return session
    }

    // MARK: - Session Construction

    private func makeSession(
        report: DMPSFlaggedReport,
        sourceReportURL: URL?
    ) -> DMPSFlaggedImportSession {
        let createdAtResult = parseISO8601(report.createdAt)
        let updatedAtResult = parseOptionalISO8601(report.updatedAt)
        var topLevelIssues = validateTopLevel(
            report: report,
            createdAtIsValid: createdAtResult != nil,
            updatedAtIsValid: updatedAtResult.isValid
        )

        let pathResolver = DMPSFlaggedPathResolver(
            archiveRootURL: archiveRootURL,
            fileManager: fileManager
        )

        var seenIDs: [String: Int] = [:]
        let rawItems = report.items ?? []

        for item in rawItems {
            let trimmedID = item.trimmedID
            guard !trimmedID.isEmpty else { continue }
            seenIDs[trimmedID, default: 0] += 1
        }

        let sessionItems = rawItems.enumerated().map { index, item in
            let pathResolution = pathResolver.classify(item)
            var issues = validateItem(
                item,
                duplicateCount: seenIDs[item.trimmedID] ?? 0
            )
            issues.append(contentsOf: pathResolution.pathIssues)

            let validationStatus = DMPSFlaggedReportItemValidationStatus.from(issues: issues)
            let stableID = sessionItemID(for: item, index: index)

            return DMPSFlaggedImportSessionItem(
                id: stableID,
                reportItem: item,
                validationStatus: validationStatus,
                validationIssues: issues,
                pathResolution: pathResolution
            )
        }

        if report.items == nil {
            topLevelIssues.append(DMPSFlaggedReportValidationIssue(
                severity: .error,
                code: .missingItems,
                message: "Report is missing the required items array."
            ))
        } else if rawItems.isEmpty {
            topLevelIssues.append(DMPSFlaggedReportValidationIssue(
                severity: .warning,
                code: .emptyItems,
                message: "Report contains no flagged items."
            ))
        }

        return DMPSFlaggedImportSession(
            sourceReportURL: sourceReportURL,
            report: report,
            createdAt: createdAtResult,
            updatedAt: updatedAtResult.date,
            importedAt: now(),
            topLevelIssues: topLevelIssues,
            items: sessionItems
        )
    }

    // MARK: - Top-Level Validation

    private func validateTopLevel(
        report: DMPSFlaggedReport,
        createdAtIsValid: Bool,
        updatedAtIsValid: Bool
    ) -> [DMPSFlaggedReportValidationIssue] {
        var issues: [DMPSFlaggedReportValidationIssue] = []

        if report.schema != DMPSFlaggedReportConstants.supportedSchema {
            issues.append(DMPSFlaggedReportValidationIssue(
                severity: .error,
                code: .unsupportedSchema,
                message: "Report schema is not supported."
            ))
        }

        if report.schemaVersion != DMPSFlaggedReportConstants.supportedSchemaVersion {
            issues.append(DMPSFlaggedReportValidationIssue(
                severity: .error,
                code: .unsupportedSchemaVersion,
                message: "Report schemaVersion is not supported."
            ))
        }

        if !createdAtIsValid {
            issues.append(DMPSFlaggedReportValidationIssue(
                severity: .error,
                code: .invalidCreatedAt,
                message: "Report createdAt is missing or not a valid ISO-8601 timestamp."
            ))
        }

        if !updatedAtIsValid {
            issues.append(DMPSFlaggedReportValidationIssue(
                severity: .warning,
                code: .invalidUpdatedAt,
                message: "Report updatedAt is not a valid ISO-8601 timestamp."
            ))
        }

        return issues
    }

    // MARK: - Item Validation

    private func validateItem(
        _ item: DMPSFlaggedReportItem,
        duplicateCount: Int
    ) -> [DMPSFlaggedReportValidationIssue] {
        var issues: [DMPSFlaggedReportValidationIssue] = []
        let trimmedID = item.trimmedID
        let issueItemID = trimmedID.isEmpty ? nil : trimmedID

        if trimmedID.isEmpty {
            issues.append(makeIssue(
                severity: .error,
                code: .missingID,
                itemID: issueItemID,
                message: "Item is missing an id."
            ))
        } else if UUID(uuidString: trimmedID) == nil {
            issues.append(makeIssue(
                severity: .error,
                code: .invalidID,
                itemID: issueItemID,
                message: "Item id is not a valid UUID string."
            ))
        }

        if duplicateCount > 1 {
            issues.append(makeIssue(
                severity: .error,
                code: .duplicateID,
                itemID: issueItemID,
                message: "Item id appears more than once in this report."
            ))
        }

        if item.trimmedImageAbsolutePath == nil && item.trimmedRelativePath == nil {
            issues.append(makeIssue(
                severity: .error,
                code: .missingLocator,
                itemID: issueItemID,
                message: "Item has no imageAbsolutePath or relativePath."
            ))
        }

        if parseISO8601(item.flaggedAt) == nil {
            issues.append(makeIssue(
                severity: .error,
                code: .invalidFlaggedAt,
                itemID: issueItemID,
                message: "Item flaggedAt is missing or not a valid ISO-8601 timestamp."
            ))
        }

        if item.trimmedSuggestedReviewNote == nil {
            issues.append(makeIssue(
                severity: .warning,
                code: .emptySuggestedReviewNote,
                itemID: issueItemID,
                message: "Item suggestedReviewNote is empty or missing."
            ))
        }

        if item.runtimeFlagState == .unknown {
            issues.append(makeIssue(
                severity: .warning,
                code: .unexpectedRuntimeFlagState,
                itemID: issueItemID,
                message: "Item runtimeFlagState is not a known Phase 1 value."
            ))
        }

        if item.sidecarStatusAtFlag == .unknown {
            issues.append(makeIssue(
                severity: .warning,
                code: .unexpectedSidecarStatusAtFlag,
                itemID: issueItemID,
                message: "Item sidecarStatusAtFlag is not a known Phase 1 value."
            ))
        }

        let suggestedTags = item.suggestedDMPMSTags ?? []
        let hasFlaggedTag = suggestedTags.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(DMPSFlaggedReportConstants.canonicalFlaggedTag) == .orderedSame
        }

        if !hasFlaggedTag {
            issues.append(makeIssue(
                severity: .warning,
                code: .suggestedTagsMissingFlagged,
                itemID: issueItemID,
                message: "Item suggestedDMPMSTags does not include Flagged."
            ))
        }

        return issues
    }

    // MARK: - Helpers

    private func parseISO8601(_ value: String?) -> Date? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Self.iso8601Formatter.date(from: trimmed)
            ?? Self.iso8601FormatterWithFractionalSeconds.date(from: trimmed)
    }

    private func parseOptionalISO8601(_ value: String?) -> (date: Date?, isValid: Bool) {
        guard let value else { return (nil, true) }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (nil, false) }
        guard let date = Self.iso8601Formatter.date(from: trimmed) else {
            return (nil, false)
        }
        return (date, true)
    }

    private func sessionItemID(for item: DMPSFlaggedReportItem, index: Int) -> String {
        let trimmedID = item.trimmedID
        if !trimmedID.isEmpty {
            return trimmedID
        }

        return "invalid-item-\(index)"
    }

    private func makeIssue(
        severity: DMPSFlaggedReportValidationSeverity,
        code: DMPSFlaggedReportValidationCode,
        itemID: String?,
        message: String
    ) -> DMPSFlaggedReportValidationIssue {
        DMPSFlaggedReportValidationIssue(
            severity: severity,
            code: code,
            itemID: itemID,
            message: message
        )
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let iso8601FormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
