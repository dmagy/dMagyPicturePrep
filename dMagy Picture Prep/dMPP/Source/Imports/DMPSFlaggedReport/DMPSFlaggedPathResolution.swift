import Foundation

// ================================================================
// DMPSFlaggedPathResolution.swift
//
// Purpose:
// - Classifies dMPS report item paths for Phase 1 import sessions.
// - Establishes a placeholder boundary for later relinking/review queues.
//
// Dependencies & Effects:
// - Depends only on Foundation and FileManager existence checks.
// - Does not search broadly, present UI, write mappings, inspect sidecars,
//   update tags, or modify image files.
//
// Data Flow:
// - DMPSFlaggedReportParser passes report items to DMPSFlaggedPathResolver.
// - The resolver returns a lightweight classification stored in the session.
//
// Section Index:
// - Resolution Status
// - Resolved Path
// - Path Resolver
// - Helpers
// ================================================================

// MARK: - Resolution Status

enum DMPSFlaggedPathResolutionStatus: String, Codable, Equatable {
    case notResolved
    case hasAbsolutePath
    case hasRelativePath
    case missingLocator
    case outsideArchiveRoot
    case missingFile
    case unsupportedImageExtension
}

// MARK: - Resolved Path

struct DMPSFlaggedResolvedPath: Codable, Equatable {
    var status: DMPSFlaggedPathResolutionStatus
    var originalPath: String?
    var candidateURL: URL?
    var isInsideArchiveRoot: Bool?
    var fileExists: Bool?
    var pathIssues: [DMPSFlaggedReportValidationIssue]

    static let notResolved = DMPSFlaggedResolvedPath(
        status: .notResolved,
        originalPath: nil,
        candidateURL: nil,
        isInsideArchiveRoot: nil,
        fileExists: nil,
        pathIssues: []
    )
}

// MARK: - Path Resolver

struct DMPSFlaggedPathResolver {
    var archiveRootURL: URL?
    var fileManager: FileManager

    init(
        archiveRootURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.archiveRootURL = archiveRootURL?.standardizedFileURL
        self.fileManager = fileManager
    }

    func classify(_ item: DMPSFlaggedReportItem) -> DMPSFlaggedResolvedPath {
        guard item.trimmedImageAbsolutePath != nil || item.trimmedRelativePath != nil else {
            return DMPSFlaggedResolvedPath(
                status: .missingLocator,
                originalPath: nil,
                candidateURL: nil,
                isInsideArchiveRoot: nil,
                fileExists: nil,
                pathIssues: [
                    makeIssue(
                        severity: .error,
                        code: .missingLocator,
                        itemID: item.trimmedID,
                        message: "Item has no imageAbsolutePath or relativePath."
                    )
                ]
            )
        }

        if let absolutePath = item.trimmedImageAbsolutePath {
            return classifyAbsolutePath(absolutePath, item: item)
        }

        if let relativePath = item.trimmedRelativePath {
            return classifyRelativePath(relativePath, item: item)
        }

        return .notResolved
    }

    // MARK: - Absolute Paths

    private func classifyAbsolutePath(
        _ path: String,
        item: DMPSFlaggedReportItem
    ) -> DMPSFlaggedResolvedPath {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var issues: [DMPSFlaggedReportValidationIssue] = []

        if !isSupportedImageURL(url) {
            issues.append(makeIssue(
                severity: .warning,
                code: .unsupportedImageExtension,
                itemID: item.trimmedID,
                message: "Image path has an unsupported or unknown image extension."
            ))
            return DMPSFlaggedResolvedPath(
                status: .unsupportedImageExtension,
                originalPath: path,
                candidateURL: url,
                isInsideArchiveRoot: isInsideArchiveRoot(url),
                fileExists: fileManager.fileExists(atPath: url.path),
                pathIssues: issues
            )
        }

        let insideRoot = isInsideArchiveRoot(url)
        if insideRoot == false {
            issues.append(makeIssue(
                severity: .warning,
                code: .absolutePathOutsideArchiveRoot,
                itemID: item.trimmedID,
                message: "Absolute image path is outside the active Picture Library Folder."
            ))
            return DMPSFlaggedResolvedPath(
                status: .outsideArchiveRoot,
                originalPath: path,
                candidateURL: url,
                isInsideArchiveRoot: false,
                fileExists: fileManager.fileExists(atPath: url.path),
                pathIssues: issues
            )
        }

        let exists = fileManager.fileExists(atPath: url.path)
        if !exists {
            issues.append(makeIssue(
                severity: .warning,
                code: .imageFileMissing,
                itemID: item.trimmedID,
                message: "Image file does not exist at the report path."
            ))
        }

        return DMPSFlaggedResolvedPath(
            status: exists ? .hasAbsolutePath : .missingFile,
            originalPath: path,
            candidateURL: url,
            isInsideArchiveRoot: insideRoot,
            fileExists: exists,
            pathIssues: issues
        )
    }

    // MARK: - Relative Paths

    private func classifyRelativePath(
        _ path: String,
        item: DMPSFlaggedReportItem
    ) -> DMPSFlaggedResolvedPath {
        guard let archiveRootURL else {
            return DMPSFlaggedResolvedPath(
                status: .hasRelativePath,
                originalPath: path,
                candidateURL: nil,
                isInsideArchiveRoot: nil,
                fileExists: nil,
                pathIssues: []
            )
        }

        let url = archiveRootURL.appendingPathComponent(path).standardizedFileURL
        var issues: [DMPSFlaggedReportValidationIssue] = []

        if !isSupportedImageURL(url) {
            issues.append(makeIssue(
                severity: .warning,
                code: .unsupportedImageExtension,
                itemID: item.trimmedID,
                message: "Relative image path has an unsupported or unknown image extension."
            ))
            return DMPSFlaggedResolvedPath(
                status: .unsupportedImageExtension,
                originalPath: path,
                candidateURL: url,
                isInsideArchiveRoot: true,
                fileExists: fileManager.fileExists(atPath: url.path),
                pathIssues: issues
            )
        }

        let exists = fileManager.fileExists(atPath: url.path)
        if !exists {
            issues.append(makeIssue(
                severity: .warning,
                code: .imageFileMissing,
                itemID: item.trimmedID,
                message: "Image file does not exist at the relative report path."
            ))
        }

        return DMPSFlaggedResolvedPath(
            status: exists ? .hasRelativePath : .missingFile,
            originalPath: path,
            candidateURL: url,
            isInsideArchiveRoot: true,
            fileExists: exists,
            pathIssues: issues
        )
    }

    // MARK: - Helpers

    private func isInsideArchiveRoot(_ url: URL) -> Bool? {
        guard let archiveRootURL else { return nil }

        let rootPath = archiveRootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path

        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private func isSupportedImageURL(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = [
            "jpg", "jpeg", "png", "tif", "tiff", "heic", "heif", "webp",
            "dng", "raw", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2"
        ]

        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !ext.isEmpty && supportedExtensions.contains(ext)
    }

    private func makeIssue(
        severity: DMPSFlaggedReportValidationSeverity,
        code: DMPSFlaggedReportValidationCode,
        itemID: String,
        message: String
    ) -> DMPSFlaggedReportValidationIssue {
        DMPSFlaggedReportValidationIssue(
            severity: severity,
            code: code,
            itemID: itemID.isEmpty ? nil : itemID,
            message: message
        )
    }
}
