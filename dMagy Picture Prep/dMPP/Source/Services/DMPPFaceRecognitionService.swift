import Foundation
import AppKit
import CoreML

// ================================================================
// DMPPFaceRecognitionService.swift
//
// Purpose
// - Extract face embeddings from an image for recognition/matching.
// - Uses a bundled Core ML embedding model: AuraFaceEmbedding.mlpackage
//
// Dependencies & Effects
// - No disk writes.
// - No network.
// - Consumes NSImage + normalized face rect.
//
// Data Flow
// - embedFace(in:faceRect:) crops -> resizes -> tensorizes -> CoreML -> [Float]
// ================================================================

final class DMPPFaceRecognitionService {

    // MARK: - Model constants (AuraFace embedding)

    // AuraFace ONNX we chose outputs 512, input 112x112 (CHW).
    private let inputWidth: Int = 112
    private let inputHeight: Int = 112

    // Normalization: map 0..255 to -1..1
    // (Common for face embedding nets; adjust later if accuracy needs tuning.)
    private let mean: Float = 0.5
    private let std: Float = 0.5

    // MARK: - Model (lazy)

    private lazy var model: MLModel? = {
        do {
            guard let url = Bundle.main.url(forResource: "AuraFaceEmbedding", withExtension: "mlmodelc") else {
                print("dMPP FaceRec: AuraFaceEmbedding.mlmodelc NOT FOUND in bundle.")
                let compiled = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) ?? []
                print("dMPP FaceRec: mlmodelc resources in bundle:", compiled.map { $0.lastPathComponent })
                return nil
            }

            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let m = try MLModel(contentsOf: url, configuration: config)
            print("dMPP FaceRec: model loaded OK:", url.lastPathComponent)
            return m
        
        } catch {
            print("dMPP FaceRec: model load FAILED:", error)
            return nil
        }
    }()

    // MARK: - Public API

    /// Returns an embedding vector for a detected face, or nil if unavailable.
    ///
    /// - Parameters:
    ///   - image: The source NSImage (full photo)
    ///   - faceRect: Normalized face rect (top-left origin, 0..1), from DMPPFaceDetectionService
    func embedFace(in image: NSImage, faceRect: RectNormalized) -> [Float]? {
        guard let model else { return nil }

        // 1) Crop face from the source
        guard let faceCG = cropFaceImage(from: image, faceRect: faceRect) else { return nil }

        // 2) Resize to model input size
        guard let resized = resize(cgImage: faceCG, width: inputWidth, height: inputHeight) else { return nil }

        // 3) Convert to MLMultiArray (Float32) in CHW, shape [1, 3, H, W]
        guard let inputArray = makeCHWMultiArray(from: resized) else { return nil }

        // 4) Run model
        let inputName = model.modelDescription.inputDescriptionsByName.keys.first ?? "data"
        let outputName = model.modelDescription.outputDescriptionsByName.keys.first

        do {
            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: inputArray])
            let out = try model.prediction(from: provider)

            if let outputName,
               let feature = out.featureValue(for: outputName),
               let arr = feature.multiArrayValue {
                return flattenMultiArray(arr)
            }

            // Fallback: find the first multiarray output if name mismatch
            for name in out.featureNames {
                if let feature = out.featureValue(for: name),
                   let arr = feature.multiArrayValue {
                    return flattenMultiArray(arr)
                }
            }

            return nil
        } catch {
            print("dMPP FaceRec: prediction failed:", error)
            return nil
        }
    }

    // MARK: - Cropping

    /// Crops the face region from the full image, with a little padding.
    /// Returns a CGImage suitable for preprocessing/model input.
    private func cropFaceImage(from image: NSImage, faceRect: RectNormalized) -> CGImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let imgW = cg.width
        let imgH = cg.height
        guard imgW > 2, imgH > 2 else { return nil }

        // Convert normalized top-left rect to pixel rect (y down).
        let xPx = Int((Double(imgW) * faceRect.x).rounded(.down))
        let yPx = Int((Double(imgH) * faceRect.y).rounded(.down))
        let wPx = Int((Double(imgW) * faceRect.width).rounded(.up))
        let hPx = Int((Double(imgH) * faceRect.height).rounded(.up))

        // Padding (10% of face size)
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

    // MARK: - Image -> Tensor

    private func resize(cgImage: CGImage, width: Int, height: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // RGBA8
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    /// Creates a Float32 MLMultiArray shaped [1, 3, H, W] in CHW order.
    private func makeCHWMultiArray(from cgImage: CGImage) -> MLMultiArray? {
        let w = cgImage.width
        let h = cgImage.height
        guard w == inputWidth, h == inputHeight else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * w
        let countBytes = bytesPerRow * h

        var raw = [UInt8](repeating: 0, count: countBytes)

        guard let ctx = CGContext(
            data: &raw,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Shape: [1, 3, H, W]
        guard let arr = try? MLMultiArray(shape: [1, 3, NSNumber(value: h), NSNumber(value: w)], dataType: .float32) else {
            return nil
        }

        // Fill in CHW
        // raw is RGBA, top-left origin, row-major
        func norm(_ v: UInt8) -> Float {
            let f = Float(v) / 255.0
            return (f - mean) / std
        }

        // Index mapping for MLMultiArray (C order): [n, c, y, x]
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = norm(raw[i + 0])
                let g = norm(raw[i + 1])
                let b = norm(raw[i + 2])

                arr[[0, 0, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: r)
                arr[[0, 1, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: g)
                arr[[0, 2, NSNumber(value: y), NSNumber(value: x)]] = NSNumber(value: b)
            }
        }

        return arr
    }

    private func flattenMultiArray(_ arr: MLMultiArray) -> [Float] {
        let n = arr.count
        var out: [Float] = Array(repeating: 0, count: n)

        // MLMultiArray can be non-contiguous; safest is element access.
        // (This is fine for 512 dims.)
        for i in 0..<n {
            out[i] = arr[i].floatValue
        }
        return out
    }
}
