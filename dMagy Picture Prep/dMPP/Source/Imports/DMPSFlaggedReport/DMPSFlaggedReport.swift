import Foundation

// ================================================================
// DMPSFlaggedReport.swift
//
// Purpose:
// - Defines the Codable model for dMPS Flagged Pictures Report JSON.
// - Keeps dMPS review intent separate from dMPP durable metadata writes.
//
// Dependencies & Effects:
// - Depends only on Foundation.
// - Performs no file I/O, sidecar writes, tag updates, or UI work.
//
// Data Flow:
// - DMPSFlaggedReportParser decodes JSON into these types.
// - Validation/session types inspect these decoded values.
// - Later phases can present or apply this intent through separate flows.
//
// Section Index:
// - Constants
// - Report Model
// - Report Item Model
// - Known dMPS Status Values
// ================================================================

// MARK: - Constants

enum DMPSFlaggedReportConstants {
    static let supportedSchema = "com.dmagy.dmps.flaggedReviewQueue"
    static let supportedSchemaVersion = 1
    static let canonicalFlaggedTag = "Flagged"
}

// MARK: - Report Model

struct DMPSFlaggedReport: Codable, Equatable {
    var schema: String?
    var schemaVersion: Int?
    var createdAt: String?
    var updatedAt: String?
    var createdBy: String?
    var sourceAppVersion: String?
    var archiveRootHint: String?
    var items: [DMPSFlaggedReportItem]?
}

// MARK: - Report Item Model

struct DMPSFlaggedReportItem: Codable, Identifiable, Equatable {
    private var rawID: String?

    var id: String {
        rawID ?? ""
    }

    var imageAbsolutePath: String?
    var relativePath: String?
    var filename: String?
    var flaggedAt: String?
    var flagSource: String?
    var suggestedDMPMSTags: [String]?
    var suggestedReviewNote: String?
    var runtimeFlagState: DMPSFlaggedReportRuntimeFlagState?
    var sidecarStatusAtFlag: DMPSFlaggedReportSidecarStatusAtFlag?

    enum CodingKeys: String, CodingKey {
        case rawID = "id"
        case imageAbsolutePath
        case relativePath
        case filename
        case flaggedAt
        case flagSource
        case suggestedDMPMSTags
        case suggestedReviewNote
        case runtimeFlagState
        case sidecarStatusAtFlag
    }

    init(
        rawID: String? = nil,
        imageAbsolutePath: String? = nil,
        relativePath: String? = nil,
        filename: String? = nil,
        flaggedAt: String? = nil,
        flagSource: String? = nil,
        suggestedDMPMSTags: [String]? = nil,
        suggestedReviewNote: String? = nil,
        runtimeFlagState: DMPSFlaggedReportRuntimeFlagState? = nil,
        sidecarStatusAtFlag: DMPSFlaggedReportSidecarStatusAtFlag? = nil
    ) {
        self.rawID = rawID
        self.imageAbsolutePath = imageAbsolutePath
        self.relativePath = relativePath
        self.filename = filename
        self.flaggedAt = flaggedAt
        self.flagSource = flagSource
        self.suggestedDMPMSTags = suggestedDMPMSTags
        self.suggestedReviewNote = suggestedReviewNote
        self.runtimeFlagState = runtimeFlagState
        self.sidecarStatusAtFlag = sidecarStatusAtFlag
    }

    init(from decoder: Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.init()
            return
        }

        self.init(
            rawID: container.decodeLossyStringIfPresent(forKey: .rawID),
            imageAbsolutePath: container.decodeLossyStringIfPresent(forKey: .imageAbsolutePath),
            relativePath: container.decodeLossyStringIfPresent(forKey: .relativePath),
            filename: container.decodeLossyStringIfPresent(forKey: .filename),
            flaggedAt: container.decodeLossyStringIfPresent(forKey: .flaggedAt),
            flagSource: container.decodeLossyStringIfPresent(forKey: .flagSource),
            suggestedDMPMSTags: (try? container.decodeIfPresent([String].self, forKey: .suggestedDMPMSTags)) ?? nil,
            suggestedReviewNote: container.decodeLossyStringIfPresent(forKey: .suggestedReviewNote),
            runtimeFlagState: try? container.decodeIfPresent(DMPSFlaggedReportRuntimeFlagState.self, forKey: .runtimeFlagState),
            sidecarStatusAtFlag: try? container.decodeIfPresent(DMPSFlaggedReportSidecarStatusAtFlag.self, forKey: .sidecarStatusAtFlag)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(rawID, forKey: .rawID)
        try container.encodeIfPresent(imageAbsolutePath, forKey: .imageAbsolutePath)
        try container.encodeIfPresent(relativePath, forKey: .relativePath)
        try container.encodeIfPresent(filename, forKey: .filename)
        try container.encodeIfPresent(flaggedAt, forKey: .flaggedAt)
        try container.encodeIfPresent(flagSource, forKey: .flagSource)
        try container.encodeIfPresent(suggestedDMPMSTags, forKey: .suggestedDMPMSTags)
        try container.encodeIfPresent(suggestedReviewNote, forKey: .suggestedReviewNote)
        try container.encodeIfPresent(runtimeFlagState, forKey: .runtimeFlagState)
        try container.encodeIfPresent(sidecarStatusAtFlag, forKey: .sidecarStatusAtFlag)
    }

    var trimmedID: String {
        id.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedImageAbsolutePath: String? {
        trimmedNonEmpty(imageAbsolutePath)
    }

    var trimmedRelativePath: String? {
        trimmedNonEmpty(relativePath)
    }

    var trimmedSuggestedReviewNote: String? {
        trimmedNonEmpty(suggestedReviewNote)
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: - Tolerant Decoding Helpers

private extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }

        return nil
    }
}

// MARK: - Known dMPS Status Values

enum DMPSFlaggedReportRuntimeFlagState: String, Codable, Equatable {
    case flagged
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }
}

enum DMPSFlaggedReportSidecarStatusAtFlag: String, Codable, Equatable {
    case notChecked
    case missing
    case valid
    case invalid
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = Self(rawValue: raw) ?? .unknown
    }
}
