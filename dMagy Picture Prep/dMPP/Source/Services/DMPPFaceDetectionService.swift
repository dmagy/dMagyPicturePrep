import Foundation
import AppKit
import Vision

// ================================================================
// DMPPFaceDetectionService.swift
// cp-2026-02-20-02(FACE-DETECT-SVC)
// Purpose
// - Detect faces in ONE image (no folder scanning).
// - Returns normalized rects in TOP-LEFT origin space (x,y,w,h in 0...1).
//
// Notes
// - Vision returns bounding boxes normalized with origin at bottom-left.
// - dMPP UI/crop logic is easier if we use top-left origin.
//   Conversion: yTop = 1 - yBottom - height
// ================================================================

@MainActor
final class DMPPFaceDetectionService {

    struct DetectedFace: Identifiable, Equatable {
        let id = UUID()
        let rect: RectNormalized     // top-left origin, normalized 0...1
    }

    /// Detect faces in an NSImage. Returns faces sorted left-to-right.
    func detectFaces(in nsImage: NSImage) async -> [DetectedFace] {

        guard let cg = nsImage.cgImageForCurrentRepresentation() else { return [] }

        let request = VNDetectFaceRectanglesRequest()

        do {
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])

            let obs = request.results ?? []

            let faces: [DetectedFace] = obs.compactMap { o in
                let b = o.boundingBox  // normalized, origin bottom-left
                let x = clamp01(b.origin.x)
                let w = clamp01(b.size.width)

                // Convert to top-left origin
                let yTop = clamp01(1.0 - b.origin.y - b.size.height)
                let h = clamp01(b.size.height)

                // Filter out pathological boxes
                guard w > 0.01, h > 0.01 else { return nil }

                return DetectedFace(rect: RectNormalized(x: x, y: yTop, width: w, height: h))
            }

            // Sort left-to-right (x)
            return faces.sorted { $0.rect.x < $1.rect.x }

        } catch {
            print("dMPP: Face detection failed: \(error)")
            return []
        }
    }

    private func clamp01(_ v: CGFloat) -> CGFloat {
        min(1.0, max(0.0, v))
    }
}

// MARK: - NSImage helper

private extension NSImage {
    func cgImageForCurrentRepresentation() -> CGImage? {
        // Try the fastest path first
        var rect = CGRect(origin: .zero, size: size)
        if let cg = cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cg
        }

        // Fallback: render into a bitmap rep
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.cgImage
    }
}
