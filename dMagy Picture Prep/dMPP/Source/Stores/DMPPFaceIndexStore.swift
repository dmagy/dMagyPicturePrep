import Foundation
import Combine

// ================================================================
// DMPPFaceIndexStore.swift
//
// Purpose
// - Portable, per-archive face embedding index for local recognition.
// - Stores numeric face embeddings (no images) keyed by personID.
// - Loads/saves to the portable archive so it travels with the archive.
//
// Dependencies & Effects
// - Reads/writes JSON under:
//   <Archive Root>/dMagy Portable Archive Data/FaceIndex/face_index.json
// - Does NOT touch per-photo sidecars.
//
// Section Index
// - // MARK: - Types
// - // MARK: - Configuration
// - // MARK: - Public API
// - // MARK: - Persistence
// - // MARK: - Matching
// - // MARK: - Utilities
// ================================================================

final class DMPPFaceIndexStore: ObservableObject {

    // MARK: - Types

    struct Match: Identifiable, Hashable {
        let personID: String
        let similarity: Float
        var id: String { personID }
    }

    struct EmbeddingSample: Codable, Hashable {
        var createdAtISO8601: String
        var source: String?
        var embedding: [Float]
    }

    private struct FaceIndexFile: Codable {
        var schemaVersion: Int
        var updatedAtISO8601: String
        var people: [String: [EmbeddingSample]]
    }

    // MARK: - Configuration

    private var archiveRootURL: URL? = nil
    private var faceIndexURL: URL? = nil

    // MARK: - In-memory state

    private(set) var isConfigured: Bool = false

    /// In-memory index: personID -> samples
    @Published private(set) var people: [String: [EmbeddingSample]] = [:]

    // MARK: - Tuning knobs (MVP)

    private let maxSamplesPerPerson: Int = 50
    private let dedupeSimilarityThreshold: Float = 0.995

    // MARK: - Init

    init() {}

    // MARK: - Public API

    func configureForArchiveRoot(_ root: URL?) {
        archiveRootURL = root
        isConfigured = (root != nil)

        guard let root else {
            faceIndexURL = nil
            people = [:]
            return
        }

        faceIndexURL = makeFaceIndexURL(root: root)
        loadFromDisk()
    }

    var hasAnySamples: Bool { !people.isEmpty }

    func addSample(personID: String, embedding rawEmbedding: [Float], source: String? = nil) {
        guard isConfigured else { return }

        let pid = personID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pid.isEmpty else { return }

        let cleaned = sanitizeEmbedding(rawEmbedding)
        guard !cleaned.isEmpty else { return }

        let normalizedNew = normalize(cleaned)
        guard !normalizedNew.isEmpty else { return }

        let existing = people[pid] ?? []

        // De-dupe against existing samples for this person.
        for s in existing {
            let normExisting = normalize(s.embedding)
            if normExisting.isEmpty { continue }
            let sim = cosineSimilarity(normalizedNew, normExisting)
            if sim >= dedupeSimilarityThreshold {
                return
            }
        }

        let sample = EmbeddingSample(
            createdAtISO8601: ISO8601DateFormatter().string(from: Date()),
            source: source,
            embedding: normalizedNew
        )

        var updated = existing
        updated.append(sample)

        // Rolling cap (keep newest)
        if updated.count > maxSamplesPerPerson {
            updated = Array(updated.suffix(maxSamplesPerPerson))
        }

        people[pid] = updated
        saveToDisk()
    }

    func removeAllSamples(for personID: String) {
        guard isConfigured else { return }
        people.removeValue(forKey: personID)
        saveToDisk()
    }

    func clearAll() {
        guard isConfigured else { return }
        people = [:]
        saveToDisk()
    }

    // MARK: - Persistence

    private func makeFaceIndexURL(root: URL) -> URL {
        let folder = root
            .appendingPathComponent("dMagy Portable Archive Data", isDirectory: true)
            .appendingPathComponent("FaceIndex", isDirectory: true)

        return folder.appendingPathComponent("face_index.json", isDirectory: false)
    }

    private func ensureFolderExists(for url: URL) {
        let folder = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            print("dMPP: FaceIndexStore failed to create folder: \(error)")
        }
    }

    private func loadFromDisk() {
        guard let faceIndexURL else { return }

        ensureFolderExists(for: faceIndexURL)

        guard FileManager.default.fileExists(atPath: faceIndexURL.path) else {
            people = [:]
            return
        }

        do {
            let data = try Data(contentsOf: faceIndexURL)
            let decoded = try JSONDecoder().decode(FaceIndexFile.self, from: data)

            var cleanedPeople: [String: [EmbeddingSample]] = [:]
            for (pid, samples) in decoded.people {
                let safe = samples.compactMap { s -> EmbeddingSample? in
                    let e = sanitizeEmbedding(s.embedding)
                    guard !e.isEmpty else { return nil }
                    return EmbeddingSample(createdAtISO8601: s.createdAtISO8601, source: s.source, embedding: e)
                }
                if !safe.isEmpty { cleanedPeople[pid] = safe }
            }

            people = cleanedPeople
        } catch {
            print("dMPP: FaceIndexStore failed to load: \(error)")
            people = [:]
        }
    }

    private func saveToDisk() {
        guard let faceIndexURL else { return }
        ensureFolderExists(for: faceIndexURL)

        let file = FaceIndexFile(
            schemaVersion: 1,
            updatedAtISO8601: ISO8601DateFormatter().string(from: Date()),
            people: people
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(file)
            try data.write(to: faceIndexURL, options: .atomic)
        } catch {
            print("dMPP: FaceIndexStore failed to save: \(error)")
        }
    }

    // MARK: - Matching

    func match(embedding rawEmbedding: [Float], topK: Int = 3, minSimilarity: Float = 0.55) -> [Match] {
        guard isConfigured else { return [] }
        guard topK > 0 else { return [] }

        let cleaned = sanitizeEmbedding(rawEmbedding)
        let query = normalize(cleaned)
        guard !query.isEmpty else { return [] }

        var results: [Match] = []

        for (pid, samples) in people {
            var best: Float = -1
            for s in samples {
                let candidate = normalize(s.embedding)
                if candidate.isEmpty { continue }
                let sim = cosineSimilarity(query, candidate)
                if sim > best { best = sim }
            }

            if best >= minSimilarity {
                results.append(Match(personID: pid, similarity: best))
            }
        }

        results.sort {
            if $0.similarity != $1.similarity { return $0.similarity > $1.similarity }
            return $0.personID < $1.personID
        }

        return results.count > topK ? Array(results.prefix(topK)) : results
    }

    // MARK: - Utilities

    private func sanitizeEmbedding(_ raw: [Float]) -> [Float] {
        raw.filter { $0.isFinite }
    }

    private func normalize(_ v: [Float]) -> [Float] {
        guard !v.isEmpty else { return [] }
        var sum: Double = 0
        for x in v {
            let dx = Double(x)
            sum += dx * dx
        }
        let norm = sqrt(sum)
        guard norm > 0.0000001 else { return [] }
        let inv = 1.0 / norm
        return v.map { Float(Double($0) * inv) }
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1 }
        var dot: Double = 0
        for i in 0..<a.count {
            dot += Double(a[i]) * Double(b[i])
        }
        return Float(dot)
    }
}
