import Foundation
import AppKit

// ================================================================
// DMPPFaceRecognitionService.swift
//
// Purpose
// - Extract face embeddings from an image for recognition/matching.
// - This is a stub that compiles without a Core ML model.
// - Next step: plug in a bundled Core ML embedding model and return
//   real vectors.
//
// Dependencies & Effects
// - No disk writes.
// - No network.
// - Consumes NSImage + normalized face rect.
//
// Data Flow
// - embedFace(in:image, faceRect) -> [Float]?  (nil in stub)
// - cropFaceImage(...) prepares a face crop for model input.
//
// Section Index
// - // MARK: - Public API
// - // MARK: - Cropping
// - // MARK: - Utilities
// ================================================================

final class DMPPFaceRecognitionService {

    // MARK: - Public API

    /// Returns an embedding vector for a detected face, or nil if unavailable.
    ///
    /// - Parameters:
    ///   - image: The source NSImage (full photo)
    ///   - faceRect: Normalized face rect (top-left origin, 0..1), from DMPPFaceDetectionService
    ///
    /// Notes:
    /// - Stub returns nil until a Core ML model is wired in.
    func embedFace(in image: NSImage, faceRect: RectNormalized) -> [Float]? {
        // Prepare a crop (this will be used by the model later)
        guard cropFaceImage(from: image, faceRect: faceRect) != nil else {
            return nil
        }

        // TODO (next step): run Core ML model and return embedding
        return nil
    }

    // MARK: - Cropping

    /// Crops the face region from the full image, with a little padding.
    /// Returns a CGImage suitable for preprocessing/model input.
    private func cropFaceImage(from image: NSImage, faceRect: RectNormalized) -> CGImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let imgW = cg.width
        let imgH = cg.height
        guard imgW > 2, imgH > 2 else { return nil }

        // Convert normalized top-left rect to pixel rect.
        // RectNormalized in this project uses top-left origin (same as Vision’s normalized bounding boxes
        // after your conversion), so y increases downward.
        let xPx = Int((Double(imgW) * faceRect.x).rounded(.down))
        let yPx = Int((Double(imgH) * faceRect.y).rounded(.down))
        let wPx = Int((Double(imgW) * faceRect.width).rounded(.up))
        let hPx = Int((Double(imgH) * faceRect.height).rounded(.up))

        // Add padding (10% of face size) to capture a bit of context.
        let padX = Int(Double(wPx) * 0.10)
        let padY = Int(Double(hPx) * 0.10)

        let padded = CGRect(
            x: xPx - padX,
            y: yPx - padY,
            width: wPx + (2 * padX),
            height: hPx + (2 * padY)
        )

        let bounds = CGRect(x: 0, y: 0, width: imgW, height: imgH)
        let cropRect = padded.intersection(bounds)
        guard cropRect.width >= 4, cropRect.height >= 4 else { return nil }

        return cg.cropping(to: cropRect)
    }
}
