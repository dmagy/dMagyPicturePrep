import Foundation

// ================================================================
// DMPSFlaggedSidecarInspection.swift
//
// Purpose:
// - Defines read-only dMPMS sidecar inspection for dMPS Flagged Review
//   Queue import sessions.
// - Classifies current saved information without changing it.
//
// Dependencies & Effects:
// - Depends on Foundation, DmpmsMetadata, and Phase 1 import session types.
// - Reads at most the exact sidecar file derived from a resolved image path.
// - Does not create sidecars, repair sidecars, change tags, change curator
//   notes, modify images, or persist inspection results.
//
// Data Flow:
// - DMPSFlaggedReportImportCoordinator passes session items to the inspector.
// - The inspector returns in-memory status/results keyed by session item ID.
// - DMPSFlaggedReportImportView displays those results as inspection-only data.
//
// Section Index:
// - Inspection Status
// - Readiness
// - Inspection Result
// - Inspection Summary
// - Inspector
// - Helpers
// ================================================================

// MARK: - Inspection Status

enum DMPSFlaggedSidecarInspectionStatus: String, Codable, Equatable {
    case notInspected
    case unresolvedImage
    case imageMissing
    case sidecarMissing
    case sidecarInvalid
    case sidecarValid
    case sourceFileMismatch
    case readError
}

// MARK: - Readiness

enum DMPSFlaggedSidecarReadiness: String, Codable, Equatable {
    case readyForFutureApply
    case alreadyFlagged
    case needsSidecar
    case needsRepair
    case needsResolvedImage
}

// MARK: - Inspection Result

struct DMPSFlaggedSidecarInspectionResult: Identifiable, Equatable {
    var id: String { itemID }

    var itemID: String
    var status: DMPSFlaggedSidecarInspectionStatus
    var readiness: DMPSFlaggedSidecarReadiness
    var imageURL: URL?
    var sidecarURL: URL?
    var sourceFile: String?
    var expectedSourceFile: String?
    var sourceFileMatches: Bool?
    var currentTags: [String]
    var containsFlaggedTag: Bool
    var curatorNotesPreview: String?
    var curatorNotesIsEmpty: Bool
    var errorMessage: String?
}

// MARK: - Inspection Summary

struct DMPSFlaggedSidecarInspectionSummary: Equatable {
    var totalInspectedCount: Int
    var validSidecarCount: Int
    var missingSidecarCount: Int
    var invalidSidecarCount: Int
    var readErrorCount: Int
    var sourceFileMismatchCount: Int
    var alreadyFlaggedCount: Int
    var needsAttentionCount: Int

    init(results: [DMPSFlaggedSidecarInspectionResult]) {
        totalInspectedCount = results.count
        validSidecarCount = results.filter { $0.status == .sidecarValid }.count
        missingSidecarCount = results.filter { $0.status == .sidecarMissing }.count
        invalidSidecarCount = results.filter { $0.status == .sidecarInvalid }.count
        readErrorCount = results.filter { $0.status == .readError }.count
        sourceFileMismatchCount = results.filter { $0.status == .sourceFileMismatch }.count
        alreadyFlaggedCount = results.filter { $0.containsFlaggedTag }.count
        needsAttentionCount = results.filter {
            switch $0.readiness {
            case .readyForFutureApply, .alreadyFlagged:
                return false
            case .needsSidecar, .needsRepair, .needsResolvedImage:
                return true
            }
        }.count
    }

    static let empty = DMPSFlaggedSidecarInspectionSummary(results: [])
}

// MARK: - Inspector

struct DMPSFlaggedSidecarInspector {
    var fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspect(items: [DMPSFlaggedImportSessionItem]) -> [String: DMPSFlaggedSidecarInspectionResult] {
        var results: [String: DMPSFlaggedSidecarInspectionResult] = [:]

        for item in items {
            let result = inspect(item: item)
            results[item.id] = result
        }

        return results
    }

    func inspect(item: DMPSFlaggedImportSessionItem) -> DMPSFlaggedSidecarInspectionResult {
        guard let imageURL = item.pathResolution.candidateURL else {
            return baseResult(
                itemID: item.id,
                status: .unresolvedImage,
                readiness: .needsResolvedImage,
                errorMessage: "No resolved picture path is available for this report item."
            )
        }

        if item.pathResolution.fileExists == false {
            return baseResult(
                itemID: item.id,
                status: .imageMissing,
                readiness: .needsResolvedImage,
                imageURL: imageURL,
                expectedSourceFile: imageURL.lastPathComponent,
                errorMessage: "The picture file was not found at the report path."
            )
        }

        switch item.pathResolution.status {
        case .hasAbsolutePath, .hasRelativePath:
            return inspectSidecar(itemID: item.id, imageURL: imageURL)
        case .notResolved, .missingLocator, .missingFile, .outsideArchiveRoot, .unsupportedImageExtension:
            return baseResult(
                itemID: item.id,
                status: .unresolvedImage,
                readiness: .needsResolvedImage,
                imageURL: imageURL,
                expectedSourceFile: imageURL.lastPathComponent,
                errorMessage: "The picture path is not ready for saved information inspection."
            )
        }
    }

    // MARK: - Helpers

    private func inspectSidecar(
        itemID: String,
        imageURL: URL
    ) -> DMPSFlaggedSidecarInspectionResult {
        let sidecarURL = imageURL.appendingPathExtension("dmpms.json")
        let expectedSourceFile = imageURL.lastPathComponent

        guard fileManager.fileExists(atPath: sidecarURL.path) else {
            return baseResult(
                itemID: itemID,
                status: .sidecarMissing,
                readiness: .needsSidecar,
                imageURL: imageURL,
                sidecarURL: sidecarURL,
                expectedSourceFile: expectedSourceFile,
                errorMessage: "No saved information file exists beside this picture."
            )
        }

        do {
            let data = try Data(contentsOf: sidecarURL)
            let metadata = try JSONDecoder().decode(DmpmsMetadata.self, from: data)
            let sourceFileMatches = metadata.sourceFile == expectedSourceFile
            let containsFlaggedTag = containsFlagged(in: metadata.tags)
            let status: DMPSFlaggedSidecarInspectionStatus = sourceFileMatches ? .sidecarValid : .sourceFileMismatch
            let readiness: DMPSFlaggedSidecarReadiness

            if !sourceFileMatches {
                readiness = .needsRepair
            } else if containsFlaggedTag {
                readiness = .alreadyFlagged
            } else {
                readiness = .readyForFutureApply
            }

            return DMPSFlaggedSidecarInspectionResult(
                itemID: itemID,
                status: status,
                readiness: readiness,
                imageURL: imageURL,
                sidecarURL: sidecarURL,
                sourceFile: metadata.sourceFile,
                expectedSourceFile: expectedSourceFile,
                sourceFileMatches: sourceFileMatches,
                currentTags: metadata.tags,
                containsFlaggedTag: containsFlaggedTag,
                curatorNotesPreview: notesPreview(metadata.curatorNotes),
                curatorNotesIsEmpty: metadata.curatorNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                errorMessage: sourceFileMatches ? nil : "The saved information sourceFile does not match this picture filename."
            )
        } catch let decodingError as DecodingError {
            return baseResult(
                itemID: itemID,
                status: .sidecarInvalid,
                readiness: .needsRepair,
                imageURL: imageURL,
                sidecarURL: sidecarURL,
                expectedSourceFile: expectedSourceFile,
                errorMessage: decodingError.localizedDescription
            )
        } catch {
            return baseResult(
                itemID: itemID,
                status: .readError,
                readiness: .needsRepair,
                imageURL: imageURL,
                sidecarURL: sidecarURL,
                expectedSourceFile: expectedSourceFile,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func baseResult(
        itemID: String,
        status: DMPSFlaggedSidecarInspectionStatus,
        readiness: DMPSFlaggedSidecarReadiness,
        imageURL: URL? = nil,
        sidecarURL: URL? = nil,
        expectedSourceFile: String? = nil,
        errorMessage: String? = nil
    ) -> DMPSFlaggedSidecarInspectionResult {
        DMPSFlaggedSidecarInspectionResult(
            itemID: itemID,
            status: status,
            readiness: readiness,
            imageURL: imageURL,
            sidecarURL: sidecarURL,
            sourceFile: nil,
            expectedSourceFile: expectedSourceFile,
            sourceFileMatches: nil,
            currentTags: [],
            containsFlaggedTag: false,
            curatorNotesPreview: nil,
            curatorNotesIsEmpty: true,
            errorMessage: errorMessage
        )
    }

    private func containsFlagged(in tags: [String]) -> Bool {
        tags.contains {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(DMPPUserPreferences.reservedFlaggedTag) == .orderedSame
        }
    }

    private func notesPreview(_ notes: String) -> String? {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let limit = 400
        if trimmed.count <= limit {
            return trimmed
        }

        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[..<endIndex]) + "..."
    }
}
