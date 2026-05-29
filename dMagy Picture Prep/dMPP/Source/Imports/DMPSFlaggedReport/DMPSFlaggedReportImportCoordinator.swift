import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

// ================================================================
// DMPSFlaggedReportImportCoordinator.swift
//
// Purpose:
// - Coordinates the read-only dMPS Flagged Review Queue import flow.
// - Owns the current parsed import session and import error.
//
// Dependencies & Effects:
// - Uses NSOpenPanel to let the user choose a dMPS Flagged Review Queue file.
// - Uses DMPSFlaggedReportParser and the Picture Library Folder URL when one
//   is available.
// - Does not reference sidecar writers, tag stores, or durable metadata helpers.
//
// Data Flow:
// - App command or import window calls importReport(archiveRootURL:).
// - Coordinator asks the user for a report file, parses it, and publishes the
//   transient read-only session for DMPSFlaggedReportImportView.
//
// Section Index:
// - Published State
// - Public Actions
// - Session Summaries
// - File Selection
// - Helpers
// ================================================================

@MainActor
final class DMPSFlaggedReportImportCoordinator: ObservableObject {

    // MARK: - Published State

    @Published var currentSession: DMPSFlaggedImportSession?
    @Published var importErrorMessage: String?

    private var lastImportFolderURL: URL?
    private let chooseReportURL: (URL?) -> URL?

    init(chooseReportURL: ((URL?) -> URL?)? = nil) {
        self.chooseReportURL = chooseReportURL ?? Self.presentReportOpenPanel(startingDirectory:)
    }

    // MARK: - Public Actions

    @discardableResult
    func importReport(archiveRootURL: URL?) -> Bool {
        guard let reportURL = chooseReportURL(startingDirectoryURL(archiveRootURL: archiveRootURL)) else {
            return false
        }

        let parser = DMPSFlaggedReportParser(archiveRootURL: archiveRootURL)

        do {
            let session = try parser.parse(fileURL: reportURL)
            currentSession = session
            importErrorMessage = nil
            lastImportFolderURL = reportURL.deletingLastPathComponent()
            return true
        } catch {
            importErrorMessage = "dMPP could not open that report: \(error.localizedDescription)"
            return false
        }
    }

    func clearSession() {
        currentSession = nil
        importErrorMessage = nil
    }

    // MARK: - Session Summaries

    var totalItemCount: Int {
        currentSession?.items.count ?? 0
    }

    var validItemCount: Int {
        currentSession?.validationSummary.validItemCount ?? 0
    }

    var warningItemCount: Int {
        currentSession?.validationSummary.warningItemCount ?? 0
    }

    var invalidItemCount: Int {
        currentSession?.validationSummary.invalidItemCount ?? 0
    }

    var unresolvedItemCount: Int {
        currentSession?.items.filter {
            switch $0.pathResolution.status {
            case .missingLocator, .missingFile, .notResolved, .outsideArchiveRoot, .unsupportedImageExtension:
                return true
            case .hasAbsolutePath, .hasRelativePath:
                return false
            }
        }.count ?? 0
    }

    // MARK: - File Selection

    private static func presentReportOpenPanel(startingDirectory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Import dMPS Flagged Pictures Report"
        panel.message = "Choose a dMPS Flagged Review Queue file exported by dMagy Picture Show. dMPP will inspect it only; no saved information will be changed."
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.directoryURL = startingDirectory

        let result = panel.runModal()
        guard result == .OK else { return nil }
        return panel.url
    }

    private func startingDirectoryURL(archiveRootURL: URL?) -> URL? {
        if let lastImportFolderURL {
            return lastImportFolderURL
        }

        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL
        }

        return archiveRootURL
    }
}
