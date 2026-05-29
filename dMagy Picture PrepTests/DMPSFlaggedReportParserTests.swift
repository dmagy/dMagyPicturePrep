import Foundation
import Testing
@testable import dMagy_Picture_Prep

struct DMPSFlaggedReportParserTests {

    // MARK: - Sample Report

    @Test func parsesSampleReport() throws {
        let data = try Data(contentsOf: sampleReportURL())
        let session = DMPSFlaggedReportParser().parse(data: data)

        #expect(session.report?.schema == DMPSFlaggedReportConstants.supportedSchema)
        #expect(session.report?.schemaVersion == DMPSFlaggedReportConstants.supportedSchemaVersion)
        #expect(session.items.count == 5)
        #expect(session.topLevelIssues.isEmpty)
        #expect(session.validationSummary.invalidItemCount == 0)
    }

    // MARK: - Top-Level Validation

    @Test func invalidJSONCreatesErrorSession() {
        let session = DMPSFlaggedReportParser().parse(data: Data("not json".utf8))

        #expect(session.report == nil)
        #expect(session.items.isEmpty)
        #expect(session.topLevelIssues.contains { $0.code == .invalidJSON && $0.severity == .error })
    }

    @Test func unsupportedSchemaAndVersionProduceErrors() throws {
        let json = """
        {
          "schema": "example.unsupported",
          "schemaVersion": 99,
          "createdAt": "2026-05-25T16:08:00Z",
          "items": []
        }
        """

        let session = DMPSFlaggedReportParser().parse(data: Data(json.utf8))

        #expect(session.topLevelIssues.contains { $0.code == .unsupportedSchema })
        #expect(session.topLevelIssues.contains { $0.code == .unsupportedSchemaVersion })
        #expect(session.topLevelIssues.contains { $0.code == .emptyItems && $0.severity == .warning })
    }

    // MARK: - Item Validation

    @Test func duplicateIDsAreInvalid() {
        let id = "14B35749-D1B2-4E48-A4F3-45A49AED41F2"
        let json = reportJSON(items: """
        [
          \(validItemJSON(id: id)),
          \(validItemJSON(id: id))
        ]
        """)

        let session = DMPSFlaggedReportParser().parse(data: Data(json.utf8))

        #expect(session.items.count == 2)
        #expect(session.items.allSatisfy { $0.validationStatus == .invalid })
        #expect(session.items.allSatisfy { item in
            item.validationIssues.contains { $0.code == .duplicateID }
        })
    }

    @Test func missingLocatorIsInvalid() {
        let json = reportJSON(items: """
        [
          {
            "id": "14B35749-D1B2-4E48-A4F3-45A49AED41F2",
            "flaggedAt": "2026-05-28T02:55:52Z",
            "suggestedDMPMSTags": ["Flagged"],
            "suggestedReviewNote": "Flagged in dMagy Picture Show for later review."
          }
        ]
        """)

        let session = DMPSFlaggedReportParser().parse(data: Data(json.utf8))

        #expect(session.items.count == 1)
        #expect(session.items[0].validationStatus == .invalid)
        #expect(session.items[0].pathResolution.status == .missingLocator)
        #expect(session.items[0].validationIssues.contains { $0.code == .missingLocator })
    }

    // MARK: - Path Classification

    @Test func classifiesAbsolutePathInsideArchiveRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DMPSFlaggedReportParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = root.appendingPathComponent("sample.jpg")
        try Data().write(to: imageURL)

        let json = reportJSON(items: """
        [
          \(validItemJSON(id: "14B35749-D1B2-4E48-A4F3-45A49AED41F2", imageAbsolutePath: imageURL.path))
        ]
        """)

        let session = DMPSFlaggedReportParser(archiveRootURL: root).parse(data: Data(json.utf8))

        #expect(session.items.count == 1)
        #expect(session.items[0].validationStatus == .valid)
        #expect(session.items[0].pathResolution.status == .hasAbsolutePath)
        #expect(session.items[0].pathResolution.isInsideArchiveRoot == true)
        #expect(session.items[0].pathResolution.fileExists == true)
    }

    // MARK: - Helpers

    private func sampleReportURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dMagy Picture Prep")
            .appendingPathComponent("Docs/dMPP/Sample Imports/dMPS Flagged Review Queue.json")
    }

    private func reportJSON(items: String) -> String {
        """
        {
          "schema": "\(DMPSFlaggedReportConstants.supportedSchema)",
          "schemaVersion": \(DMPSFlaggedReportConstants.supportedSchemaVersion),
          "createdAt": "2026-05-25T16:08:00Z",
          "updatedAt": "2026-05-28T02:55:55Z",
          "items": \(items)
        }
        """
    }

    private func validItemJSON(
        id: String,
        imageAbsolutePath: String = "/tmp/sample.jpg"
    ) -> String {
        """
        {
          "id": "\(id)",
          "imageAbsolutePath": "\(escapedJSON(imageAbsolutePath))",
          "flaggedAt": "2026-05-28T02:55:52Z",
          "runtimeFlagState": "flagged",
          "sidecarStatusAtFlag": "notChecked",
          "suggestedDMPMSTags": ["Flagged"],
          "suggestedReviewNote": "Flagged in dMagy Picture Show for later review."
        }
        """
    }

    private func escapedJSON(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
